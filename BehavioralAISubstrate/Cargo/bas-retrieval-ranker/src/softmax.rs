// SPDX:internal
//
// softmax.rs — chapter 七百九 第一刀 / M2216
//
// Numerically-stable softmax for the substrate's CPU path。
// Two variants:
//
//   - softmax_stable(x, out)       : max-subtract + 1-pass exp_sum
//   - softmax_stable_simd(x, out)  : + 4-wide inner loops auto-
//                                    vectorized to NEON / SSE
//
// Max-subtract makes the softmax numerically stable even when
// logits include very large magnitudes (otherwise exp() would
// overflow to +inf)。
//
// All ops are pure functions on caller-owned slices — no shared
// state, no allocations inside the hot loop。

/// In-place numerically-stable softmax。 Reads `x` + writes
/// `out`。 Both must have the same length。 Algorithm:
///
///   m = max(x)
///   denom = Σⱼ exp(x_j - m)
///   out_i = exp(x_i - m) / denom
pub fn softmax_stable(x: &[f32], out: &mut [f32]) {
    debug_assert_eq!(x.len(), out.len());
    if x.is_empty() { return; }

    // Pass 1: find max
    let mut m = x[0];
    for &v in x.iter().skip(1) {
        if v > m { m = v; }
    }

    // Pass 2: compute exp(x - m) into out, accumulate denom
    let mut denom = 0.0_f32;
    for (i, &v) in x.iter().enumerate() {
        let e = (v - m).exp();
        out[i] = e;
        denom += e;
    }

    // Pass 3: normalize
    if denom > 0.0 {
        let inv = 1.0_f32 / denom;
        for o in out.iter_mut() { *o *= inv; }
    } else {
        // Pathological — uniform fallback
        let uniform = 1.0_f32 / (x.len() as f32);
        for o in out.iter_mut() { *o = uniform; }
    }
}

/// SIMD-accelerated softmax — same numerical-stability formula
/// but with 4-wide loops that LLVM auto-vectorizes。
pub fn softmax_stable_simd(x: &[f32], out: &mut [f32]) {
    debug_assert_eq!(x.len(), out.len());
    if x.is_empty() { return; }
    let n = x.len();

    // Pass 1: 4-wide max
    let mut m0 = x[0];
    let mut m1 = x[0];
    let mut m2 = x[0];
    let mut m3 = x[0];
    let mut i = 0;
    while i + 4 <= n {
        if x[i + 0] > m0 { m0 = x[i + 0]; }
        if x[i + 1] > m1 { m1 = x[i + 1]; }
        if x[i + 2] > m2 { m2 = x[i + 2]; }
        if x[i + 3] > m3 { m3 = x[i + 3]; }
        i += 4;
    }
    let mut m = m0.max(m1).max(m2).max(m3);
    while i < n {
        if x[i] > m { m = x[i]; }
        i += 1;
    }

    // Pass 2: 4-wide exp + accumulate
    let mut s0 = 0.0_f32;
    let mut s1 = 0.0_f32;
    let mut s2 = 0.0_f32;
    let mut s3 = 0.0_f32;
    i = 0;
    while i + 4 <= n {
        let e0 = (x[i + 0] - m).exp();
        let e1 = (x[i + 1] - m).exp();
        let e2 = (x[i + 2] - m).exp();
        let e3 = (x[i + 3] - m).exp();
        out[i + 0] = e0;
        out[i + 1] = e1;
        out[i + 2] = e2;
        out[i + 3] = e3;
        s0 += e0;
        s1 += e1;
        s2 += e2;
        s3 += e3;
        i += 4;
    }
    let mut tail = 0.0_f32;
    while i < n {
        let e = (x[i] - m).exp();
        out[i] = e;
        tail += e;
        i += 1;
    }
    let denom = (s0 + s1) + (s2 + s3) + tail;
    if denom > 0.0 {
        let inv = 1.0_f32 / denom;
        let mut j = 0;
        while j + 4 <= n {
            out[j + 0] *= inv;
            out[j + 1] *= inv;
            out[j + 2] *= inv;
            out[j + 3] *= inv;
            j += 4;
        }
        while j < n {
            out[j] *= inv;
            j += 1;
        }
    } else {
        let uniform = 1.0_f32 / (n as f32);
        for o in out.iter_mut() { *o = uniform; }
    }
}

