// SPDX:internal
//
// bas-mamba-scan — chapter 八百五十二 第一刀 / M2911
//
// Pure-Rust mirror of the Swift `BASSSMScanCPUReference`
// selective-scan implementation (chapter 六百七十八 / M2090)。
// Math is identical:zero-order hold discretization +
// per-(batch, channel) sequential recurrence over time。
//
// Knife 1 of Phase A (Mamba CPU multi-threading):this is
// the SEQUENTIAL Rust port。 Knife 2 will add rayon
// parallelism。 Knife 3 will add C ABI + Swift bridge。
//
// Layout convention (mirrors Swift):
//   - (B, L, D) row-major tensors:
//     linear_index(b, t, d) = ((b * L) + t) * D + d
//   - x, delta, B, C all share shape (B, L, D)
//   - A is per-channel only:shape (D,)
//   - y output: shape (B, L, D)
//
// All computation is f32。 The choice mirrors the Metal
// kernel's `float` type and the Swift `Float` (= Float32)
// in BASSSMScanCPUReference。 Future f64 widening is
// possible but not motivated:Mamba state-space models
// are trained + deployed in Float32 / bf16 / fp16 in
// practice;Float64 would be wasteful precision。
//
// Replay determinism:sequential reduction over time per
// (b, d) thread。 Cross-thread is independent so the
// sequential vs parallel paths produce identical outputs
// (within FMA-reorder tolerance which on x86/aarch64 is
// 0 for this code shape since no horizontal reduction
// crosses threads)。

#![forbid(unsafe_op_in_unsafe_fn)]

use std::os::raw::c_char;

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_mamba_scan_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Shape

/// Mirror of Swift `BASSSMScanShape` (3 UInt32 fields,
/// 12 bytes,no padding)。
#[repr(C)]
#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub struct MambaScanShape {
    pub b: u32,
    pub l: u32,
    pub d: u32,
}

impl MambaScanShape {
    /// Same as `BASSSMScanShape.linearIndex(b:t:d:)`。
    #[inline(always)]
    pub fn linear_index(&self, b: usize, t: usize, d: usize) -> usize {
        ((b * self.l as usize) + t) * self.d as usize + d
    }

    /// Total element count of a (B, L, D) tensor。
    #[inline(always)]
    pub fn element_count(&self) -> usize {
        (self.b as usize) * (self.l as usize) * (self.d as usize)
    }
}

// MARK: - Errors

#[derive(Debug, PartialEq, Eq)]
pub enum MambaScanError {
    /// A payload buffer length did not match the expected
    /// element count for its shape。 Mirrors Swift
    /// `BASSSMScanCPUReferenceError.payloadCountMismatch`。
    PayloadCountMismatch {
        name: &'static str,
        expected: usize,
        actual: usize,
    },
}

// MARK: - Sequential scan (knife 1)

/// Pure-Rust selective-scan implementation。 Sequential
/// over the outer (b, d) loop and over the inner t loop。
/// Knife 2 will add rayon over (b, d)。
///
/// Returns the output `y` of shape (B, L, D) row-major,
/// matching the Swift reference exactly。
///
/// Errors if any input slice length disagrees with the
/// shape struct。
pub fn scan_sequential(
    x: &[f32],
    delta: &[f32],
    a: &[f32],
    b_proj: &[f32],
    c_proj: &[f32],
    shape: MambaScanShape,
) -> Result<Vec<f32>, MambaScanError> {
    let bld = shape.element_count();
    let d_count = shape.d as usize;

    if x.len() != bld {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "x",
            expected: bld,
            actual: x.len(),
        });
    }
    if delta.len() != bld {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "delta",
            expected: bld,
            actual: delta.len(),
        });
    }
    if a.len() != d_count {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "A",
            expected: d_count,
            actual: a.len(),
        });
    }
    if b_proj.len() != bld {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "B",
            expected: bld,
            actual: b_proj.len(),
        });
    }
    if c_proj.len() != bld {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "C",
            expected: bld,
            actual: c_proj.len(),
        });
    }

    let mut y = vec![0.0_f32; bld];

    let batch = shape.b as usize;
    let length = shape.l as usize;
    let channels = shape.d as usize;

    // Outer:per (batch, channel) thread (matches Metal
    // dispatch grid (B, D, 1))。 Inner:sequential scan
    // over time。 Order matches MSL kernel exactly。
    for b_i in 0..batch {
        for d_i in 0..channels {
            let a_d = a[d_i];
            let mut h: f32 = 0.0;

            for t in 0..length {
                let idx = shape.linear_index(b_i, t, d_i);
                let x_t = x[idx];
                let delta_t = delta[idx];
                let b_t = b_proj[idx];
                let c_t = c_proj[idx];

                // Zero-order hold discretization
                let a_bar = (delta_t * a_d).exp();
                let b_bar = delta_t * b_t;

                // Recurrence step
                h = a_bar * h + b_bar * x_t;

                // Output projection
                y[idx] = c_t * h;
            }
        }
    }
    Ok(y)
}

// MARK: - Parallel scan (knife 2 — rayon over (b, d))

