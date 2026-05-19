// SPDX:internal
//
// quantize.rs — chapter 七百二十六 第一刀 / M2301
//
// Symmetric int8 quantization primitives:net-new capability
// per the chapter 七百二十一-七百三十 aggressive evolution arc。
//
// ## Symmetric int8 quantization
//
// For a tensor x: f32 of length N,find the absolute-max:
//
//   amax = max(|x[i]|)
//   scale = amax / 127.0    (127 = i8::MAX,zero-symmetric range)
//
// Quantize:
//
//   q[i] = round(x[i] / scale).clamp(-128, 127) as i8
//
// Dequantize:
//
//   y[i] = q[i] as f32 * scale
//
// The round-trip introduces a per-element error bounded by
// (scale / 2):half a quantization bin。 For typical embedding
// values in [-1, 1] this means error ≤ ~0.004 (= 1/254)。
//
// ## int8 × int8 → f32 matmul
//
// C (m×n) = A (m×k, int8 + scale_a) × B (k×n, int8 + scale_b)
//
//   C[i,j] = sum_k A[i,k] as i32 * B[k,j] as i32
//           * scale_a * scale_b
//
// Accumulate in i32 to avoid intermediate overflow (each term
// fits in 16 bits;summing k of them fits comfortably in i32
// for k up to ~2^15)。 Final multiplication by scale_a * scale_b
// converts to f32 result。
//
// ## Why net-new
//
// Substrate is Float32 throughout。 int8 enables:
//   - 4× memory savings (1 byte/value vs 4 bytes/value)
//   - ~1.5× compute on M1/M2 (no AMX,modest perf win — but
//     still net positive once memory bandwidth dominates)
//
// Foundation for chapters 七百二十七 (int8 vector storage) +
// 七百二十八 (int8 KV cache) per the aggressive evolution arc。

/// Quantize a Float32 slice to int8 + scale。 Returns the
/// quantized buffer + the scale used。 Empty input returns
/// (empty,0.0)。
pub fn quantize_int8(x: &[f32]) -> (Vec<i8>, f32) {
    if x.is_empty() {
        return (Vec::new(), 0.0);
    }
    // amax = max(|x[i]|)
    let mut amax = 0.0f32;
    for &v in x {
        let abs_v = v.abs();
        if abs_v > amax { amax = abs_v; }
    }
    // Edge case:all zeros → scale = 0,quantized = all 0
    if amax == 0.0 {
        return (vec![0i8; x.len()], 0.0);
    }
    let scale = amax / 127.0;
    let inv_scale = 1.0 / scale;
    let q: Vec<i8> = x
        .iter()
        .map(|&v| {
            let raw = (v * inv_scale).round();
            // Clamp to [-128, 127] then cast
            let clamped = raw.max(-128.0).min(127.0);
            clamped as i8
        })
        .collect();
    (q, scale)
}

/// Dequantize int8 + scale back to Float32。 Empty input
/// returns empty vector。
pub fn dequantize_int8(q: &[i8], scale: f32) -> Vec<f32> {
    q.iter().map(|&v| (v as f32) * scale).collect()
}

/// int8 matrix multiplication producing Float32 output。
/// A is m × k row-major,B is k × n row-major,output C is
/// m × n row-major Float32。 scale_a and scale_b are the
/// quantization scales of A and B respectively。
///
/// Returns error string on shape mismatch。 Accumulates in
/// i32 to avoid overflow (k up to ~2^15 is safe)。
pub fn matmul_int8(
    a: &[i8], scale_a: f32,
    b: &[i8], scale_b: f32,
    m: usize, k: usize, n: usize,
) -> Result<Vec<f32>, String> {
    if a.len() != m * k {
        return Err(format!(
            "A length {} != m*k = {}", a.len(), m * k));
    }
    if b.len() != k * n {
        return Err(format!(
            "B length {} != k*n = {}", b.len(), k * n));
    }
    let combined_scale = scale_a * scale_b;
    let mut c = vec![0.0f32; m * n];
    for i in 0..m {
        for j in 0..n {
            let mut acc: i32 = 0;
            for kk in 0..k {
                let av = a[i * k + kk] as i32;
                let bv = b[kk * n + j] as i32;
                acc += av * bv;
            }
            c[i * n + j] = (acc as f32) * combined_scale;
        }
    }
    Ok(c)
}

