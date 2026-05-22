// MARK: - Tests for bas-mamba-scan
// chapter 八百六十五 / M2981 — extracted from lib.rs to keep that
// file under the 800-line god-file ceiling per coding-style.md。
// Lib.rs declares `#[cfg(test)] mod tests;` at the end,Rust auto-
// resolves this to src/tests.rs。 No semantic change — all tests
// run identically,still as part of `cargo test -p bas-mamba-scan`。

#![allow(clippy::needless_range_loop)]

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
    assert!(seq_ns > 0);
    assert!(par_ns > 0);
    assert!(v2_ns > 0);
    // chapter 八百六十四 / M2976 review-remediation:
    // assert the v2-vs-v1 win quantitatively。 Pre-fix this
    // was print-only,so a future regression making v2 slower
    // than v1 would not fail tests。 The chapter 八百六十三
    // measurement showed v2 3.23× faster than v1 at this
    // shape — guard against ≥1.5× regression with headroom
    // for noisy CI hardware。
    assert!(v2_ns < par_ns,
        "v2 must outperform v1 at this shape \
         (v2_ns={}, par_ns={}) — regression check",
        v2_ns, par_ns);
    assert!(v2_ns < seq_ns,
        "v2 must outperform sequential at large shape \
         (v2_ns={}, seq_ns={}) — Phase A rework regression check",
        v2_ns, seq_ns);
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

// MARK: - chapter 八百六十四 / M2976 review-remediation tests

/// Pin: v1 scan_parallel (now Rust-only oracle) is bit-equal
/// to v2 scan_parallel_v2 (now C ABI-backed)。 Reviewer flagged
/// that the original test grid only verified v2 ≡ sequential,
/// not v2 ≡ v1。 Both must hold because v1 is the byte-equality
/// oracle for v2's transparent C ABI swap (chapter 八百六十三)。
#[test]
fn scan_parallel_v1_bit_equals_v2_over_30_fixture_grid() {
    for trial in 0..30_u64 {
        let b = 1 + (trial % 6) as usize;
        let l = 4 + (trial % 14) as usize;
        let d = 1 + (trial % 7) as usize;
        let shape = make_shape(b as u32, l as u32, d as u32);
        let bld = shape.element_count();
        let mut state: u64 = trial.wrapping_mul(0xD00D).wrapping_add(0xFEED);
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
        let v1 = scan_parallel(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
        let v2 = scan_parallel_v2(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
        assert_eq!(v1, v2,
            "Trial {} (b={}, l={}, d={}):v1 oracle MUST bit-equal v2",
            trial, b, l, d);
    }
}

/// Pin: NaN/Inf input handling propagates correctly。 The
/// recurrence `h = exp(δ·A)·h + (δ·B)·x` produces NaN when
/// any of A / B / x / δ is NaN at the corresponding (b, t, d)
/// cell。 IEEE-754 guarantees NaN propagation,but we PIN it
/// across all 3 paths (seq / v1 / v2) to catch any future
/// optimization that breaks NaN semantics。
#[test]
fn scan_handles_nan_inputs_consistently_across_paths() {
    let shape = make_shape(1, 4, 2);
    let mut x = vec![1.0_f32; 8];
    x[2] = f32::NAN;  // inject NaN at idx 2 = (b=0,t=1,d=0)
    let delta = vec![0.1_f32; 8];
    let a = vec![-1.0_f32; 2];
    let b_proj = vec![1.0_f32; 8];
    let c_proj = vec![1.0_f32; 8];
    let seq = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
    let v1 = scan_parallel(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
    let v2 = scan_parallel_v2(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
    // For NaN comparisons we need to check is_nan parity (NaN != NaN)
    for i in 0..8 {
        assert_eq!(seq[i].is_nan(), v1[i].is_nan(),
            "idx {}: seq NaN-parity must match v1", i);
        assert_eq!(seq[i].is_nan(), v2[i].is_nan(),
            "idx {}: seq NaN-parity must match v2", i);
        if !seq[i].is_nan() {
            assert_eq!(seq[i], v1[i],
                "idx {}: non-NaN cells must bit-equal", i);
            assert_eq!(seq[i], v2[i],
                "idx {}: non-NaN cells must bit-equal", i);
        }
    }
}

#[test]
fn scan_handles_inf_inputs_consistently_across_paths() {
    let shape = make_shape(1, 2, 2);
    let x = vec![f32::INFINITY, 1.0, 1.0, 1.0];
    let delta = vec![0.1_f32; 4];
    let a = vec![-1.0_f32; 2];
    let b_proj = vec![1.0_f32; 4];
    let c_proj = vec![1.0_f32; 4];
    let seq = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
    let v1 = scan_parallel(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
    let v2 = scan_parallel_v2(&x, &delta, &a, &b_proj, &c_proj, shape).unwrap();
    for i in 0..4 {
        assert_eq!(seq[i].is_finite(), v1[i].is_finite(),
            "idx {}: seq finite-parity must match v1", i);
        assert_eq!(seq[i].is_finite(), v2[i].is_finite(),
            "idx {}: seq finite-parity must match v2", i);
    }
}

/// Pin: C ABI overflow guard rejects adversarial dimensions
/// that would overflow i64 multiplication。 Pre-八百六十四
/// guard used naive `(b as i64) * (l as i64) * (d as i64)`
/// which wraps at b=l=d ≈ 2.1M cubes (i64::MAX ≈ 9.2e18,
/// 2.1e6³ ≈ 9.3e18)。 The chapter 八百六十四 fix uses
/// checked_mul which returns None on wrap → reject as -1。
#[test]
fn c_abi_rejects_adversarial_dimensions_via_checked_mul() {
    let dummy = vec![1.0_f32; 1];
    let mut out = vec![0.0_f32; 1];
    // b=l=d=i32::MAX/2 → cube would overflow i64
    let big = i32::MAX / 2;
    let rc = unsafe {
        bas_mamba_scan_sequential(
            dummy.as_ptr(), dummy.as_ptr(), dummy.as_ptr(),
            dummy.as_ptr(), dummy.as_ptr(),
            big, big, big,
            out.as_mut_ptr(), 1)
    };
    assert_eq!(rc, -1,
        "Adversarial dims that overflow i64 must be rejected");
}