/// Same math as `scan_sequential` but parallel over the
/// outer `(b, d)` loop via rayon。 Each `(b, d)` pair is
/// an independent rayon task running the inner L
/// recurrence sequentially。 Mirror of the Metal GPU
/// dispatch grid `(B, D, 1)`。
///
/// Byte-equality with `scan_sequential` is GUARANTEED by
/// construction:
///   - No cross-thread reductions (each output cell
///     depends only on its own (b, d) thread's h state)
///   - Sequential reduction over time within each thread
///     (FP order preserved per cell)
///   - Output cells written to disjoint indices (no
///     racing,no atomic merge)
///
/// FMA-reorder concern: none。 The inner-loop math
/// `h = exp(δ·A) · h + (δ·B) · x` is the same in both
/// paths,executed in the same order per cell。
///
/// Performance:embarrassingly parallel across (B × D)
/// independent threads。 Real speedup measured in knife 4
/// at various B/D/L sizes。
pub fn scan_parallel(
    x: &[f32],
    delta: &[f32],
    a: &[f32],
    b_proj: &[f32],
    c_proj: &[f32],
    shape: MambaScanShape,
) -> Result<Vec<f32>, MambaScanError> {
    use rayon::prelude::*;

    let bld = shape.element_count();
    let d_count = shape.d as usize;

    // Validation — identical to sequential path
    if x.len() != bld {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "x", expected: bld, actual: x.len(),
        });
    }
    if delta.len() != bld {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "delta", expected: bld, actual: delta.len(),
        });
    }
    if a.len() != d_count {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "A", expected: d_count, actual: a.len(),
        });
    }
    if b_proj.len() != bld {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "B", expected: bld, actual: b_proj.len(),
        });
    }
    if c_proj.len() != bld {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "C", expected: bld, actual: c_proj.len(),
        });
    }

    let batch = shape.b as usize;
    let length = shape.l as usize;
    let channels = shape.d as usize;

    // Each (b, d) thread writes to `length` disjoint indices
    // in `y` — `idx = ((b * L) + t) * D + d`。 Different (b, d)
    // pairs produce different idx for every t,so write
    // disjointness is guaranteed。
    //
    // Strategy:produce a Vec of (idx, value) pairs in
    // parallel,then scatter into y。 This avoids needing
    // unsafe interior mutability。 For B × D × L cells the
    // scatter is O(N) and runs sequentially。 Alternative:
    // chunk y by (b, d) stride and let each task write its
    // chunk — but stride is D (the channel dim) which means
    // each cell of y is at index `b*L*D + t*D + d` and the
    // task's cells are NON-CONTIGUOUS。 So scatter is the
    // simplest correct approach for arbitrary shapes。
    //
    // For real-world shapes (B ≥ 4, D ≥ 32, L ≥ 64) the
    // parallel benefit easily outweighs the scatter cost。

    // Build a vector of (b, d) pairs and process in parallel
    let total_threads = batch * channels;
    let cells: Vec<((usize, usize), Vec<(usize, f32)>)> =
        (0..total_threads)
            .into_par_iter()
            .map(|tid| {
                let b_i = tid / channels;
                let d_i = tid % channels;
                let a_d = a[d_i];
                let mut h: f32 = 0.0;
                let mut local: Vec<(usize, f32)> =
                    Vec::with_capacity(length);
                for t in 0..length {
                    let idx = shape.linear_index(b_i, t, d_i);
                    let x_t = x[idx];
                    let delta_t = delta[idx];
                    let b_t = b_proj[idx];
                    let c_t = c_proj[idx];

                    let a_bar = (delta_t * a_d).exp();
                    let b_bar = delta_t * b_t;
                    h = a_bar * h + b_bar * x_t;
                    local.push((idx, c_t * h));
                }
                ((b_i, d_i), local)
            })
            .collect();

    // Scatter (sequential — disjoint writes,no racing)
    let mut y = vec![0.0_f32; bld];
    for (_bd, locals) in cells {
        for (idx, v) in locals {
            y[idx] = v;
        }
    }
    Ok(y)
}

// MARK: - Parallel v2 (chapter 八百六十三 / M2971)
//
// Better parallel implementation per the chapter 八百五十二 第四刀
// measurement finding:original `scan_parallel` was SLOWER than
// `scan_sequential` at all 3 measured scales because the scatter
// algorithm allocated `Vec<((usize,usize), Vec<(usize, f32)>)>`
// per task — heavy heap pressure。
//
// Strategy v2:`par_chunks_mut` on the output `y`,partitioning by
// BATCH (each task gets a contiguous slice of length L×D for one
// batch,does the full (D × L) sequential work in that batch)。
//
// Why this is better:
//   - Task granularity = B (not B×D)。 With B=8 batches you get 8
//     tasks of equal size, perfect for M-series chips (8+ cores)
//   - Writes within a task go to a contiguous slice → cache-friendly
//   - Zero unsafe (par_chunks_mut gives mutable disjoint slices)
//   - Zero per-task heap allocation (writes directly into y_batch)
//   - Output layout unchanged — still (B, L, D) row-major Float32
//
// Byte-equality with sequential is GUARANTEED:
//   - Each batch's work is identical to the corresponding portion
//     of the sequential loop
//   - Sequential order within a batch is preserved (same (d, t) loop
//     nesting)
//   - No cross-batch reductions

