import Foundation

/// Single-source-of-truth renderer for the **`.runtimeSchema`** tool-bridging strategy
/// (`BASFoundationModelsToolBridge`): declare `BASTool`s IN THE PROMPT so a model that has no native
/// structured tool API (e.g. Apple FoundationModels in runtimeSchema mode) becomes aware of the tools and can
/// emit a parseable tool-call. The HOST (e.g. `BASToolCallingPlanner`'s policy) then parses that tool-call,
/// gates it (`BASToolInvocationGate`), dispatches it (`BASToolDispatcher`), and feeds the result back — so
/// tool execution stays CLIENT-EXECUTED and GATE-BEFORE-EXECUTE (红线 7 hint-only; the adapter NEVER runs a
/// tool). This renderer only makes the model AWARE; it executes nothing.
///
/// The emitted `tool_call` JSON shape is the stable contract a host parser targets — pinned here so the
/// renderer and any host-side parser share one definition (chapter 二百一一 single-source-of-truth).
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
}
