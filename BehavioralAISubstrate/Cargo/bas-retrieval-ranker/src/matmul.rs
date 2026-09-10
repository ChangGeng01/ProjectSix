// SPDX:internal
//
// matmul.rs — chapter 七百八 第一刀 / M2211
//
// Cache-blocked + SIMD-unrolled f32 matrix multiplication for
// the substrate's CPU path。 Three variants:
//
//   - matmul_naive(a, b, c, m, n, k)        : reference O(MNK) impl
//   - matmul_blocked(a, b, c, m, n, k)      : 64-byte cache tiles
//   - matmul_simd_blocked(a, b, c, m, n, k) : + 4-wide inner unroll
//
// All operate on row-major float32 buffers:
//   A is M×K, B is K×N, C (output) is M×N
//   C[i][j] = Σₖ A[i][k] × B[k][j]
//
// Cache-blocking pulls B's column slice into a per-tile workspace
// so the inner loop reuses cache lines instead of striding across
// N rows of B per element of C。 The block size (BLOCK = 32) is
// chosen to keep three blocks (A-tile + B-tile + C-tile) within
// the M-series L1 cache (32 KB)。

use std::cmp::min;

/// Block size in element count。 At f32 each block is 32×32×4 =
/// 4 KB,three blocks = 12 KB — comfortable L1 fit。
const BLOCK: usize = 32;

/// Reference naive O(MNK) matrix multiplication。 Used as the
/// "always correct" oracle in cross-impl byte-equality tests。
pub fn matmul_naive(
    a: &[f32], b: &[f32], c: &mut [f32],
    m: usize, n: usize, k: usize,
) {
    debug_assert_eq!(a.len(), m * k);
    debug_assert_eq!(b.len(), k * n);
    debug_assert_eq!(c.len(), m * n);
    for i in 0..m {
        for j in 0..n {
            let mut acc: f32 = 0.0;
            for kk in 0..k {
                acc += a[i * k + kk] * b[kk * n + j];
            }
            c[i * n + j] = acc;
        }
    }
}

/// Cache-blocked matrix multiplication。 Tiles A, B, and C into
/// BLOCK×BLOCK chunks。 Within each tile the i-k-j loop order
/// reuses B's row across all i in the tile。 Faster than naive
/// for medium-large matrices (≥ 64×64) due to cache locality。
pub fn matmul_blocked(
    a: &[f32], b: &[f32], c: &mut [f32],
    m: usize, n: usize, k: usize,
) {
    debug_assert_eq!(a.len(), m * k);
    debug_assert_eq!(b.len(), k * n);
    debug_assert_eq!(c.len(), m * n);
    // Zero output first — accumulator pattern needs clean C
    for c_elem in c.iter_mut() { *c_elem = 0.0; }
    let mut i = 0;
    while i < m {
        let ii_end = min(i + BLOCK, m);
        let mut kk = 0;
        while kk < k {
            let kk_end = min(kk + BLOCK, k);
            let mut j = 0;
            while j < n {
                let jj_end = min(j + BLOCK, n);
                // Inner tile loops with i-k-j order — B's
                // row is reused across i values within the
                // tile,A's element across j values。
                for ii in i..ii_end {
                    for kkk in kk..kk_end {
                        let a_ik = a[ii * k + kkk];
                        let b_row_start = kkk * n;
                        let c_row_start = ii * n;
                        for jjj in j..jj_end {
                            c[c_row_start + jjj] += a_ik
                                * b[b_row_start + jjj];
                        }
                    }
                }
                j += BLOCK;
            }
            kk += BLOCK;
        }
        i += BLOCK;
    }
}

