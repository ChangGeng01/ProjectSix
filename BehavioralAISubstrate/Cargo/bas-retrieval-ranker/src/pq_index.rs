// SPDX:internal
//
// pq_index.rs — chapter 七百二十九 第一刀 / M2316
//
// Product Quantization (PQ) approximate-nearest-neighbor index。
// Net-new capability per the chapter 七百二十一-七百三十
// aggressive evolution plan。 Pragmatic landing:lives as a
// module in bas-retrieval-ranker rather than a separate crate
// (per chapter 七百二十三 / 七百二十五 / 七百二十六 lessons
// about not overengineering with extra crates)。
//
// ## PQ in 4 sentences
//
// 1. Split D-dim vectors into M subvectors of D/M dim each
//    (e.g。 D=128, M=8 → 16-dim subvectors)。
// 2. K-means each subvector space to K centroids;each
//    subvector compresses to log2(K) bits (typ 8 bits for
//    K=256;here K=16 → 4 bits per code,so M=8 bytes per
//    vector instead of 4×D=512 bytes for Float32 dim 128)。
// 3. At query time:precompute M × K distance LUT from
//    query subvectors to centroids,then per-corpus-vector
//    distance is sum of M LUT lookups (no float ops in the
//    inner loop)。
// 4. Top-K via partial sort over the precomputed distances。
//
// ## Honest scope acknowledgments
//
// - K=16 (4-bit codes) keeps training fast + memory tight。
//   Production-grade PQ libraries use K=256 (8-bit) for
//   higher recall;substrate's small typical corpus (1K-10K)
//   doesn't justify the extra training time。
// - K-means uses random init + bounded Lloyd iterations (no
//   K-means++);good enough for asymmetric-distance accuracy
//   at the substrate's scale。
// - L2-NORMALIZED vectors only (the substrate convention)。
//   For unnormalized vectors,replace L2 with cosine-aware
//   distance (TBD if a host requests)。

use std::collections::HashMap;

/// Compact PQ index。 Stores codebooks (M × K × subDim
/// Float32) and per-corpus-row codes (M bytes per row)。
#[derive(Clone, Debug)]
pub struct PqIndex {
    pub dim: usize,         // original vector dim
    pub m: usize,           // subquantizers
    pub k: usize,           // codes per subquantizer
    pub sub_dim: usize,     // dim / m
    pub codebooks: Vec<f32>, // m × k × sub_dim
    pub codes: Vec<u8>,      // n × m flat
    pub n_rows: usize,
}

impl PqIndex {

    /// Construct an UNTRAINED PQ index。 Caller calls
    /// `train(...)` next。 Returns Err if dim not divisible by
    /// m or if k > 256 (codes are u8)。
    pub fn new(
        dim: usize, m: usize, k: usize,
    ) -> Result<Self, String> {
        if dim == 0 || m == 0 {
            return Err("dim and m must be > 0".to_string());
        }
        if dim % m != 0 {
            return Err(format!(
                "dim {} not divisible by m {}", dim, m));
        }
        if k > 256 {
            return Err("k must be ≤ 256 (codes are u8)".to_string());
        }
        let sub_dim = dim / m;
        Ok(Self {
            dim, m, k, sub_dim,
            codebooks: vec![0.0; m * k * sub_dim],
            codes: Vec::new(),
            n_rows: 0,
        })
    }

