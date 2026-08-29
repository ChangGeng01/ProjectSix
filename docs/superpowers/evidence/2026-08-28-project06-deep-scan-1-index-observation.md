# Project06 Deep Scan #1 read-only index observation

Date observed (UTC): `2026-08-28T01:55:35Z`

Purpose: freeze the exact read-only facts that remain available for the user's
first successful Deep Scan without representing this record as the missing
canonical manifest, findings document, coverage document, or report.

## Observed storage identity

- live database path:
  `/Users/changgeng/.codex/state/plugins/codex-security/workbench.sqlite3`
- read-only URI:
  `file:/Users/changgeng/.codex/state/plugins/codex-security/workbench.sqlite3?mode=ro&immutable=1`
- observed main-file length: `9371648` bytes
- observed main-file mtime epoch: `1787875692`
- observed main-file SHA-256:
  `df2adf848824647abd13e3aeb6dcb8424ac5b98e894fe3c0d9e20a54a8bc29e9`
- observed `PRAGMA user_version`: `0`
- same-directory glob at observation time contained the main database only;
  no `workbench.sqlite3-wal` or `workbench.sqlite3-shm` was present.

The database is live. Its whole-file hash is a point-in-time observation, not
a stable future locator. A later evidence export must use a read-only SQLite
snapshot/backup or deterministic query serialization; it must not copy only
the main file while a WAL may exist.

## Exact bounded queries

Only these tables/columns were needed for the core identity/count observation:

```sql
SELECT id,status,mode,target_revision,scan_dir,seal_manifest_digest,
       COALESCE(handoff_claim_token,''),
       COALESCE(handoff_claimed_at,''),
       COALESCE(continuation_thread_id,'')
FROM scans
WHERE id='bcffa52e-53cf-4407-b216-14288ae07061';

SELECT COUNT(*),COUNT(DISTINCT id),COUNT(DISTINCT finding_id)
FROM finding_occurrences
WHERE scan_id='bcffa52e-53cf-4407-b216-14288ae07061';

SELECT kind,path
FROM scan_artifacts
WHERE scan_id='bcffa52e-53cf-4407-b216-14288ae07061'
ORDER BY kind;

PRAGMA quick_check;
PRAGMA foreign_key_check;

SELECT SUM(id IS NULL),SUM(finding_id IS NULL),SUM(details_json IS NULL)
FROM finding_occurrences
WHERE scan_id='bcffa52e-53cf-4407-b216-14288ae07061';

SELECT severity,COUNT(*) AS n
FROM finding_occurrences
WHERE scan_id='bcffa52e-53cf-4407-b216-14288ae07061'
GROUP BY severity
ORDER BY CASE severity
  WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 ELSE 4 END;

SELECT COUNT(*) AS location_rows,
       COUNT(DISTINCT occurrence_id) AS occurrences_with_locations
FROM finding_locations
WHERE occurrence_id IN (
  SELECT id FROM finding_occurrences
  WHERE scan_id='bcffa52e-53cf-4407-b216-14288ae07061'
);

SELECT COUNT(*) AS malformed_details
FROM finding_occurrences
WHERE scan_id='bcffa52e-53cf-4407-b216-14288ae07061'
  AND json_valid(details_json)=0;

SELECT MIN(length(CAST(details_json AS BLOB))) AS min_detail_bytes,
       MAX(length(CAST(details_json AS BLOB))) AS max_detail_bytes,
       SUM(length(CAST(details_json AS BLOB))) AS total_detail_bytes
FROM finding_occurrences
WHERE scan_id='bcffa52e-53cf-4407-b216-14288ae07061';
```

No finding title, summary, remediation, or details body is copied into this
observation record.

## Exact results

The `scans` row was:

```text
bcffa52e-53cf-4407-b216-14288ae07061|complete|deep|c8f80486895e12e26d567e610c35a6e2141b3489|/private/var/folders/1x/snst3dq92x998rmwhc2tm09h0000gn/T/codex-security-scans-Hyaimj/qinao-dual-space-controlled-convergence/c8f80486895e12e26d567e610c35a6e2141b3489_20260820T210014Z_hfcu4c6p|sha256:fd5df1a1157bfceab6e3d38a73e771f50f5ddb4041780d50f95bacc2a80e79be|||
```

The occurrence counts were exactly:

```text
111|111|111
```

The four artifact rows were exactly:

```text
coverage|/private/var/folders/1x/snst3dq92x998rmwhc2tm09h0000gn/T/codex-security-scans-Hyaimj/qinao-dual-space-controlled-convergence/c8f80486895e12e26d567e610c35a6e2141b3489_20260820T210014Z_hfcu4c6p/coverage.json
findings|/private/var/folders/1x/snst3dq92x998rmwhc2tm09h0000gn/T/codex-security-scans-Hyaimj/qinao-dual-space-controlled-convergence/c8f80486895e12e26d567e610c35a6e2141b3489_20260820T210014Z_hfcu4c6p/findings.json
manifest|/private/var/folders/1x/snst3dq92x998rmwhc2tm09h0000gn/T/codex-security-scans-Hyaimj/qinao-dual-space-controlled-convergence/c8f80486895e12e26d567e610c35a6e2141b3489_20260820T210014Z_hfcu4c6p/scan-manifest.json
markdownReport|/private/var/folders/1x/snst3dq92x998rmwhc2tm09h0000gn/T/codex-security-scans-Hyaimj/qinao-dual-space-controlled-convergence/c8f80486895e12e26d567e610c35a6e2141b3489_20260820T210014Z_hfcu4c6p/report.md
```

All four paths point into the same missing temporary scan root. They are dead
locators preserved for audit, not claims that four readable artifacts remain.

Additional bounded checks at the same observed database identity found:

- `PRAGMA quick_check` returned exactly `ok`;
- `PRAGMA foreign_key_check` returned zero rows;
- zero occurrence rows had a null `id`, `finding_id`, or `details_json`;
- severity counts: `high=30`, `medium=65`, `low=16`;
- `2716` `finding_locations` rows covering all `111` occurrence IDs;
- `0` invalid `details_json` values; and
- `details_json` byte-length range `2351...703607`, total `6453105` bytes.

These checks establish that a separately labeled, non-canonical forensic
export is feasible from indexed occurrence data. They do not establish that
the sealed canonical documents or generated report are available.

## Interpretation boundary

- Deep Scan #1 remains the user's first successful Deep Scan and the indexed
  scan status remains `complete`.
- The seal-manifest digest remains recorded as
  `sha256:fd5df1a1157bfceab6e3d38a73e771f50f5ddb4041780d50f95bacc2a80e79be`.
- Claim token, claimed-at time, and continuation-thread ID are empty.
- The official completed-scan read currently returns:
  `Codex Security scan artifact root is not a safe regular directory.`
- A future 111-row forensic export must be explicitly non-canonical, preserve
  every occurrence identity, and bind a deterministic serialization/root.
- Only restoration by the official service can restore canonical-document
  availability; indexed rows or a local export cannot recreate that status.
