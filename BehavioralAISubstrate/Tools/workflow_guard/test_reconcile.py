"""Teeth for the workflow completeness guard. Run: python3 test_reconcile.py"""
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reconcile_workflow as rw


def _journal(results):
    fd, path = tempfile.mkstemp(suffix=".jsonl")
    with os.fdopen(fd, "w") as f:
        for r in results:
            f.write(json.dumps({"type": "result", "key": "v2:x", "result": r}) + "\n")
    return path


def test_silent_drop_detected_by_expect():
    # THE case that burned me twice: 19 results but usage reported 20 agents (one died).
    p = _journal([{"survives": True, "name": f"lever-{i}"} for i in range(19)])
    try:
        results = rw.load_results(p)
        assert len(results) == 19
        # expect=20 ⇒ gap
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = rw.main.__wrapped__() if hasattr(rw.main, "__wrapped__") else None
    finally:
        os.unlink(p)
    # direct call path
    p = _journal([{"survives": True, "name": f"lever-{i}"} for i in range(19)])
    try:
        sys.argv = ["x", p, "--expect", "20"]
        rc = rw.main()
        assert rc == 1, "expect>results must flag the silent drop (exit 1)"
    finally:
        os.unlink(p)


def test_clean_run_passes():
    p = _journal([{"survives": True, "name": f"l{i}"} for i in range(20)])
    try:
        sys.argv = ["x", p, "--expect", "20"]
        assert rw.main() == 0, "results == expected ⇒ clean"
    finally:
        os.unlink(p)


def test_candidate_verdict_diff_names_the_dropped():
    # A producer emits 3 levers; only 2 get a verdict → the 3rd is un-adjudicated.
    producer = {"levers": [{"name": "A"}, {"name": "B"}, {"name": "C"}]}
    verdicts = [{"name": "A", "survives": True}, {"name": "B", "survives": False}]
    p = _journal([producer, *verdicts])
    try:
        cand, verd = rw.candidate_verdict_diff(rw.load_results(p))
        assert set(cand) == {"A", "B", "C"}
        assert set(verd) == {"A", "B"}
        sys.argv = ["x", p]   # no --expect; the diff path fires
        assert rw.main() == 1, "the un-adjudicated C must be flagged"
    finally:
        os.unlink(p)


def test_empty_result_flagged():
    p = _journal([{"survives": True, "name": "ok"}, None, {}])
    try:
        sys.argv = ["x", p, "--expect", "3"]
        assert rw.main() == 1, "empty/None result payloads must be flagged"
    finally:
        os.unlink(p)


def test_nextgen_shape_20_vs_19():
    # The real nextgen-decode-levers shape: 5 producers (levers[]) + 19 verdicts, expect=26
    # agents (5 innovate + 1 compound + 20 refute — but 1 refute died → 19 verdicts, 25 results).
    producers = [{"levers": [{"name": f"lever-{i}-{j}"} for j in range(4)]} for i in range(5)]
    verdicts = [{"name": f"lever-{i}-{j}", "survives": (i + j) % 3 != 0}
                for i in range(5) for j in range(4)][:19]  # one dropped
    p = _journal([*producers, *verdicts])
    try:
        sys.argv = ["x", p, "--expect", "26"]   # 5+1+20 expected, 24 present
        rc = rw.main()
        assert rc == 1, "the nextgen 26→24 silent drop must be caught mechanically"
    finally:
        os.unlink(p)


if __name__ == "__main__":
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    saved = sys.argv[:]
    for fn in fns:
        fn(); sys.argv = saved[:]; print(f"PASS {fn.__name__}")
    print(f"{len(fns)}/{len(fns)} guard teeth green")