    /// Train codebooks via per-subquantizer k-means。 Caller
    /// provides `training_set` (n_train × dim row-major)。
    /// `iters` is the number of Lloyd iterations (8-16 is
    /// typical;more for higher quality)。
    pub fn train(
        &mut self,
        training_set: &[f32],
        n_train: usize,
        iters: usize,
    ) -> Result<(), String> {
        if training_set.len() != n_train * self.dim {
            return Err(format!(
                "training_set length {} != n_train * dim = {}",
                training_set.len(), n_train * self.dim));
        }
        if n_train < self.k {
            return Err(format!(
                "n_train {} < k {} (need ≥ k samples to seed centroids)",
                n_train, self.k));
        }

        // Train each subquantizer independently。 Subspace
        // m_idx spans dim offsets [m_idx*sub_dim,
        // (m_idx+1)*sub_dim)。
        for m_idx in 0..self.m {
            let subdim = self.sub_dim;
            let offset = m_idx * subdim;
            // Extract subvectors:n_train × subdim
            let mut subvecs: Vec<f32> =
                Vec::with_capacity(n_train * subdim);
            for row in 0..n_train {
                let start = row * self.dim + offset;
                subvecs.extend_from_slice(
                    &training_set[start..start + subdim]);
            }
            // Initialize K centroids via stride sampling
            // (deterministic, not K-means++)
            let mut centroids: Vec<f32> =
                vec![0.0; self.k * subdim];
            let stride = n_train / self.k;
            for c in 0..self.k {
                let src = c * stride;
                let s_off = src * subdim;
                let c_off = c * subdim;
                centroids[c_off..c_off + subdim]
                    .copy_from_slice(
                        &subvecs[s_off..s_off + subdim]);
            }

            // Lloyd iterations
            for _ in 0..iters {
                // Assign each subvector to nearest centroid
                let mut sums: Vec<f32> =
                    vec![0.0; self.k * subdim];
                let mut counts: Vec<usize> =
                    vec![0; self.k];
                for row in 0..n_train {
                    let v_off = row * subdim;
                    let v = &subvecs[v_off..v_off + subdim];
                    let mut best_c = 0;
                    let mut best_d = f32::MAX;
                    for c in 0..self.k {
                        let c_off = c * subdim;
                        let cent =
                            &centroids[c_off..c_off + subdim];
                        let mut d = 0.0f32;
                        for i in 0..subdim {
                            let diff = v[i] - cent[i];
                            d += diff * diff;
                        }
                        if d < best_d {
                            best_d = d;
                            best_c = c;
                        }
                    }
                    let s_off = best_c * subdim;
                    for i in 0..subdim {
                        sums[s_off + i] += v[i];
                    }
                    counts[best_c] += 1;
                }
                // Update centroids
                for c in 0..self.k {
                    if counts[c] > 0 {
                        let c_off = c * subdim;
                        let n_c = counts[c] as f32;
                        for i in 0..subdim {
                            centroids[c_off + i] =
                                sums[c_off + i] / n_c;
                        }
                    }
                }
            }

            // Store this subquantizer's codebook
            let dst_off = m_idx * self.k * subdim;
            self.codebooks[dst_off..dst_off + self.k * subdim]
                .copy_from_slice(&centroids);
        }
        Ok(())
    }

    /// Encode a single vector as M bytes (one code per
    /// subquantizer)。 Each code is the index of the closest
    /// centroid in that subspace。
    pub fn encode(&self, vector: &[f32]) -> Option<Vec<u8>> {
        if vector.len() != self.dim { return None; }
        let mut codes = vec![0u8; self.m];
        for m_idx in 0..self.m {
            let v_off = m_idx * self.sub_dim;
            let v = &vector[v_off..v_off + self.sub_dim];
            let cb_off = m_idx * self.k * self.sub_dim;
            let mut best_c = 0usize;
            let mut best_d = f32::MAX;
            for c in 0..self.k {
                let c_off = cb_off + c * self.sub_dim;
                let cent =
                    &self.codebooks[c_off..c_off + self.sub_dim];
                let mut d = 0.0f32;
                for i in 0..self.sub_dim {
                    let diff = v[i] - cent[i];
                    d += diff * diff;
                }
                if d < best_d {
                    best_d = d;
                    best_c = c;
                }
            }
            codes[m_idx] = best_c as u8;
        }
        Some(codes)
    }

    /// Add a single vector to the index (encode + append)。
    pub fn add(&mut self, vector: &[f32]) -> Option<usize> {
        let codes = self.encode(vector)?;
        self.codes.extend_from_slice(&codes);
        let id = self.n_rows;
        self.n_rows += 1;
        Some(id)
    }

