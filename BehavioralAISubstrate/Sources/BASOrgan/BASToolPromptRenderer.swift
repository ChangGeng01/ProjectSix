import Foundation

/// Single-source-of-truth renderer for the **`.runtimeSchema`** tool-bridging strategy
/// (`BASFoundationModelsToolBridge`): declare `BASTool`s IN THE PROMPT so a model that has no native
/// structured tool API (e.g. Apple FoundationModels in runtimeSchema mode) becomes aware of the tools and can
/// emit a parseable tool-call. The HOST (e.g. `BASToolCallingPlanner`'s policy) then parses that tool-call,
/// gates it (`BASToolInvocationGate`), dispatches it (`BASToolDispatcher`), and feeds the result back — so
/// tool execution stays CLIENT-EXECUTED and GATE-BEFORE-EXECUTE (红线 7 hint-only; the adapter NEVER runs a
/// tool). This renderer only makes the model AWARE; it executes nothing.
///
/// The emitted `tool_call` JSON shape is a stable contract. BOTH halves live here — `runtimeSchemaBlock`
/// (emit) and `parseToolCall` (parse) — so the declared shape and the consumed shape can never drift
/// (chapter 二百一一 single-source-of-truth). NOTE: shipping the matched pair does NOT auto-wire execution —
/// the host must opt `parseToolCall` into a `BASToolCallingPlanner` policy (the planner stays vendor-neutral
/// by design); and the end-to-end on-device round-trip (a real model emitting the contract) is not yet
/// exercised on hardware.
public enum BASToolPromptRenderer {

    /// The exact tool-call output contract the model is instructed to emit. A host parser keys on this shape.
    public static let toolCallInstruction = """
    To call a tool, reply with ONLY this JSON object on its own line (no prose around it):
    {"tool_call": {"name": "<tool_name>", "arguments": {"<param>": <value>, ...}}}
    If no tool is needed, answer normally.
    """

    /// Render the tool declarations + the call-format contract into a prompt block. Empty tools → `""`
    /// (caller appends nothing). Deterministic — stable order, no Date/UUID.
    public static func runtimeSchemaBlock(for tools: [BASTool]) -> String {
        guard !tools.isEmpty else { return "" }
        var lines: [String] = ["AVAILABLE TOOLS (declare-in-prompt; the host executes them):"]
        for tool in tools {
            lines.append("• \(tool.name): \(tool.description)")
            for p in tool.parameters {
                let requirement = p.required ? "required" : "optional"
                let allowed = p.allowedValues.isEmpty
                    ? ""
                    : " (one of: \(p.allowedValues.joined(separator: ", ")))"
                lines.append("    - \(p.name): \(p.type.rawValue) [\(requirement)]\(allowed) — \(p.description)")
            }
        }
        lines.append("")
        lines.append(toolCallInstruction)
        return lines.joined(separator: "\n")
    }

    // MARK: - The matched parser (closes the emit↔parse loop; single-source-of-truth)

    /// Parse a model reply that follows `toolCallInstruction` back into a `BASToolInvocation`. This is the
    /// matched consumer of the contract `runtimeSchemaBlock` declares — they live together so the emitted
    /// shape and the parsed shape can never drift. Pure + deterministic.
    ///
    /// Returns `nil` for a non-tool reply (plain prose), so a caller can treat "no tool call" as "use the body
    /// as the answer". The HOST still decides whether to USE this parser (the substrate's `BASToolCallingPlanner`
    /// stays vendor-neutral and takes a host policy closure); a host that adopts the runtimeSchema strategy
    /// wires this as its policy → the parsed invocation is then gated (`BASToolInvocationGate`) + dispatched
    /// (`BASToolDispatcher`). The adapter still executes NOTHING — gate-before-execute is preserved.
    ///
    /// Lenient: accepts the JSON object on its own line (the contract) OR embedded in surrounding prose.
    /// `arguments` values are returned as JSON fragments (the `BASToolInvocation` contract: JSON-encoded
    /// strings the caller decodes per each `BASToolParameter.type`).
    public static func parseToolCall(_ body: String) -> BASToolInvocation? {
        guard let object = extractToolCallObject(from: body),
              let call = object["tool_call"] as? [String: Any],
              let name = (call["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else { return nil }
        let rawArgs = (call["arguments"] as? [String: Any]) ?? [:]
        var arguments: [String: String] = [:]
        for (key, value) in rawArgs { arguments[key] = jsonFragment(value) }
        return BASToolInvocation(
            invocationID: "rsc-\(name)-\(stableHashHex(arguments))",
            toolName: name,
            arguments: arguments)
    }

    /// Find the first `{...}` that parses to an object containing a `tool_call` key — try the whole body
    /// (the ideal "on its own line" contract case), then each line (lenient if the model wrapped it in prose).
    private static func extractToolCallObject(from body: String) -> [String: Any]? {
        let candidates = [body] + body.split(separator: "\n").map(String.init)
        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = trimmed.data(using: .utf8),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  object["tool_call"] != nil
            else { continue }
            return object
        }
        return nil
    }

    /// Serialize one parsed JSON value back to its JSON text (`"s"` / `42` / `true` / `[…]`), preserving the
    /// type JSONSerialization inferred (avoids the Bool-vs-Number ambiguity by never re-inferring).
    private static func jsonFragment(_ value: Any) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return String(describing: value)
    }

    /// Deterministic, dependency-free FNV-1a hex over the canonical sorted args — a stable invocation id
    /// (correlates with the result) that the round-trip test can assert. No Date/UUID.
    private static func stableHashHex(_ arguments: [String: String]) -> String {
        let canonical = arguments.keys.sorted()
            .map { "\($0)=\(arguments[$0] ?? "")" }
            .joined(separator: "&")
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in canonical.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
