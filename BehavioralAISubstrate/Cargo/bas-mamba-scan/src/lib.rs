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

    // Build a vector of (idx, value) lists per (b, d) thread and
    // process in parallel。 Chapter 八百六十五 simplification:the
    // outer `(b_i, d_i)` tuple was unused at scatter time (we already
    // encoded location in the `idx` field of each pair),so drop it
    // to halve heap allocations。 v2 is the production path;v1
    // remains for the chapter 八百六十三 bit-equality test only。
    let total_threads = batch * channels;
    let cells: Vec<Vec<(usize, f32)>> =
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
                local
            })
            .collect();

    // Scatter (sequential — disjoint writes,no racing)
    let mut y = vec![0.0_f32; bld];
    for locals in cells {
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
// (b, l, d) + a writable output buffer (y) + its capacity AS
// ELEMENT COUNT (must be ≥ element_count() = b*l*d float32 cells)。
// chapter 八百六十四 / M2976 doc fix:earlier comment incorrectly
// said "in bytes" — the code (lines 471 + 526) checks
// `out_capacity < bld as i32` where bld is element count,not bytes。
// Return `0` on success, `-1` on any input mismatch (caller
// routes to Swift fallback)。

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
    // chapter 八百六十四 / M2976 — checked_mul protects against
    // i64 overflow under adversarial inputs (b=l=d ≈ 2.1M cubes
    // overflow i64 even though each fits in i32)。 Original
    // `(b as i64) * (l as i64) * (d as i64)` could wrap to a
    // positive value < i32::MAX and slip through the cap。
    let bld_opt = (b as i64)
        .checked_mul(l as i64)
        .and_then(|x| x.checked_mul(d as i64));
    let bld = match bld_opt {
        Some(v) if v > 0 && v <= (i32::MAX as i64) => v as usize,
        _ => return -1,
    };
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
    // chapter 八百六十六 / M2986 — mirror sequential's chapter 八百六十四
    // `checked_mul` overflow guard。 Both 3-agent review passes
    // (code review + test coverage) independently caught that the
    // parallel C ABI was missing the same guard,which would slip
    // adversarial b=l=d ≈ 2.1M inputs (i64 wrap to positive < i32::MAX)
    // through this entry point。 Now symmetric with sequential。
    let bld_opt = (b as i64)
        .checked_mul(l as i64)
        .and_then(|x| x.checked_mul(d as i64));
    let bld = match bld_opt {
        Some(v) if v > 0 && v <= (i32::MAX as i64) => v as usize,
        _ => return -1,
    };
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


// MARK: - Tests (extracted chapter 八百六十五 / M2981 to keep
// lib.rs under the 800-line god-file ceiling per coding-style.md)

#[cfg(test)]
mod tests;