/// Quantize + dequantize round-trip。 Used to measure the
/// quantization error envelope before downstream chapters
/// (七百二十七 / 七百二十八) commit to a cosine-drift gate。
pub fn quantize_dequantize_roundtrip(
    x: &[f32]
) -> Vec<f32> {
    let (q, scale) = quantize_int8(x);
    dequantize_int8(&q, scale)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_eq(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() <= tol
    }

    #[test]
    fn quantize_empty_returns_empty() {
        let (q, scale) = quantize_int8(&[]);
        assert!(q.is_empty());
        assert_eq!(scale, 0.0);
    }

    #[test]
    fn quantize_all_zeros_returns_all_zeros() {
        let (q, scale) = quantize_int8(&[0.0; 10]);
        assert_eq!(q, vec![0i8; 10]);
        assert_eq!(scale, 0.0);
    }

    #[test]
    fn quantize_single_value_round_trips_exactly() {
        let x = [1.0f32];
        let (q, scale) = quantize_int8(&x);
        assert_eq!(scale, 1.0 / 127.0);
        assert_eq!(q[0], 127); // max positive int8
        let y = dequantize_int8(&q, scale);
        assert!(approx_eq(y[0], 1.0, 1e-6));
    }

    #[test]
    fn quantize_symmetric_negative() {
        let x = [-1.0f32];
        let (q, scale) = quantize_int8(&x);
        assert_eq!(scale, 1.0 / 127.0);
        // -1.0 / scale = -127 exactly,fits in i8
        assert_eq!(q[0], -127);
        let y = dequantize_int8(&q, scale);
        assert!(approx_eq(y[0], -1.0, 1e-6));
    }

    #[test]
    fn quantize_round_trip_typical_embedding_values() {
        // Typical embedding values in [-1, 1]
        let x: Vec<f32> = (0..100)
            .map(|i| ((i as f32) / 50.0 - 1.0))
            .collect();
        let y = quantize_dequantize_roundtrip(&x);
        // Error per element ≤ scale / 2 = 1/254 ≈ 0.004
        for i in 0..x.len() {
            let err = (x[i] - y[i]).abs();
            assert!(
                err < 0.005,
                "i={} err={} x={} y={}",
                i, err, x[i], y[i]);
        }
    }

    #[test]
    fn quantize_scale_computed_from_amax() {
        let x = [0.5f32, -0.3, 0.8, -0.1];
        // amax = 0.8 → scale = 0.8/127
        let (_, scale) = quantize_int8(&x);
        assert!((scale - 0.8 / 127.0).abs() < 1e-7);
    }

    #[test]
    fn matmul_identity_returns_dequantized_input() {
        // A = [1.0, 0.5] (1×2 matrix)
        // B = identity (2×2):[[1, 0], [0, 1]]
        // C = A × B should ≈ A (within quantization error)
        let a_f32 = [1.0f32, 0.5];
        let (a_q, a_scale) = quantize_int8(&a_f32);
        let b_f32 = [1.0f32, 0.0, 0.0, 1.0];
        let (b_q, b_scale) = quantize_int8(&b_f32);
        let c = matmul_int8(
            &a_q, a_scale,
            &b_q, b_scale,
            1, 2, 2).unwrap();
        assert_eq!(c.len(), 2);
        // Each output ≤ ~quantization error away from A
        assert!((c[0] - 1.0).abs() < 0.02);
        assert!((c[1] - 0.5).abs() < 0.02);
    }

    #[test]
    fn matmul_shape_mismatch_returns_error() {
        let a = vec![0i8; 4];
        let b = vec![0i8; 4];
        // a.len() = 4 ≠ 2*3 = 6
        let r = matmul_int8(
            &a, 1.0,
            &b, 1.0,
            2, 3, 2);
        assert!(r.is_err());
    }

    #[test]
    fn matmul_2x2_times_2x2_produces_correct_shape() {
        // Just smoke-check the shape is right
        let a_f32 = [1.0f32, 0.5, 0.3, 0.7];
        let b_f32 = [0.2f32, 0.4, 0.1, 0.6];
        let (a_q, a_scale) = quantize_int8(&a_f32);
        let (b_q, b_scale) = quantize_int8(&b_f32);
        let c = matmul_int8(
            &a_q, a_scale,
            &b_q, b_scale,
            2, 2, 2).unwrap();
        assert_eq!(c.len(), 4);
    }

    #[test]
    fn matmul_against_f32_reference_within_drift() {
        // 4×3 × 3×2 = 4×2
        let a_f32 = [
            0.5, 0.1, 0.3,
            0.2, 0.7, 0.4,
            0.6, 0.5, 0.1,
            0.3, 0.8, 0.2,
        ];
        let b_f32 = [
            0.4, 0.2,
            0.1, 0.6,
            0.3, 0.5,
        ];
        // Float32 reference
        let m = 4; let k = 3; let n = 2;
        let mut c_ref = vec![0.0f32; m * n];
        for i in 0..m {
            for j in 0..n {
                let mut acc = 0.0f32;
                for kk in 0..k {
                    acc += a_f32[i*k+kk] * b_f32[kk*n+j];
                }
                c_ref[i*n+j] = acc;
            }
        }
        // int8 matmul
        let (a_q, sa) = quantize_int8(&a_f32);
        let (b_q, sb) = quantize_int8(&b_f32);
        let c_q = matmul_int8(
            &a_q, sa,
            &b_q, sb,
            m, k, n).unwrap();
        // Per-element drift bounded by k * scale_a * scale_b
        // ≈ 3 * (1/254)² ≈ 1e-4 for these values。 Use a
        // conservative 0.01 absolute drift gate。
        for i in 0..(m * n) {
            assert!(
                (c_q[i] - c_ref[i]).abs() < 0.01,
                "drift at i={}:int8 {} vs f32 {}",
                i, c_q[i], c_ref[i]);
        }
    }

    #[test]
    fn quantization_memory_is_4x_smaller() {
        // 1024 Float32 → 1024 int8 + 1 scale = 1029 bytes
        // vs 4096 bytes Float32。 ~3.98× savings。
        let x: Vec<f32> = (0..1024)
            .map(|i| (i as f32 / 1024.0))
            .collect();
        let (q, _) = quantize_int8(&x);
        let f32_bytes = x.len() * 4;
        let int8_bytes = q.len() + 4; // +4 for scale
        let ratio = f32_bytes as f32 / int8_bytes as f32;
        assert!(
            ratio > 3.9 && ratio < 4.1,
            "expected ~4× savings got {}", ratio);
    }
}