    /// top-K nearest neighbors。 Returns up to `k_results`
    /// (row_idx,distance²) pairs sorted by distance ascending。
    /// Uses asymmetric distance:precompute query → centroid
    /// LUT,then per-row distance is a sum of M LUT lookups
    /// (no float ops in the inner loop)。
    pub fn top_k(
        &self, query: &[f32], k_results: usize,
    ) -> Option<Vec<(usize, f32)>> {
        if query.len() != self.dim { return None; }
        if k_results == 0 || self.n_rows == 0 {
            return Some(Vec::new());
        }
        // Precompute LUT: M × K distance²(query subvec, centroid)
        let mut lut = vec![0.0f32; self.m * self.k];
        for m_idx in 0..self.m {
            let q_off = m_idx * self.sub_dim;
            let q = &query[q_off..q_off + self.sub_dim];
            let cb_off = m_idx * self.k * self.sub_dim;
            for c in 0..self.k {
                let c_off = cb_off + c * self.sub_dim;
                let cent =
                    &self.codebooks[c_off..c_off + self.sub_dim];
                let mut d = 0.0f32;
                for i in 0..self.sub_dim {
                    let diff = q[i] - cent[i];
                    d += diff * diff;
                }
                lut[m_idx * self.k + c] = d;
            }
        }
        // Score every row using LUT lookups
        let mut scored: Vec<(usize, f32)> =
            Vec::with_capacity(self.n_rows);
        for row in 0..self.n_rows {
            let r_off = row * self.m;
            let mut d = 0.0f32;
            for m_idx in 0..self.m {
                let code = self.codes[r_off + m_idx] as usize;
                d += lut[m_idx * self.k + code];
            }
            scored.push((row, d));
        }
        // Sort ascending by distance,truncate to k_results
        scored.sort_by(|a, b|
            a.1.partial_cmp(&b.1)
                .unwrap_or(std::cmp::Ordering::Equal));
        scored.truncate(k_results);
        Some(scored)
    }

