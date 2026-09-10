use bas_mamba_scan::{
    scan_parallel, scan_parallel_v2, scan_sequential, MambaScanError, MambaScanShape,
};
use std::hint::black_box;
use std::time::Instant;

type ScanFn = fn(
    &[f32],
    &[f32],
    &[f32],
    &[f32],
    &[f32],
    MambaScanShape,
) -> Result<Vec<f32>, MambaScanError>;

// 0 = sequential, 1 = parallel v1, 2 = parallel v2
const WARMUP: [[usize; 3]; 3] = [[0, 1, 2], [1, 2, 0], [2, 0, 1]];
const MEASURED: [[usize; 3]; 6] = [
    [0, 1, 2],
    [0, 2, 1],
    [1, 0, 2],
    [1, 2, 0],
    [2, 0, 1],
    [2, 1, 0],
];

fn observed_call(
    scan: ScanFn,
    x: &[f32],
    delta: &[f32],
    a: &[f32],
    b_proj: &[f32],
    c_proj: &[f32],
    shape: MambaScanShape,
) {
    let output = scan(
        black_box(x),
        black_box(delta),
        black_box(a),
        black_box(b_proj),
        black_box(c_proj),
        black_box(shape),
    )
    .expect("timed scan must succeed");
    drop(black_box(output));
}

fn assert_bit_equal(actual: &[f32], expected: &[f32], implementation: &str) {
    assert_eq!(actual.len(), expected.len(), "{implementation} output length");
    for (index, (actual, expected)) in actual.iter().zip(expected).enumerate() {
        assert_eq!(
            actual.to_bits(),
            expected.to_bits(),
            "{implementation} differs from sequential at element {index}"
        );
    }
}

#[test]
fn scan_parallel_v2_perf_at_realistic_scale() {
    let shape = MambaScanShape {
        b: 8,
        l: 128,
        d: 128,
    };
    let bld = shape.element_count();
    let d_count = shape.d as usize;
    let x: Vec<f32> = (0..bld).map(|i| ((i % 23) as f32) * 0.013).collect();
    let delta: Vec<f32> = (0..bld)
        .map(|i| 0.05 + ((i % 17) as f32) * 0.001)
        .collect();
    let a: Vec<f32> = (0..d_count)
        .map(|i| -0.5 - (i as f32) * 0.1)
        .collect();
    let b_proj: Vec<f32> = (0..bld)
        .map(|i| 0.3 + ((i % 11) as f32) * 0.007)
        .collect();
    let c_proj: Vec<f32> = (0..bld)
        .map(|i| 1.1 + ((i % 13) as f32) * 0.005)
        .collect();

    let sequential = scan_sequential(&x, &delta, &a, &b_proj, &c_proj, shape)
        .expect("sequential preflight must succeed");
    let parallel = scan_parallel(&x, &delta, &a, &b_proj, &c_proj, shape)
        .expect("parallel v1 preflight must succeed");
    let parallel_v2 = scan_parallel_v2(&x, &delta, &a, &b_proj, &c_proj, shape)
        .expect("parallel v2 preflight must succeed");
    assert_bit_equal(&parallel, &sequential, "parallel v1");
    assert_bit_equal(&parallel_v2, &sequential, "parallel v2");

    let rayon_workers = rayon::current_num_threads();
    let available_parallelism = std::thread::available_parallelism()
        .map(|count| count.get())
        .ok();
    println!(
        "environment: global_rayon_workers={rayon_workers}, available_parallelism={available_parallelism:?}, debug_assertions={} (Cargo command/log is authoritative for profile)",
        cfg!(debug_assertions)
    );

    let scans: [ScanFn; 3] = [scan_sequential, scan_parallel, scan_parallel_v2];
    let mut warmup_counts = [0_usize; 3];
    for order in WARMUP {
        for implementation in order {
            observed_call(
                scans[implementation],
                &x,
                &delta,
                &a,
                &b_proj,
                &c_proj,
                shape,
            );
            warmup_counts[implementation] += 1;
        }
    }

    let mut measured_counts = [0_usize; 3];
    let mut elapsed_ns = [0_u128; 3];
    for order in MEASURED {
        for implementation in order {
            let start = Instant::now();
            for _ in 0..5 {
                observed_call(
                    scans[implementation],
                    &x,
                    &delta,
                    &a,
                    &b_proj,
                    &c_proj,
                    shape,
                );
                measured_counts[implementation] += 1;
            }
            elapsed_ns[implementation] += start.elapsed().as_nanos();
        }
    }

    assert_eq!(warmup_counts, [3; 3], "warmup call counts changed");
    assert_eq!(measured_counts, [30; 3], "measured call counts changed");

    let [seq_ns, par_ns, v2_ns] = elapsed_ns;
    let seq_ms = seq_ns as f64 / 1_000_000.0;
    let par_ms = par_ns as f64 / 1_000_000.0;
    let v2_ms = v2_ns as f64 / 1_000_000.0;

    println!("== scan performance [B=8 L=128 D=128; 30 measured calls/path] ==");
    println!("warmup_schedule={WARMUP:?}, measured_schedule={MEASURED:?}");
    println!("call_counts: warmup={warmup_counts:?}, measured={measured_counts:?}");
    println!("Rust seq:      {seq_ms:.3} ms total");
    println!(
        "Rust par (v1): {par_ms:.3} ms total (ratio vs seq {:.2}×)",
        par_ms / seq_ms
    );
    println!(
        "Rust par (v2): {v2_ms:.3} ms total (ratio vs seq {:.2}×, speedup vs v1 {:.2}×)",
        v2_ms / seq_ms,
        par_ms / v2_ms
    );

    assert!(seq_ns > 0);
    assert!(par_ns > 0);
    assert!(v2_ns > 0);
    assert!(
        v2_ns < par_ns,
        "v2 must outperform v1 at this shape (v2_ns={v2_ns}, par_ns={par_ns}) — regression check"
    );
    assert!(
        v2_ns < seq_ns,
        "v2 must outperform sequential at large shape (v2_ns={v2_ns}, seq_ns={seq_ns}) — Phase A rework regression check"
    );
}