pub fn scan_parallel_v2(
    x: &[f32],
    delta: &[f32],
    a: &[f32],
    b_proj: &[f32],
    c_proj: &[f32],
    shape: MambaScanShape,
) -> Result<Vec<f32>, MambaScanError> {
    use rayon::prelude::*;

    let bld = shape.element_count();
    let d_count = shape.d as usize;

    // Validation — identical to other scan variants
    if x.len() != bld {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "x", expected: bld, actual: x.len(),
        });
    }
    if delta.len() != bld {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "delta", expected: bld, actual: delta.len(),
        });
    }
    if a.len() != d_count {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "A", expected: d_count, actual: a.len(),
        });
    }
    if b_proj.len() != bld {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "B", expected: bld, actual: b_proj.len(),
        });
    }
    if c_proj.len() != bld {
        return Err(MambaScanError::PayloadCountMismatch {
            name: "C", expected: bld, actual: c_proj.len(),
        });
    }

    let length = shape.l as usize;
    let channels = shape.d as usize;
    let batch_size = length * channels; // chunk per batch

    let mut y = vec![0.0_f32; bld];

    y.par_chunks_mut(batch_size)
        .enumerate()
        .for_each(|(b_i, y_batch)| {
            // y_batch is &mut [f32] of length L*D for batch b_i
            // Within y_batch, the cell for (t, d) is at index
            // (t * channels + d_i) since y is (B, L, D) row-major
            // and we've sliced off one batch's worth of L*D。
            //
            // The input arrays (x, delta, b_proj, c_proj) are still
            // shaped (B, L, D) with global indexing:
            //   global_idx = b_i * length * channels + t * channels + d_i
            //
            // For each channel d_i, run the sequential recurrence
            // over time t in 0..L。
            let batch_offset = b_i * length * channels;
            for d_i in 0..channels {
                let a_d = a[d_i];
                let mut h: f32 = 0.0;
                for t in 0..length {
                    let local_idx = t * channels + d_i;
                    let global_idx = batch_offset + local_idx;
                    let x_t = x[global_idx];
                    let delta_t = delta[global_idx];
                    let b_t = b_proj[global_idx];
                    let c_t = c_proj[global_idx];

                    let a_bar = (delta_t * a_d).exp();
                    let b_bar = delta_t * b_t;
                    h = a_bar * h + b_bar * x_t;
                    y_batch[local_idx] = c_t * h;
                }
            }
        });

    Ok(y)
}

// MARK: - C ABI (chapter 八百五十二 第三刀 / M2913)
//
// Three entry points:
//   - bas_mamba_scan_sequential(...) — sequential CPU path
//   - bas_mamba_scan_parallel(...)   — rayon parallel CPU path
//
// Both take 5 input buffers (x, delta, A, B, C) + a shape triple
// (b, l, d) + a writable output buffer (y) + its capacity in
// bytes (which must be ≥ element_count() × sizeof(f32))。 Return
// `0` on success, `-1` on any input mismatch (caller routes to
// Swift fallback)。

/// Sequential dispatch C ABI。 See `scan_sequential` for math。
///
/// # Safety
///
/// All input pointers MUST be non-null and point to readable
/// Float32 buffers of the correct element count:
///   - x, delta, B, C: length b*l*d (each)
///   - A: length d
/// `out_y_ptr` MUST point to a writable Float32 buffer of length
/// ≥ b*l*d。 The pointer-length contract is pinned by the FFI
/// caller (the Swift wrapper owns all buffers and sizes them
/// from the shape struct)。
#[no_mangle]
pub unsafe extern "C" fn bas_mamba_scan_sequential(
    x_ptr: *const f32,
    delta_ptr: *const f32,
    a_ptr: *const f32,
    b_proj_ptr: *const f32,
    c_proj_ptr: *const f32,
    b: i32,
    l: i32,
    d: i32,
    out_y_ptr: *mut f32,
    out_capacity: i32,
) -> i32 {
    // Input validation
    if x_ptr.is_null() || delta_ptr.is_null() || a_ptr.is_null()
        || b_proj_ptr.is_null() || c_proj_ptr.is_null()
        || out_y_ptr.is_null()
        || b <= 0 || l <= 0 || d <= 0
    {
        return -1;
    }
    let bld = (b as i64) * (l as i64) * (d as i64);
    if bld < 0 || bld > (i32::MAX as i64) {
        return -1; // overflow guard
    }
    let bld = bld as usize;
    if out_capacity < bld as i32 {
        return -1;
    }

    let shape = MambaScanShape {
        b: b as u32, l: l as u32, d: d as u32,
    };
    let x = unsafe { std::slice::from_raw_parts(x_ptr, bld) };
    let delta = unsafe { std::slice::from_raw_parts(delta_ptr, bld) };
    let a = unsafe { std::slice::from_raw_parts(a_ptr, d as usize) };
    let b_proj = unsafe { std::slice::from_raw_parts(b_proj_ptr, bld) };
    let c_proj = unsafe { std::slice::from_raw_parts(c_proj_ptr, bld) };

    match scan_sequential(x, delta, a, b_proj, c_proj, shape) {
        Ok(y) => {
            unsafe {
                std::ptr::copy_nonoverlapping(
                    y.as_ptr(), out_y_ptr, bld);
            }
            0
        }
        Err(_) => -1,
    }
}