/// Row-wise softmax for a (rows × cols) matrix。 Used by
/// attention + classification heads。 Both `x` and `out` are
/// row-major flat arrays of length rows*cols。
pub fn softmax_rowwise_simd(
    x: &[f32], out: &mut [f32],
    rows: usize, cols: usize,
) {
    debug_assert_eq!(x.len(), rows * cols);
    debug_assert_eq!(out.len(), rows * cols);
    for r in 0..rows {
        let start = r * cols;
        let row_in = &x[start..start + cols];
        let row_out = &mut out[start..start + cols];
        softmax_stable_simd(row_in, row_out);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_eq(a: &[f32], b: &[f32], tol: f32) -> bool {
        if a.len() != b.len() { return false; }
        for i in 0..a.len() {
            if (a[i] - b[i]).abs() > tol { return false; }
        }
        true
    }

    #[test]
    fn uniform_input_uniform_output() {
        let x = [1.0_f32; 8];
        let mut out = [0.0_f32; 8];
        softmax_stable(&x, &mut out);
        // All values equal → uniform 1/N
        let target = [1.0 / 8.0_f32; 8];
        assert!(approx_eq(&out, &target, 1e-6));
        // Sum to 1
        let sum: f32 = out.iter().sum();
        assert!((sum - 1.0).abs() < 1e-6);
    }

    #[test]
    fn one_hot_input_one_hot_output() {
        // [1000, 0, 0] — large positive → first element ≈ 1
        let x = [1000.0_f32, 0.0, 0.0];
        let mut out = [0.0_f32; 3];
        softmax_stable(&x, &mut out);
        assert!((out[0] - 1.0).abs() < 1e-6);
        assert!(out[1] < 1e-6);
        assert!(out[2] < 1e-6);
        // Numerical stability:WITHOUT max-subtract this would
        // have overflowed to NaN。
    }

    #[test]
    fn sum_to_one() {
        let x = [-2.0_f32, -1.0, 0.0, 1.0, 2.0];
        let mut out = [0.0_f32; 5];
        softmax_stable(&x, &mut out);
        let sum: f32 = out.iter().sum();
        assert!((sum - 1.0).abs() < 1e-6);
    }

    #[test]
    fn simd_matches_scalar() {
        let x: Vec<f32> = (0..16).map(|i|
            (i as f32) * 0.1 - 0.8).collect();
        let mut out_scalar = vec![0.0_f32; 16];
        let mut out_simd = vec![0.0_f32; 16];
        softmax_stable(&x, &mut out_scalar);
        softmax_stable_simd(&x, &mut out_simd);
        assert!(approx_eq(&out_scalar, &out_simd, 1e-5));
    }

    #[test]
    fn simd_matches_scalar_non_multiple_of_4() {
        let x: Vec<f32> = (0..17).map(|i|
            ((i as f32) * 0.13).sin()).collect();
        let mut out_scalar = vec![0.0_f32; 17];
        let mut out_simd = vec![0.0_f32; 17];
        softmax_stable(&x, &mut out_scalar);
        softmax_stable_simd(&x, &mut out_simd);
        assert!(approx_eq(&out_scalar, &out_simd, 1e-5));
    }

    #[test]
    fn large_magnitude_inputs_stable() {
        // [10000, 10000+1, 10000+2] — without max-subtract,
        // exp() overflows。 With max-subtract, soft-max
        // gives sensible result。
        let x = [10000.0_f32, 10001.0, 10002.0];
        let mut out = [0.0_f32; 3];
        softmax_stable(&x, &mut out);
        for &v in &out {
            assert!(v.is_finite());
            assert!(v >= 0.0 && v <= 1.0);
        }
        let sum: f32 = out.iter().sum();
        assert!((sum - 1.0).abs() < 1e-5);
    }

    #[test]
    fn empty_input_is_noop() {
        let x: [f32; 0] = [];
        let mut out: [f32; 0] = [];
        softmax_stable(&x, &mut out);
        // Just doesn't crash
    }

    #[test]
    fn determinism() {
        let x: Vec<f32> = (0..64).map(|i|
            ((i as f32) * 0.07).sin()).collect();
        let mut o1 = vec![0.0_f32; 64];
        let mut o2 = vec![0.0_f32; 64];
        let mut o3 = vec![0.0_f32; 64];
        softmax_stable_simd(&x, &mut o1);
        softmax_stable_simd(&x, &mut o2);
        softmax_stable_simd(&x, &mut o3);
        assert_eq!(o1, o2);
        assert_eq!(o2, o3);
    }

    #[test]
    fn rowwise_softmax_two_rows() {
        // 2x3 input — each row independently softmax'd
        let x: Vec<f32> = vec![
            1000.0, 0.0, 0.0,
            0.0,    0.0, 1000.0,
        ];
        let mut out = vec![0.0_f32; 6];
        softmax_rowwise_simd(&x, &mut out, 2, 3);
        assert!((out[0] - 1.0).abs() < 1e-6);
        assert!((out[5] - 1.0).abs() < 1e-6);
        assert!(out[1] < 1e-6);
        assert!(out[2] < 1e-6);
        assert!(out[3] < 1e-6);
        assert!(out[4] < 1e-6);
    }
}