    /// Memory footprint in bytes (codebooks + codes)。
    pub fn byte_size(&self) -> usize {
        self.codebooks.len() * 4
            + self.codes.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn unit_vector(seed: u64, dim: usize) -> Vec<f32> {
        let mut s = seed;
        let mut v = Vec::with_capacity(dim);
        for _ in 0..dim {
            s = s.wrapping_mul(6364136223846793005)
                .wrapping_add(1442695040888963407);
            let u = (s >> 33) as f32 / 2147483648.0 - 1.0;
            v.push(u);
        }
        let mag: f32 = v.iter().map(|x| x*x).sum::<f32>().sqrt();
        if mag > 0.0 {
            for x in v.iter_mut() { *x /= mag; }
        }
        v
    }

    #[test]
    fn pq_index_construction_validates_dimensions() {
        // dim must be divisible by m
        assert!(PqIndex::new(127, 8, 16).is_err());
        // k must be ≤ 256
        assert!(PqIndex::new(128, 8, 300).is_err());
        // zero dim
        assert!(PqIndex::new(0, 8, 16).is_err());
        // OK
        let p = PqIndex::new(128, 8, 16).unwrap();
        assert_eq!(p.dim, 128);
        assert_eq!(p.m, 8);
        assert_eq!(p.k, 16);
        assert_eq!(p.sub_dim, 16);
    }

    #[test]
    fn pq_train_runs_at_small_scale() {
        let dim = 32;
        let n = 64;
        let mut training: Vec<f32> = Vec::with_capacity(n * dim);
        for i in 0..n {
            training.extend(unit_vector(
                i as u64 * 13 + 1, dim));
        }
        let mut pq = PqIndex::new(dim, 4, 8).unwrap();
        // K = 8 < n = 64 OK
        pq.train(&training, n, 4).unwrap();
        // codebooks now contain trained centroids
        // (4 subquantizers × 8 codes × 8 sub-dim = 256 floats)
        assert_eq!(pq.codebooks.len(), 4 * 8 * 8);
    }

    #[test]
    fn pq_encode_returns_m_codes() {
        let dim = 32;
        let n = 64;
        let mut training: Vec<f32> = Vec::with_capacity(n * dim);
        for i in 0..n {
            training.extend(unit_vector(
                i as u64 * 13 + 1, dim));
        }
        let mut pq = PqIndex::new(dim, 4, 8).unwrap();
        pq.train(&training, n, 4).unwrap();
        let v = unit_vector(999, dim);
        let codes = pq.encode(&v).unwrap();
        assert_eq!(codes.len(), 4);
        for &c in &codes {
            assert!(c < 8);
        }
    }

    #[test]
    fn pq_add_increments_n_rows() {
        let dim = 32;
        let n = 64;
        let mut training: Vec<f32> = Vec::with_capacity(n * dim);
        for i in 0..n {
            training.extend(unit_vector(
                i as u64 * 13 + 1, dim));
        }
        let mut pq = PqIndex::new(dim, 4, 8).unwrap();
        pq.train(&training, n, 4).unwrap();
        for i in 0..10 {
            let v = unit_vector(2000 + i, dim);
            pq.add(&v);
        }
        assert_eq!(pq.n_rows, 10);
        assert_eq!(pq.codes.len(), 10 * 4);
    }

    #[test]
    fn pq_top_k_recovers_self_within_top_3() {
        let dim = 32;
        let n_train = 256;
        let mut training: Vec<f32> = Vec::with_capacity(
            n_train * dim);
        for i in 0..n_train {
            training.extend(unit_vector(
                i as u64 * 13 + 1, dim));
        }
        let mut pq = PqIndex::new(dim, 4, 16).unwrap();
        pq.train(&training, n_train, 8).unwrap();
        // Add 100 corpus vectors
        let mut corpus: Vec<Vec<f32>> = Vec::with_capacity(100);
        for i in 0..100 {
            let v = unit_vector(5000 + i, dim);
            corpus.push(v.clone());
            pq.add(&v);
        }
        // Query is one of the corpus vectors — should find
        // itself in top-3 (PQ approximation may not put it
        // at the top,but it should rank highly)
        let query = corpus[42].clone();
        let result = pq.top_k(&query, 3).unwrap();
        let top_ids: Vec<usize> = result
            .iter()
            .map(|(id, _)| *id)
            .collect();
        assert!(
            top_ids.contains(&42),
            "expected 42 in top-3, got {:?}", top_ids);
    }

    #[test]
    fn pq_byte_size_smaller_than_float32_equivalent() {
        let dim = 128;
        let n_train = 256;
        let mut training: Vec<f32> = Vec::with_capacity(
            n_train * dim);
        for i in 0..n_train {
            training.extend(unit_vector(
                i as u64 * 13 + 1, dim));
        }
        let mut pq = PqIndex::new(dim, 8, 16).unwrap();
        pq.train(&training, n_train, 8).unwrap();
        // Add 10000 corpus vectors
        let n_corpus = 10000;
        for i in 0..n_corpus {
            let v = unit_vector(50000 + i, dim);
            pq.add(&v);
        }
        let pq_bytes = pq.byte_size();
        let f32_bytes = n_corpus as usize * dim * 4;
        // PQ codes alone: n_corpus × m = 10000 × 8 = 80KB
        // Codebooks: m × k × sub_dim × 4 = 8 × 16 × 16 × 4 = 8KB
        // Total: ~88 KB vs 5120 KB Float32 → ~58× shrink
        let ratio = f32_bytes as f32 / pq_bytes as f32;
        assert!(
            ratio > 30.0,
            "expected ≥ 30× shrink, got {}", ratio);
    }

    #[test]
    fn pq_train_rejects_too_few_samples() {
        let mut pq = PqIndex::new(32, 4, 16).unwrap();
        // 8 samples < k = 16
        let training: Vec<f32> = vec![0.0; 8 * 32];
        assert!(pq.train(&training, 8, 4).is_err());
    }
}