/// Parallel dispatch C ABI。 Same shape as sequential。
///
/// # Safety
///
/// Same safety requirements as `bas_mamba_scan_sequential`。
#[no_mangle]
pub unsafe extern "C" fn bas_mamba_scan_parallel(
    x_ptr: *const f32,
    delta_ptr: *const f32,
    a_ptr: *const f32,
    b_proj_ptr: *const f32,
    c_proj_ptr: *const f32,
    b: i32,
    l: i32,
    d: i32,
    out_y_ptr: *mut f32,
    out_capacity: i32,
) -> i32 {
    if x_ptr.is_null() || delta_ptr.is_null() || a_ptr.is_null()
        || b_proj_ptr.is_null() || c_proj_ptr.is_null()
        || out_y_ptr.is_null()
        || b <= 0 || l <= 0 || d <= 0
    {
        return -1;
    }
    let bld = (b as i64) * (l as i64) * (d as i64);
    if bld < 0 || bld > (i32::MAX as i64) {
        return -1;
    }
    let bld = bld as usize;
    if out_capacity < bld as i32 {
        return -1;
    }

    let shape = MambaScanShape {
        b: b as u32, l: l as u32, d: d as u32,
    };
    let x = unsafe { std::slice::from_raw_parts(x_ptr, bld) };
    let delta = unsafe { std::slice::from_raw_parts(delta_ptr, bld) };
    let a = unsafe { std::slice::from_raw_parts(a_ptr, d as usize) };
    let b_proj = unsafe { std::slice::from_raw_parts(b_proj_ptr, bld) };
    let c_proj = unsafe { std::slice::from_raw_parts(c_proj_ptr, bld) };

    // chapter 八百六十三 / M2971 — transparent upgrade to
    // scan_parallel_v2 (par_chunks_mut by batch) which measured
    // 6.6× faster than sequential + 3.23× faster than v1
    // scan_parallel scatter algorithm。 v2 is bit-equal to v1 +
    // sequential by construction (verified by 30-fixture grid
    // in tests),so swapping the C ABI's internal call is a
    // transparent perf upgrade — no external signature change,
    // no behavioral change beyond walltime。 The v1 scan_parallel
    // remains exposed as a Rust pub fn for byte-equality oracle
    // testing only。
    match scan_parallel_v2(x, delta, a, b_proj, c_proj, shape) {
        Ok(y) => {
            unsafe {
                std::ptr::copy_nonoverlapping(
                    y.as_ptr(), out_y_ptr, bld);
            }
            0
        }
        Err(_) => -1,
    }
}