/// Blocked + 4-wide SIMD-unrolled。 Same as `matmul_blocked` but
/// with the innermost j-loop manually unrolled by 4 so LLVM
/// auto-vectorizes to NEON / SSE。 Best CPU performance for
/// matrices where N is a multiple of 4 (typical for ML tensors)。
pub fn matmul_simd_blocked(
    a: &[f32], b: &[f32], c: &mut [f32],
    m: usize, n: usize, k: usize,
) {
    debug_assert_eq!(a.len(), m * k);
    debug_assert_eq!(b.len(), k * n);
    debug_assert_eq!(c.len(), m * n);
    for c_elem in c.iter_mut() { *c_elem = 0.0; }
    let mut i = 0;
    while i < m {
        let ii_end = min(i + BLOCK, m);
        let mut kk = 0;
        while kk < k {
            let kk_end = min(kk + BLOCK, k);
            let mut j = 0;
            while j < n {
                let jj_end = min(j + BLOCK, n);
                for ii in i..ii_end {
                    for kkk in kk..kk_end {
                        let a_ik = a[ii * k + kkk];
                        let b_row = kkk * n;
                        let c_row = ii * n;
                        // 4-wide unrolled inner loop
                        let mut jjj = j;
                        while jjj + 4 <= jj_end {
                            c[c_row + jjj + 0] +=
                                a_ik * b[b_row + jjj + 0];
                            c[c_row + jjj + 1] +=
                                a_ik * b[b_row + jjj + 1];
                            c[c_row + jjj + 2] +=
                                a_ik * b[b_row + jjj + 2];
                            c[c_row + jjj + 3] +=
                                a_ik * b[b_row + jjj + 3];
                            jjj += 4;
                        }
                        while jjj < jj_end {
                            c[c_row + jjj] += a_ik
                                * b[b_row + jjj];
                            jjj += 1;
                        }
                    }
                }
                j += BLOCK;
            }
            kk += BLOCK;
        }
        i += BLOCK;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_eq_arrays(
        a: &[f32], b: &[f32], tol: f32
    ) -> bool {
        if a.len() != b.len() { return false; }
        for i in 0..a.len() {
            if (a[i] - b[i]).abs() > tol {
                return false;
            }
        }
        true
    }

    #[test]
    fn naive_2x2_known() {
        // A = [[1, 2], [3, 4]]
        // B = [[5, 6], [7, 8]]
        // C = [[19, 22], [43, 50]]
        let a = [1.0, 2.0, 3.0, 4.0];
        let b = [5.0, 6.0, 7.0, 8.0];
        let mut c = [0.0_f32; 4];
        matmul_naive(&a, &b, &mut c, 2, 2, 2);
        assert_eq!(c, [19.0, 22.0, 43.0, 50.0]);
    }

    #[test]
    fn blocked_matches_naive_small() {
        let m = 4; let n = 4; let k = 4;
        let a: Vec<f32> = (0..m*k).map(|i|
            (i as f32) * 0.1).collect();
        let b: Vec<f32> = (0..k*n).map(|i|
            (i as f32) * 0.2).collect();
        let mut c_naive = vec![0.0_f32; m * n];
        let mut c_blocked = vec![0.0_f32; m * n];
        matmul_naive(&a, &b, &mut c_naive, m, n, k);
        matmul_blocked(&a, &b, &mut c_blocked, m, n, k);
        assert!(approx_eq_arrays(
            &c_naive, &c_blocked, 1e-4));
    }

    #[test]
    fn blocked_matches_naive_medium() {
        let m = 64; let n = 48; let k = 32;
        let a: Vec<f32> = (0..m*k).map(|i|
            ((i as f32) * 0.013).sin()).collect();
        let b: Vec<f32> = (0..k*n).map(|i|
            ((i as f32) * 0.017).cos()).collect();
        let mut c_naive = vec![0.0_f32; m * n];
        let mut c_blocked = vec![0.0_f32; m * n];
        matmul_naive(&a, &b, &mut c_naive, m, n, k);
        matmul_blocked(&a, &b, &mut c_blocked, m, n, k);
        assert!(approx_eq_arrays(
            &c_naive, &c_blocked, 1e-3));
    }

    #[test]
    fn simd_blocked_matches_naive() {
        let m = 32; let n = 64; let k = 16;
        let a: Vec<f32> = (0..m*k).map(|i|
            ((i as f32) * 0.011).sin()).collect();
        let b: Vec<f32> = (0..k*n).map(|i|
            ((i as f32) * 0.019).cos()).collect();
        let mut c_naive = vec![0.0_f32; m * n];
        let mut c_simd = vec![0.0_f32; m * n];
        matmul_naive(&a, &b, &mut c_naive, m, n, k);
        matmul_simd_blocked(
            &a, &b, &mut c_simd, m, n, k);
        assert!(approx_eq_arrays(
            &c_naive, &c_simd, 1e-3));
    }

    #[test]
    fn identity_matmul() {
        // I * A = A
        let m = 3; let n = 3; let k = 3;
        let identity = [
            1.0_f32, 0.0, 0.0,
            0.0,     1.0, 0.0,
            0.0,     0.0, 1.0,
        ];
        let a = [
            0.1_f32, 0.2, 0.3,
            0.4,     0.5, 0.6,
            0.7,     0.8, 0.9,
        ];
        let mut c = [0.0_f32; 9];
        matmul_naive(&identity, &a, &mut c, m, n, k);
        assert!(approx_eq_arrays(&c, &a, 1e-6));
        let mut c2 = [0.0_f32; 9];
        matmul_simd_blocked(
            &identity, &a, &mut c2, m, n, k);
        assert!(approx_eq_arrays(&c2, &a, 1e-6));
    }

    #[test]
    fn non_square_shapes() {
        // 3x5 * 5x2 = 3x2
        let m = 3; let n = 2; let k = 5;
        let a: Vec<f32> = (0..m*k).map(|i|
            (i as f32) * 0.1).collect();
        let b: Vec<f32> = (0..k*n).map(|i|
            (i as f32) * 0.1).collect();
        let mut c_naive = vec![0.0_f32; m * n];
        let mut c_blocked = vec![0.0_f32; m * n];
        let mut c_simd = vec![0.0_f32; m * n];
        matmul_naive(&a, &b, &mut c_naive, m, n, k);
        matmul_blocked(&a, &b, &mut c_blocked, m, n, k);
        matmul_simd_blocked(
            &a, &b, &mut c_simd, m, n, k);
        assert!(approx_eq_arrays(
            &c_naive, &c_blocked, 1e-4));
        assert!(approx_eq_arrays(
            &c_naive, &c_simd, 1e-4));
    }

    #[test]
    fn zero_matrices() {
        let m = 4; let n = 4; let k = 4;
        let a = vec![0.0_f32; m * k];
        let b = vec![0.0_f32; k * n];
        let mut c = vec![1.0_f32; m * n];
        matmul_naive(&a, &b, &mut c, m, n, k);
        assert!(c.iter().all(|&v| v == 0.0));
    }
}
