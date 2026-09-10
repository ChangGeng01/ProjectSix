// ch1050 / v1.0 §11 — Qinao Transcript: SDK surface for the L12 transcript objects (§8.2).
//
// Thin re-export of the BAS transcript value types under the `Qinao*` name (same convention as
// QinaoMemory/QinaoRisk; the substrate types stay the source of record, no mirror-drift). Modes:
// off / summary / compare / structuredTrace / agentTrace / auditLite — process structure, never raw
// hidden reasoning (红线).

import BASOrgan

public typealias QinaoTranscriptMode = BASTranscriptMode
public typealias QinaoTranscriptView = BASTranscriptView
public typealias QinaoProcessTrace = BASProcessTrace
public typealias QinaoProcessTraceVerdict = BASProcessTraceVerdict
