// SPDX:internal
//
// layer_norm.rs — chapter 七百九 第二刀 / M2217
//
// LayerNorm forward implementations for the substrate's CPU
// path。 Three variants:
//
//   - layer_norm_naive(x, out, eps)        : two-pass mean+var
//   - layer_norm_welford(x, out, eps)      : single-pass Welford
//                                             (better numerics
//                                              for large D)
//   - layer_norm_affine_simd(x, gamma, beta,
//                            out, eps)     : with γ and β + SIMD
//
// Used by transformer-shaped networks for activation normalization
// before each attention / FFN block。

/// Two-pass naive LayerNorm — reference impl + still correct
/// for typical D ≤ 1024。
pub fn layer_norm_naive(
    x: &[f32], out: &mut [f32], eps: f32,
) {
    debug_assert_eq!(x.len(), out.len());
    let n = x.len();
    if n == 0 { return; }
    // Pass 1: mean
    let mut sum = 0.0_f64;
    for &v in x { sum += v as f64; }
    let mean = (sum / n as f64) as f32;
    // Pass 2: variance
    let mut var_acc = 0.0_f64;
    for &v in x {
        let d = (v as f64) - (mean as f64);
        var_acc += d * d;
    }
    let variance = (var_acc / n as f64) as f32;
    let inv_std = 1.0_f32 / (variance + eps).sqrt();
    for i in 0..n {
        out[i] = (x[i] - mean) * inv_std;
    }
}

/// Welford single-pass algorithm — numerically stable for very
/// large D where the two-pass sum-of-squares loses precision。
pub fn layer_norm_welford(
    x: &[f32], out: &mut [f32], eps: f32,
) {
    debug_assert_eq!(x.len(), out.len());
    let n = x.len();
    if n == 0 { return; }
    let mut mean = 0.0_f64;
    let mut m2 = 0.0_f64;
    for (i, &v) in x.iter().enumerate() {
        let v = v as f64;
        let delta = v - mean;
        mean += delta / ((i + 1) as f64);
        let delta2 = v - mean;
        m2 += delta * delta2;
    }
    let variance = (m2 / n as f64) as f32;
    let mean_f = mean as f32;
    let inv_std = 1.0_f32 / (variance + eps).sqrt();
    for i in 0..n {
        out[i] = (x[i] - mean_f) * inv_std;
    }
}

/// Affine LayerNorm: y = γ × (x - μ) / sqrt(σ² + ε) + β
/// With 4-wide SIMD unrolled loops。 γ and β must have the
/// same length as x。
pub fn layer_norm_affine_simd(
    x: &[f32], gamma: &[f32], beta: &[f32],
    out: &mut [f32], eps: f32,
) {
    debug_assert_eq!(x.len(), out.len());
    debug_assert_eq!(x.len(), gamma.len());
    debug_assert_eq!(x.len(), beta.len());
    let n = x.len();
    if n == 0 { return; }

    // Pass 1: 4-wide sum
    let mut s0 = 0.0_f64;
    let mut s1 = 0.0_f64;
    let mut s2 = 0.0_f64;
    let mut s3 = 0.0_f64;
    let mut i = 0;
    while i + 4 <= n {
        s0 += x[i + 0] as f64;
        s1 += x[i + 1] as f64;
        s2 += x[i + 2] as f64;
        s3 += x[i + 3] as f64;
        i += 4;
    }
    let mut tail = 0.0_f64;
    while i < n { tail += x[i] as f64; i += 1; }
    let mean = ((s0 + s1) + (s2 + s3) + tail)
        / (n as f64);

    // Pass 2: 4-wide variance
    let mut v0 = 0.0_f64;
    let mut v1 = 0.0_f64;
    let mut v2 = 0.0_f64;
    let mut v3 = 0.0_f64;
    i = 0;
    while i + 4 <= n {
        let d0 = (x[i + 0] as f64) - mean;
        let d1 = (x[i + 1] as f64) - mean;
        let d2 = (x[i + 2] as f64) - mean;
        let d3 = (x[i + 3] as f64) - mean;
        v0 += d0 * d0;
        v1 += d1 * d1;
        v2 += d2 * d2;
        v3 += d3 * d3;
        i += 4;
    }
    let mut tail_v = 0.0_f64;
    while i < n {
        let d = (x[i] as f64) - mean;
        tail_v += d * d;
        i += 1;
    }
    let variance = (
        ((v0 + v1) + (v2 + v3) + tail_v) / (n as f64)
    ) as f32;
    let mean_f = mean as f32;
    let inv_std =
        1.0_f32 / (variance + eps).sqrt();

    // Pass 3: 4-wide normalize + affine
    i = 0;
    while i + 4 <= n {
        let n0 = (x[i + 0] - mean_f) * inv_std;
        let n1 = (x[i + 1] - mean_f) * inv_std;
        let n2 = (x[i + 2] - mean_f) * inv_std;
        let n3 = (x[i + 3] - mean_f) * inv_std;
        out[i + 0] = gamma[i + 0] * n0 + beta[i + 0];
        out[i + 1] = gamma[i + 1] * n1 + beta[i + 1];
        out[i + 2] = gamma[i + 2] * n2 + beta[i + 2];
        out[i + 3] = gamma[i + 3] * n3 + beta[i + 3];
        i += 4;
    }
    while i < n {
        let nn = (x[i] - mean_f) * inv_std;
        out[i] = gamma[i] * nn + beta[i];
        i += 1;
    }
}

