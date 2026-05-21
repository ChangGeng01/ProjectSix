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

// MARK: - C ABI scaffolding (full C ABI lands in knife 3)

/// Suppress unused c_char warning until knife 3 wires
/// the full C ABI surface。
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
