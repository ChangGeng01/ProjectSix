# Retained StateLake reader — bounded input repair

The experimental `statelake-device/1` reader now checks file, metadata and
allocation boundaries before constructing tensors. The existing public load
signature, binding/checksum/missing-state error categories, requested ordering
and valid int8/fp16 format are retained. No model or user artifact was loaded.

Reader-owned limits are 1MiB header, 64MiB payload, 128MiB aggregate decoded
Float16 storage, 1024 tensor records and rank1...16. Oversized inputs fail, rather
than truncate. Descriptor-based reads require regular files and bounded chunks;
FIFO input is refused without waiting for a writer. The limits are not a bound
on whole-process memory use or a cross-file transactional writer protocol.

All records, including unrequested ones, undergo checked integer/shape/range/
byte-count/allocation validation. Unsupported formats/types, duplicate names,
nonfinite values and unrepresentable scales fail. Little-endian fp16 decoding
does not assume aligned offsets. Repeated requested names reuse decoded tensors.
The existing Float32 int8 multiplication order is retained before Float16
rounding, including a regression for a one-bit compatibility difference.

Local verification on final proposed source:

- Genuine pre-fix unsupported-dtype RED: one expected failure.
- Genuine rounding-preservation RED, followed by its passing control.
- Final reader/decoder focus:15tests, zero failures/skips.
- Final reader plus checked bridge:26tests, zero failures/skips, natural exit0.
  Includes tiny real CoreAI NDArrays on macOS27. No inference, model preparation,
  app/device probe or cloud/PCC invocation occurred.

Independent spec/quality review approved the candidate with no Critical or
Important findings. One non-blocking verification note retains the existing
native-build-system deprecation; it is not a new source defect. Raw command logs and exact source
identities are preserved in the solo-readiness recovery workspace. The only
final covering-run warning was the existing native-build-system deprecation.
No iOS/device runtime or real artifact migration is established. Payload SHA-256
is a corruption check against the captured header, not an authenticity signature.
This does not establish an attacker-controlled supported import path, close all
StateLake findings, validate hosted CI, approve merge or mark DS3 ready.