/// Row-wise LayerNorm for a (rows × cols) matrix。 Each row
/// independently normalized。 Affine form (γ, β shared across
/// rows)。
pub fn layer_norm_rowwise_affine_simd(
    x: &[f32], gamma: &[f32], beta: &[f32],
    out: &mut [f32], eps: f32,
    rows: usize, cols: usize,
) {
    debug_assert_eq!(x.len(), rows * cols);
    debug_assert_eq!(out.len(), rows * cols);
    debug_assert_eq!(gamma.len(), cols);
    debug_assert_eq!(beta.len(), cols);
    for r in 0..rows {
        let start = r * cols;
        let row_in = &x[start..start + cols];
        let row_out = &mut out[start..start + cols];
        layer_norm_affine_simd(
            row_in, gamma, beta, row_out, eps);
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
    fn output_has_zero_mean_unit_variance() {
        let x: Vec<f32> = (0..16).map(|i|
            (i as f32) * 0.1 - 0.75).collect();
        let mut out = vec![0.0_f32; 16];
        layer_norm_naive(&x, &mut out, 1e-5);
        let mean: f32 = out.iter().sum::<f32>()
            / (out.len() as f32);
        assert!(mean.abs() < 1e-4);
        let var: f32 = out.iter().map(|v|
            (v - mean).powi(2)).sum::<f32>()
            / (out.len() as f32);
        // Variance should be ~1 (with small eps adjustment)
        assert!((var - 1.0).abs() < 1e-3);
    }

    #[test]
    fn welford_matches_naive() {
        let x: Vec<f32> = (0..32).map(|i|
            ((i as f32) * 0.13).sin()).collect();
        let mut a = vec![0.0_f32; 32];
        let mut b = vec![0.0_f32; 32];
        layer_norm_naive(&x, &mut a, 1e-5);
        layer_norm_welford(&x, &mut b, 1e-5);
        assert!(approx_eq(&a, &b, 1e-4));
    }

    #[test]
    fn affine_with_identity_matches_naive() {
        let x: Vec<f32> = (0..16).map(|i|
            (i as f32) * 0.1).collect();
        let gamma = vec![1.0_f32; 16];
        let beta = vec![0.0_f32; 16];
        let mut a = vec![0.0_f32; 16];
        let mut b = vec![0.0_f32; 16];
        layer_norm_naive(&x, &mut a, 1e-5);
        layer_norm_affine_simd(
            &x, &gamma, &beta, &mut b, 1e-5);
        assert!(approx_eq(&a, &b, 1e-4));
    }

    #[test]
    fn affine_scales_output() {
        let x: Vec<f32> = (0..8).map(|i|
            (i as f32) * 0.1).collect();
        let gamma = vec![2.0_f32; 8];
        let beta = vec![0.5_f32; 8];
        let mut affine = vec![0.0_f32; 8];
        let mut plain = vec![0.0_f32; 8];
        layer_norm_affine_simd(
            &x, &gamma, &beta, &mut affine, 1e-5);
        layer_norm_naive(&x, &mut plain, 1e-5);
        // affine = 2 * plain + 0.5
        for i in 0..8 {
            let expected = 2.0 * plain[i] + 0.5;
            assert!(
                (affine[i] - expected).abs() < 1e-4,
                "i={} affine={} expected={}",
                i, affine[i], expected);
        }
    }

    #[test]
    fn constant_input_zero_output() {
        // Variance of constant = 0 → output ≈ 0 after eps
        let x = [3.0_f32; 8];
        let mut out = [0.0_f32; 8];
        layer_norm_naive(&x, &mut out, 1e-5);
        for &v in &out {
            assert!(v.abs() < 1e-3,
                "constant input → near-zero output, got {}",
                v);
        }
    }

    #[test]
    fn rowwise_normalizes_each_row() {
        let rows = 3;
        let cols = 8;
        let mut x = vec![0.0_f32; rows * cols];
        for r in 0..rows {
            for c in 0..cols {
                x[r * cols + c] =
                    (r as f32) * 10.0 + (c as f32);
            }
        }
        let gamma = vec![1.0_f32; cols];
        let beta = vec![0.0_f32; cols];
        let mut out = vec![0.0_f32; rows * cols];
        layer_norm_rowwise_affine_simd(
            &x, &gamma, &beta, &mut out,
            1e-5, rows, cols);
        // Each row should have zero mean independently
        for r in 0..rows {
            let row_mean: f32 =
                out[r * cols..(r + 1) * cols]
                    .iter().sum::<f32>()
                / (cols as f32);
            assert!(row_mean.abs() < 1e-4);
        }
    }

    #[test]
    fn determinism() {
        let x: Vec<f32> = (0..64).map(|i|
            ((i as f32) * 0.07).sin()).collect();
        let mut a = vec![0.0_f32; 64];
        let mut b = vec![0.0_f32; 64];
        let mut c = vec![0.0_f32; 64];
        layer_norm_welford(&x, &mut a, 1e-5);
        layer_norm_welford(&x, &mut b, 1e-5);
        layer_norm_welford(&x, &mut c, 1e-5);
        assert_eq!(a, b);
        assert_eq!(b, c);
    }
}