/// Suppress unused c_char warning。
const _: *const c_char = std::ptr::null();

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    fn make_shape(b: u32, l: u32, d: u32) -> MambaScanShape {
        MambaScanShape { b, l, d }
    }

    #[test]
    fn abi_version_is_one() {
        assert_eq!(bas_mamba_scan_abi_version(), 1);
    }

    #[test]
    fn shape_linear_index_matches_swift_convention() {
        // ((b * L) + t) * D + d
        let shape = make_shape(2, 3, 4);
        assert_eq!(shape.linear_index(0, 0, 0), 0);
        assert_eq!(shape.linear_index(0, 0, 3), 3);
        assert_eq!(shape.linear_index(0, 1, 0), 4);
        assert_eq!(shape.linear_index(0, 2, 0), 8);
        assert_eq!(shape.linear_index(1, 0, 0), 12);
        assert_eq!(shape.linear_index(1, 2, 3), 23);
        assert_eq!(shape.element_count(), 2 * 3 * 4);
    }

    #[test]
    fn scan_minimal_b1_l1_d1_yields_simple_recurrence() {
        // B=1, L=1, D=1 → single (b=0, d=0) thread,
        // single time step:
        //   h_0 = 0
        //   A_bar = exp(delta * A_d)
        //   B_bar = delta * B
        //   h_1 = A_bar * 0 + B_bar * x = B_bar * x
        //   y_0 = C * h_1 = C * delta * B * x
        let shape = make_shape(1, 1, 1);
        let x = vec![2.0_f32];
        let delta = vec![0.5_f32];
        let a = vec![-1.0_f32];
        let b_proj = vec![3.0_f32];
        let c_proj = vec![4.0_f32];
        let y = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape)
            .expect("scan must succeed");
        let expected = 4.0_f32 * 0.5 * 3.0 * 2.0;
        assert!((y[0] - expected).abs() < 1e-6);
    }

    #[test]
    fn scan_l2_recurrence_carries_h_state_across_time() {
        // B=1, L=2, D=1 — verify h carries between t=0 and t=1
        let shape = make_shape(1, 2, 1);
        let x = vec![1.0_f32, 1.0];
        let delta = vec![0.1_f32, 0.1];
        let a = vec![-2.0_f32];
        let b_proj = vec![1.0_f32, 1.0];
        let c_proj = vec![1.0_f32, 1.0];
        let y = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape)
            .expect("scan must succeed");
        // Hand-rolled expected:
        //   A_bar = exp(0.1 * -2) = exp(-0.2) ≈ 0.8187308
        //   B_bar = 0.1 * 1 = 0.1
        //   t=0: h = 0.8187 * 0 + 0.1 * 1 = 0.1
        //        y[0] = 1 * 0.1 = 0.1
        //   t=1: h = 0.8187 * 0.1 + 0.1 * 1 = 0.18187
        //        y[1] = 1 * 0.18187 = 0.18187
        assert!((y[0] - 0.1_f32).abs() < 1e-6);
        let expected_y1 = (0.1_f32 * -2.0).exp() * 0.1 + 0.1;
        assert!((y[1] - expected_y1).abs() < 1e-6);
    }

    #[test]
    fn scan_independent_channels_do_not_cross_contaminate() {
        // B=1, L=2, D=2 — two channels evolve independently
        let shape = make_shape(1, 2, 2);
        // x[t=0,d=0]=1, x[t=0,d=1]=10, x[t=1,d=0]=2, x[t=1,d=1]=20
        let x = vec![1.0_f32, 10.0, 2.0, 20.0];
        let delta = vec![0.1_f32, 0.1, 0.1, 0.1];
        let a = vec![-1.0_f32, -1.0];
        let b_proj = vec![1.0_f32, 1.0, 1.0, 1.0];
        let c_proj = vec![1.0_f32, 1.0, 1.0, 1.0];
        let y = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape)
            .expect("scan must succeed");
        // Each channel: y_d evolves with its own h_d
        // Channel d=0: x=[1,2], expected output proportional to (1, 2 + small carry)
        // Channel d=1: x=[10,20], expected output 10× channel d=0
        let ratio = y[1] / y[0]; // (t=0, d=1) / (t=0, d=0)
        assert!((ratio - 10.0_f32).abs() < 1e-4,
            "Channel d=1 should be 10× channel d=0 at t=0");
    }

    #[test]
    fn scan_independent_batches_do_not_cross_contaminate() {
        // B=2, L=1, D=1 — two batches evolve independently
        let shape = make_shape(2, 1, 1);
        let x = vec![5.0_f32, 7.0];  // batch 0:x=5, batch 1:x=7
        let delta = vec![0.1_f32, 0.1];
        let a = vec![-1.0_f32];
        let b_proj = vec![1.0_f32, 1.0];
        let c_proj = vec![1.0_f32, 1.0];
        let y = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape)
            .expect("scan must succeed");
        // y[0] = 1 * 0.1 * 1 * 5 = 0.5
        // y[1] = 1 * 0.1 * 1 * 7 = 0.7
        assert!((y[0] - 0.5_f32).abs() < 1e-6);
        assert!((y[1] - 0.7_f32).abs() < 1e-6);
    }

    #[test]
    fn scan_rejects_x_count_mismatch() {
        let shape = make_shape(1, 2, 1);
        // x is too short
        let x = vec![1.0_f32];
        let delta = vec![0.1_f32, 0.1];
        let a = vec![-1.0_f32];
        let b_proj = vec![1.0_f32, 1.0];
        let c_proj = vec![1.0_f32, 1.0];
        let err = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape)
            .unwrap_err();
        match err {
            MambaScanError::PayloadCountMismatch { name, expected, actual } => {
                assert_eq!(name, "x");
                assert_eq!(expected, 2);
                assert_eq!(actual, 1);
            }
        }
    }

    #[test]
    fn scan_rejects_a_count_mismatch() {
        let shape = make_shape(1, 1, 3);
        let x = vec![0.0_f32; 3];
        let delta = vec![0.1_f32; 3];
        let a = vec![-1.0_f32];  // too short:expected 3
        let b_proj = vec![1.0_f32; 3];
        let c_proj = vec![1.0_f32; 3];
        let err = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape)
            .unwrap_err();
        match err {
            MambaScanError::PayloadCountMismatch { name, expected, actual } => {
                assert_eq!(name, "A");
                assert_eq!(expected, 3);
                assert_eq!(actual, 1);
            }
        }
    }

    #[test]
    fn scan_decay_to_zero_with_strong_negative_a() {
        // With A = -100, decay is nearly instant — h should
        // collapse to ~0 after one step regardless of x。
        let shape = make_shape(1, 3, 1);
        let x = vec![1.0_f32, 1.0, 1.0];
        let delta = vec![1.0_f32, 1.0, 1.0];
        let a = vec![-100.0_f32];
        let b_proj = vec![1.0_f32, 1.0, 1.0];
        let c_proj = vec![1.0_f32, 1.0, 1.0];
        let y = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape)
            .expect("scan must succeed");
        // A_bar = exp(-100) ≈ 0 → h stays ≈ B_bar * x_t = delta * 1 * 1 = 1
        // So y[t] ≈ 1 for all t (no accumulation)
        for v in &y {
            assert!((v - 1.0_f32).abs() < 1e-6);
        }
    }

    #[test]
    fn scan_b2_l3_d2_full_shape_no_crash() {
        // Larger fixture exercising all loops
        let shape = make_shape(2, 3, 2);
        let bld = shape.element_count();
        let x: Vec<f32> = (0..bld).map(|i| (i as f32) * 0.01).collect();
        let delta: Vec<f32> = (0..bld).map(|i| 0.1 + (i as f32) * 0.001).collect();
        let a = vec![-1.0_f32, -0.5];
        let b_proj: Vec<f32> = (0..bld).map(|i| 0.5 + (i as f32) * 0.01).collect();
        let c_proj: Vec<f32> = (0..bld).map(|i| 1.0 + (i as f32) * 0.01).collect();
        let y = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape)
            .expect("scan must succeed");
        assert_eq!(y.len(), bld);
        // All outputs finite (no NaN/Inf from runaway exp)
        for v in &y {
            assert!(v.is_finite(), "all outputs must be finite");
        }
    }

    // MARK: - Parallel scan tests (knife 2 — chapter 八百五十二 / M2912)

    #[test]
    fn scan_parallel_matches_sequential_b1_l1_d1() {
        let shape = make_shape(1, 1, 1);
        let x = vec![2.0_f32];
        let delta = vec![0.5_f32];
        let a = vec![-1.0_f32];
        let b_proj = vec![3.0_f32];
        let c_proj = vec![4.0_f32];
        let seq = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
        let par = scan_parallel(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
        assert_eq!(seq, par,
            "Minimal shape: parallel must be bit-equal to sequential");
    }

    #[test]
    fn scan_parallel_matches_sequential_b4_l32_d16() {
        // Larger shape exercising real rayon parallelism
        let shape = make_shape(4, 32, 16);
        let bld = shape.element_count();
        let d_count = shape.d as usize;
        let x: Vec<f32> = (0..bld).map(|i| ((i % 23) as f32) * 0.013).collect();
        let delta: Vec<f32> = (0..bld).map(|i| 0.05 + ((i % 17) as f32) * 0.001).collect();
        let a: Vec<f32> = (0..d_count).map(|i| -0.5 - (i as f32) * 0.1).collect();
        let b_proj: Vec<f32> = (0..bld).map(|i| 0.3 + ((i % 11) as f32) * 0.007).collect();
        let c_proj: Vec<f32> = (0..bld).map(|i| 1.1 + ((i % 13) as f32) * 0.005).collect();
        let seq = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
        let par = scan_parallel(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
        assert_eq!(seq, par,
            "Larger shape (4, 32, 16): parallel must be bit-equal to sequential");
    }

    #[test]
    fn scan_parallel_handles_strong_decay() {
        // Verify NaN/Inf-safe path
        let shape = make_shape(2, 8, 4);
        let bld = shape.element_count();
        let d_count = shape.d as usize;
        let x = vec![1.0_f32; bld];
        let delta = vec![1.0_f32; bld];
        let a = vec![-50.0_f32; d_count];  // strong decay
        let b_proj = vec![1.0_f32; bld];
        let c_proj = vec![1.0_f32; bld];
        let seq = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
        let par = scan_parallel(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
        assert_eq!(seq, par);
        for v in &par {
            assert!(v.is_finite(), "All outputs must be finite under strong decay");
        }
    }

    #[test]
    fn scan_parallel_rejects_x_count_mismatch() {
        let shape = make_shape(1, 2, 1);
        let x = vec![1.0_f32];  // too short
        let delta = vec![0.1_f32, 0.1];
        let a = vec![-1.0_f32];
        let b_proj = vec![1.0_f32, 1.0];
        let c_proj = vec![1.0_f32, 1.0];
        let err = scan_parallel(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap_err();
        match err {
            MambaScanError::PayloadCountMismatch { name, .. } => {
                assert_eq!(name, "x");
            }
        }
    }

    #[test]
    fn scan_parallel_byte_equality_grid_random_inputs() {
        // 50-fixture randomized grid pinning parallel ≡ sequential
        for trial in 0..50_u64 {
            let b = 1 + (trial % 4) as usize;
            let l = 4 + (trial % 16) as usize;
            let d = 1 + (trial % 8) as usize;
            let shape = make_shape(b as u32, l as u32, d as u32);
            let bld = shape.element_count();
            // xorshift64 deterministic pseudo-random
            let mut state: u64 = trial.wrapping_mul(0x9E37).wrapping_add(0x12345);
            let mut next = || {
                state ^= state.wrapping_shl(13);
                state ^= state.wrapping_shr(7);
                state ^= state.wrapping_shl(17);
                ((state % 1000) as f32) / 1000.0
            };
            let x: Vec<f32> = (0..bld).map(|_| next()).collect();
            let delta: Vec<f32> = (0..bld).map(|_| 0.01 + 0.1 * next()).collect();
            let a: Vec<f32> = (0..d).map(|_| -1.0 - next()).collect();
            let b_proj: Vec<f32> = (0..bld).map(|_| next()).collect();
            let c_proj: Vec<f32> = (0..bld).map(|_| next()).collect();
            let seq = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
            let par = scan_parallel(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
            assert_eq!(seq, par,
                "Trial {}: parallel must be bit-equal to sequential for shape ({}, {}, {})",
                trial, b, l, d);
        }
    }

    // MARK: - Parallel v2 tests (chapter 八百六十三 / M2971)

    #[test]
    fn scan_parallel_v2_matches_sequential_b1_l1_d1() {
        let shape = make_shape(1, 1, 1);
        let x = vec![2.0_f32];
        let delta = vec![0.5_f32];
        let a = vec![-1.0_f32];
        let b_proj = vec![3.0_f32];
        let c_proj = vec![4.0_f32];
        let seq = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
        let v2 = scan_parallel_v2(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
        assert_eq!(seq, v2);
    }

    #[test]
    fn scan_parallel_v2_matches_sequential_b8_l32_d16() {
        let shape = make_shape(8, 32, 16);
        let bld = shape.element_count();
        let d_count = shape.d as usize;
        let x: Vec<f32> = (0..bld).map(|i| ((i % 23) as f32) * 0.013).collect();
        let delta: Vec<f32> = (0..bld).map(|i| 0.05 + ((i % 17) as f32) * 0.001).collect();
        let a: Vec<f32> = (0..d_count).map(|i| -0.5 - (i as f32) * 0.1).collect();
        let b_proj: Vec<f32> = (0..bld).map(|i| 0.3 + ((i % 11) as f32) * 0.007).collect();
        let c_proj: Vec<f32> = (0..bld).map(|i| 1.1 + ((i % 13) as f32) * 0.005).collect();
        let seq = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
        let v2 = scan_parallel_v2(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
        assert_eq!(seq, v2,
            "v2 (par_chunks_mut) must be bit-equal to sequential");
    }

    #[test]
    fn scan_parallel_v2_byte_equality_grid() {
        // 30-fixture randomized grid
        for trial in 0..30_u64 {
            let b = 1 + (trial % 8) as usize;
            let l = 4 + (trial % 12) as usize;
            let d = 1 + (trial % 8) as usize;
            let shape = make_shape(b as u32, l as u32, d as u32);
            let bld = shape.element_count();
            let mut state: u64 = trial.wrapping_mul(0xCAFE).wrapping_add(0xBABE);
            let mut next = || {
                state ^= state.wrapping_shl(13);
                state ^= state.wrapping_shr(7);
                state ^= state.wrapping_shl(17);
                ((state % 1000) as f32) / 1000.0
            };
            let x: Vec<f32> = (0..bld).map(|_| next()).collect();
            let delta: Vec<f32> = (0..bld).map(|_| 0.01 + 0.1 * next()).collect();
            let a: Vec<f32> = (0..d).map(|_| -1.0 - next()).collect();
            let b_proj: Vec<f32> = (0..bld).map(|_| next()).collect();
            let c_proj: Vec<f32> = (0..bld).map(|_| next()).collect();
            let seq = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
            let v2 = scan_parallel_v2(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
            assert_eq!(seq, v2,
                "Trial {} (b={}, l={}, d={}):v2 must byte-equal sequential",
                trial, b, l, d);
        }
    }

    #[test]
    fn scan_parallel_v2_rejects_x_count_mismatch() {
        let shape = make_shape(1, 2, 1);
        let x = vec![1.0_f32];
        let delta = vec![0.1_f32, 0.1];
        let a = vec![-1.0_f32];
        let b_proj = vec![1.0_f32, 1.0];
        let c_proj = vec![1.0_f32, 1.0];
        let err = scan_parallel_v2(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap_err();
        match err {
            MambaScanError::PayloadCountMismatch { name, .. } => {
                assert_eq!(name, "x");
            }
        }
    }

    // MARK: - Perf comparison v2 vs sequential vs original parallel
    //
    // Inline perf test:since this is a Rust unit test it runs as
    // part of `cargo test`,giving fast feedback on the parallel
    // rework win/loss without needing Swift integration。

    #[test]
    fn scan_parallel_v2_perf_at_realistic_scale() {
        // B=8, L=128, D=128 — typical medium-scale。 At this
        // shape, sequential was 913 µs in chapter 八百五十二 第四刀
        // (Swift CPU was 12,502 µs)。 Goal: v2 should beat seq。
        let shape = make_shape(8, 128, 128);
        let bld = shape.element_count();
        let d_count = shape.d as usize;
        let x: Vec<f32> = (0..bld).map(|i| ((i % 23) as f32) * 0.013).collect();
        let delta: Vec<f32> = (0..bld).map(|i| 0.05 + ((i % 17) as f32) * 0.001).collect();
        let a: Vec<f32> = (0..d_count).map(|i| -0.5 - (i as f32) * 0.1).collect();
        let b_proj: Vec<f32> = (0..bld).map(|i| 0.3 + ((i % 11) as f32) * 0.007).collect();
        let c_proj: Vec<f32> = (0..bld).map(|i| 1.1 + ((i % 13) as f32) * 0.005).collect();

        let iters = 30;
        // Warm up
        for _ in 0..3 {
            let _ = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape);
            let _ = scan_parallel(&x, &delta, &a, &b_proj, &c_proj, shape);
            let _ = scan_parallel_v2(&x, &delta, &a, &b_proj, &c_proj, shape);
        }

        let seq_start = std::time::Instant::now();
        for _ in 0..iters {
            let _ = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape);
        }
        let seq_ns = seq_start.elapsed().as_nanos();

        let par_start = std::time::Instant::now();
        for _ in 0..iters {
            let _ = scan_parallel(&x, &delta, &a, &b_proj, &c_proj, shape);
        }
        let par_ns = par_start.elapsed().as_nanos();

        let v2_start = std::time::Instant::now();
        for _ in 0..iters {
            let _ = scan_parallel_v2(&x, &delta, &a, &b_proj, &c_proj, shape);
        }
        let v2_ns = v2_start.elapsed().as_nanos();

        let seq_ms = (seq_ns as f64) / 1_000_000.0;
        let par_ms = (par_ns as f64) / 1_000_000.0;
        let v2_ms = (v2_ns as f64) / 1_000_000.0;

        println!("== chapter 863 perf [B=8 L=128 D=128 × {} iters] ==", iters);
        println!("   Rust seq:        {:.3} ms total", seq_ms);
        println!("   Rust par (v1):   {:.3} ms total (ratio vs seq {:.2}×)",
            par_ms, par_ms / seq_ms);
        println!("   Rust par (v2):   {:.3} ms total (ratio vs seq {:.2}×)",
            v2_ms, v2_ms / seq_ms);
        println!("   v2 speedup vs v1: {:.2}×", par_ms / v2_ms);
        // Don't assert a specific ratio — just print。 The fact
        // that all 3 run + produce valid output is the
        // correctness gate;measurement is for the human/CI to
        // read。
        assert!(seq_ns > 0);
        assert!(par_ns > 0);
        assert!(v2_ns > 0);
    }

    // MARK: - C ABI tests (chapter 八百五十二 第三刀 / M2913)

    #[test]
    fn c_abi_sequential_minimal_round_trip() {
        let x = vec![2.0_f32];
        let delta = vec![0.5_f32];
        let a = vec![-1.0_f32];
        let b_proj = vec![3.0_f32];
        let c_proj = vec![4.0_f32];
        let mut out = vec![-99.0_f32; 1];
        let rc = unsafe {
            bas_mamba_scan_sequential(
                x.as_ptr(), delta.as_ptr(), a.as_ptr(),
                b_proj.as_ptr(), c_proj.as_ptr(),
                1, 1, 1,
                out.as_mut_ptr(), 1)
        };
        assert_eq!(rc, 0, "C ABI must succeed");
        let expected = 4.0_f32 * 0.5 * 3.0 * 2.0;
        assert!((out[0] - expected).abs() < 1e-6);
    }

    #[test]
    fn c_abi_parallel_matches_sequential_at_shape_4_8_4() {
        let shape = make_shape(4, 8, 4);
        let bld = shape.element_count();
        let x: Vec<f32> = (0..bld).map(|i| (i as f32) * 0.013).collect();
        let delta: Vec<f32> = (0..bld).map(|i| 0.05 + (i as f32) * 0.001).collect();
        let a: Vec<f32> = (0..4).map(|i| -0.5 - (i as f32) * 0.1).collect();
        let b_proj: Vec<f32> = (0..bld).map(|i| 0.3 + (i as f32) * 0.007).collect();
        let c_proj: Vec<f32> = (0..bld).map(|i| 1.1 + (i as f32) * 0.005).collect();

        let mut out_seq = vec![-99.0_f32; bld];
        let mut out_par = vec![-99.0_f32; bld];

        let rc_seq = unsafe {
            bas_mamba_scan_sequential(
                x.as_ptr(), delta.as_ptr(), a.as_ptr(),
                b_proj.as_ptr(), c_proj.as_ptr(),
                4, 8, 4,
                out_seq.as_mut_ptr(), bld as i32)
        };
        let rc_par = unsafe {
            bas_mamba_scan_parallel(
                x.as_ptr(), delta.as_ptr(), a.as_ptr(),
                b_proj.as_ptr(), c_proj.as_ptr(),
                4, 8, 4,
                out_par.as_mut_ptr(), bld as i32)
        };
        assert_eq!(rc_seq, 0);
        assert_eq!(rc_par, 0);
        assert_eq!(out_seq, out_par,
            "C ABI parallel must byte-equal C ABI sequential");
    }

    #[test]
    fn c_abi_rejects_null_pointers() {
        let mut out = vec![0.0_f32; 1];
        let rc = unsafe {
            bas_mamba_scan_sequential(
                std::ptr::null(), std::ptr::null(), std::ptr::null(),
                std::ptr::null(), std::ptr::null(),
                1, 1, 1,
                out.as_mut_ptr(), 1)
        };
        assert_eq!(rc, -1);
    }

    #[test]
    fn c_abi_rejects_zero_dimensions() {
        let dummy = vec![1.0_f32; 4];
        let mut out = vec![0.0_f32; 4];
        let rc = unsafe {
            bas_mamba_scan_sequential(
                dummy.as_ptr(), dummy.as_ptr(), dummy.as_ptr(),
                dummy.as_ptr(), dummy.as_ptr(),
                0, 1, 1,
                out.as_mut_ptr(), 4)
        };
        assert_eq!(rc, -1, "b=0 must reject");
    }

    #[test]
    fn c_abi_rejects_insufficient_out_capacity() {
        let x = vec![1.0_f32; 4];  // b=1, l=2, d=2 = 4 elements
        let delta = vec![0.1_f32; 4];
        let a = vec![-1.0_f32; 2];
        let b_proj = vec![1.0_f32; 4];
        let c_proj = vec![1.0_f32; 4];
        let mut out = vec![0.0_f32; 2];  // too small
        let rc = unsafe {
            bas_mamba_scan_sequential(
                x.as_ptr(), delta.as_ptr(), a.as_ptr(),
                b_proj.as_ptr(), c_proj.as_ptr(),
                1, 2, 2,
                out.as_mut_ptr(), 2)
        };
        assert_eq!(rc, -1, "out_capacity < bld must reject");
    }

    // MARK: - Original sequential tests continue

    #[test]
    fn scan_deterministic_repeats_yield_byte_equal_outputs() {
        // chapter 392 replay-determinism — running the same
        // inputs twice must produce byte-equal outputs。
        let shape = make_shape(2, 4, 3);
        let bld = shape.element_count();
        let x: Vec<f32> = (0..bld).map(|i| (i as f32) * 0.013).collect();
        let delta: Vec<f32> = (0..bld).map(|i| 0.05 + (i as f32) * 0.001).collect();
        let a = vec![-1.5_f32, -0.7, -0.3];
        let b_proj: Vec<f32> = (0..bld).map(|i| 0.3 + (i as f32) * 0.007).collect();
        let c_proj: Vec<f32> = (0..bld).map(|i| 1.1 + (i as f32) * 0.005).collect();
        let y1 = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape)
            .expect("scan must succeed");
        let y2 = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape)
            .expect("scan must succeed");
        assert_eq!(y1, y2, "Same inputs must produce bit-equal outputs");
    }
}
