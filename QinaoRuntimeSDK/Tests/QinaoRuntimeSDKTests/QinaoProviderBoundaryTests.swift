import BASHostKit
import BASOrgan
import Foundation
import QinaoLoop
import XCTest

/// Silicon W0 freeze: Qinao is the model-neutral SDK. Concrete model runtimes
/// must live in Provider packages or host composition, never under this package.
final class QinaoProviderBoundaryTests: XCTestCase {
    private struct SwiftSourceScan {
        let activeSource: String
        let encounteredRawRegexLiteral: Bool
    }

    private enum SwiftSourceMode {
        case code
        case interpolation(parenthesesDepth: Int)
        case lineComment
        case blockComment(depth: Int)
        case string(hashCount: Int, quoteCount: Int)
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private struct DumpedPackage: Decodable {
        struct Product: Decodable {
            let name: String
        }

        let products: [Product]
    }

    /// Removes comments with a bounded linear scan while respecting ordinary,
    /// multiline, and raw Swift string delimiters plus nested block comments.
    /// Source scans mask string contents; Package.swift scans retain them so
    /// product-name literals remain visible.
    private static func activeSwiftSource(_ source: String) -> SwiftSourceScan {
        let bytes = Array(source.utf8)
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var mode = SwiftSourceMode.code
        var resumeModes: [SwiftSourceMode] = []
        var encounteredRawRegexLiteral = false
        var index = 0

        func hasBytes(_ expected: [UInt8], at start: Int) -> Bool {
            guard start >= 0, start + expected.count <= bytes.count else {
                return false
            }
            for (offset, byte) in expected.enumerated()
            where bytes[start + offset] != byte {
                return false
            }
            return true
        }

        func isEscaped(at quoteIndex: Int) -> Bool {
            var cursor = quoteIndex
            var slashCount = 0
            while cursor > 0, bytes[cursor - 1] == 0x5C {
                slashCount += 1
                cursor -= 1
            }
            return slashCount % 2 == 1
        }

        func appendMasked(_ byte: UInt8) {
            output.append(byte == 0x0A || byte == 0x0D ? byte : 0x20)
        }

        func appendStringByte(_ byte: UInt8) {
            appendMasked(byte)
        }

        func enter(_ next: SwiftSourceMode) {
            resumeModes.append(mode)
            mode = next
        }

        func resume() {
            precondition(!resumeModes.isEmpty, "unbalanced Swift lexical mode")
            mode = resumeModes.removeLast()
        }

        while index < bytes.count {
            switch mode {
            case .code, .interpolation:
                if bytes[index] == 0x23 {
                    var regexCursor = index
                    while regexCursor < bytes.count,
                          bytes[regexCursor] == 0x23
                    {
                        regexCursor += 1
                    }
                    if regexCursor > index,
                       regexCursor < bytes.count,
                       bytes[regexCursor] == 0x2F
                    {
                        // Swift raw-regex grammar is deliberately not reimplemented
                        // here. Mark the file unsupported so the boundary gate fails
                        // closed instead of mistaking `//` or `/*` inside `#/…/#`
                        // for comments and hiding later active code.
                        encounteredRawRegexLiteral = true
                    }
                }
                if hasBytes([0x2F, 0x2F], at: index) {
                    output.append(contentsOf: [0x20, 0x20])
                    index += 2
                    enter(.lineComment)
                    continue
                }
                if hasBytes([0x2F, 0x2A], at: index) {
                    output.append(contentsOf: [0x20, 0x20])
                    index += 2
                    enter(.blockComment(depth: 1))
                    continue
                }

                var delimiterCursor = index
                var hashCount = 0
                while delimiterCursor < bytes.count,
                      bytes[delimiterCursor] == 0x23
                {
                    hashCount += 1
                    delimiterCursor += 1
                }
                if delimiterCursor < bytes.count,
                   bytes[delimiterCursor] == 0x22
                {
                    let quoteCount = hasBytes(
                        [0x22, 0x22, 0x22], at: delimiterCursor) ? 3 : 1
                    let delimiterEnd = delimiterCursor + quoteCount
                    for byte in bytes[index..<delimiterEnd] {
                        appendMasked(byte)
                    }
                    index = delimiterEnd
                    enter(.string(
                        hashCount: hashCount,
                        quoteCount: quoteCount))
                    continue
                }

                if case .interpolation(let parenthesesDepth) = mode {
                    if bytes[index] == 0x28 {
                        output.append(bytes[index])
                        index += 1
                        mode = .interpolation(
                            parenthesesDepth: parenthesesDepth + 1)
                        continue
                    }
                    if bytes[index] == 0x29 {
                        appendMasked(bytes[index])
                        index += 1
                        if parenthesesDepth == 1 {
                            resume()
                        } else {
                            mode = .interpolation(
                                parenthesesDepth: parenthesesDepth - 1)
                        }
                        continue
                    }
                }

                output.append(bytes[index])
                index += 1

            case .lineComment:
                let byte = bytes[index]
                appendMasked(byte)
                index += 1
                if byte == 0x0A || byte == 0x0D {
                    resume()
                }

            case .blockComment(let depth):
                if hasBytes([0x2F, 0x2A], at: index) {
                    output.append(contentsOf: [0x20, 0x20])
                    index += 2
                    mode = .blockComment(depth: depth + 1)
                    continue
                }
                if hasBytes([0x2A, 0x2F], at: index) {
                    output.append(contentsOf: [0x20, 0x20])
                    index += 2
                    if depth == 1 {
                        resume()
                    } else {
                        mode = .blockComment(depth: depth - 1)
                    }
                    continue
                }
                appendMasked(bytes[index])
                index += 1

            case .string(let hashCount, let quoteCount):
                let interpolation = [UInt8(0x5C)]
                    + Array(repeating: UInt8(0x23), count: hashCount)
                    + [UInt8(0x28)]
                let startsInterpolation = hasBytes(interpolation, at: index)
                    && (hashCount > 0 || !isEscaped(at: index))
                if startsInterpolation {
                    for byte in bytes[index..<(index + interpolation.count)] {
                        appendStringByte(byte)
                    }
                    index += interpolation.count
                    enter(.interpolation(parenthesesDepth: 1))
                    continue
                }

                let quotes = Array(repeating: UInt8(0x22), count: quoteCount)
                let hashes = Array(repeating: UInt8(0x23), count: hashCount)
                let isClosingDelimiter = hasBytes(quotes, at: index)
                    && hasBytes(hashes, at: index + quoteCount)
                    && (hashCount > 0 || !isEscaped(at: index))
                if isClosingDelimiter {
                    let delimiterEnd = index + quoteCount + hashCount
                    for byte in bytes[index..<delimiterEnd] {
                        appendMasked(byte)
                    }
                    index = delimiterEnd
                    resume()
                    continue
                }
                appendStringByte(bytes[index])
                index += 1
            }
        }

        return SwiftSourceScan(
            activeSource: String(decoding: output, as: UTF8.self),
            encounteredRawRegexLiteral: encounteredRawRegexLiteral)
    }

    private static func swiftFiles(under root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey])
        else { return [] }
        return enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
    }

    private static func evaluatedProductNames(at packageRoot: URL) throws
        -> Set<String>
    {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-dump-package-\(UUID().uuidString)",
                isDirectory: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "swift", "package", "--package-path", packageRoot.path,
            "--scratch-path", scratch.path,
            "dump-package",
        ]
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let error = standardError.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(decoding: error, as: UTF8.self)
            throw NSError(
                domain: "QinaoProviderBoundaryTests.dump-package",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: detail])
        }

        let package = try JSONDecoder().decode(DumpedPackage.self, from: output)
        return Set(package.products.map(\.name))
    }

    private static func swiftIdentifiers(in activeSource: String) -> [String] {
        func isIdentifierByte(_ byte: UInt8) -> Bool {
            (byte >= 0x41 && byte <= 0x5A)
                || (byte >= 0x61 && byte <= 0x7A)
                || (byte >= 0x30 && byte <= 0x39)
                || byte == 0x5F
                // Treat non-ASCII scalars conservatively as identifier material,
                // so an exact forbidden ASCII name cannot match inside a larger
                // Unicode identifier.
                || byte >= 0x80
        }

        var identifiers: [String] = []
        var current: [UInt8] = []
        func flush() {
            guard !current.isEmpty else { return }
            identifiers.append(String(decoding: current, as: UTF8.self))
            current.removeAll(keepingCapacity: true)
        }

        for byte in activeSource.utf8 {
            if isIdentifierByte(byte) {
                current.append(byte)
            } else {
                flush()
            }
        }
        flush()
        return identifiers
    }

    private static func importedModules(in identifiers: [String]) -> Set<String> {
        let scopedImportKinds: Set<String> = [
            "typealias", "struct", "class", "enum", "protocol",
            "let", "var", "func",
        ]
        var modules: Set<String> = []
        for index in identifiers.indices where identifiers[index] == "import" {
            var moduleIndex = identifiers.index(after: index)
            guard moduleIndex < identifiers.endIndex else { continue }
            if scopedImportKinds.contains(identifiers[moduleIndex]) {
                moduleIndex = identifiers.index(after: moduleIndex)
            }
            guard moduleIndex < identifiers.endIndex else { continue }
            modules.insert(identifiers[moduleIndex])
        }
        return modules
    }

    func testQinaoSDKContainsNoConcreteProviderRuntime() throws {
        let productNames = try Self.evaluatedProductNames(at: packageRoot)
        var violations: [String] = []
        for product in ["QinaoAppleFoundation", "QinaoMLX"]
        where productNames.contains(product) {
            violations.append("Package.swift:declares-\(product)")
        }

        let sourcesRoot = packageRoot.appendingPathComponent("Sources")
        let files = Self.swiftFiles(under: sourcesRoot)
        XCTAssertGreaterThan(files.count, 20, "sanity: Qinao Sources must be present")
        let forbiddenImports: [(module: String, label: String)] = [
            ("BASMLXAdapter", "import BASMLXAdapter"),
            ("BASAppleAdapters", "import BASAppleAdapters"),
            ("CoreAI", "import CoreAI"),
        ]
        let forbiddenIdentifiers: [(identifier: String, label: String)] = [
            ("MLXOrganAdapter", "MLXOrganAdapter("),
            ("AppleFoundationOrganAdapter", "AppleFoundationOrganAdapter("),
            ("QinaoMLXModel", "QinaoMLXModel"),
        ]
        for file in files {
            let relative = file.path.replacingOccurrences(
                of: packageRoot.path + "/",
                with: "")
            let scan = Self.activeSwiftSource(
                try String(contentsOf: file, encoding: .utf8))
            if scan.encounteredRawRegexLiteral {
                violations.append("\(relative):unsupported-raw-regex-literal")
            }

            let identifiers = Self.swiftIdentifiers(in: scan.activeSource)
            let identifierSet = Set(identifiers)
            let importedModules = Self.importedModules(in: identifiers)
            for forbidden in forbiddenImports
            where importedModules.contains(forbidden.module) {
                violations.append("\(relative):\(forbidden.label)")
            }
            for forbidden in forbiddenIdentifiers
            where identifierSet.contains(forbidden.identifier) {
                violations.append("\(relative):\(forbidden.label)")
            }
            if identifierSet.contains(where: {
                $0.hasPrefix("CoreAI") && $0.hasSuffix("Runner")
            }) {
                violations.append("\(relative):CoreAIRunner(")
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "SILICON-W0-VIOLATIONS \(violations.sorted())")
    }

    func testStreamingAndEagerViewsShareOneOperationAndProviderInvocation()
        async throws
    {
        let rawProvider = BASOrganDeterministicAdapter(
            providerID: "silicon.w0.provider",
            clock: { Date(timeIntervalSince1970: 1_700_000_000) })
        let counter = BASLLMCallCounter()
        let countedProvider = BASCountingOrganAdapter(
            wrapping: rawProvider,
            counter: counter)
        let endpoint = BASOrganRegistryEndpoint(
            adapterOverride: { _ in countedProvider },
            nextRequestID: { "silicon.w0.request" })
        let loop = QinaoLoop(organEndpoint: endpoint)

        let sessionID = "silicon.w0.turn"
        let prompt = "Produce one stable final answer."
        await counter.mark()

        var lastStreamChunk: QinaoLoop.OrganResponseChunk?
        let stream = loop.streamBody(
            sessionID: sessionID,
            prompt: prompt,
            role: .core)
        for try await chunk in stream {
            lastStreamChunk = chunk
        }
        let streamFinal = try XCTUnwrap(lastStreamChunk)

        let seed = QinaoLoop.CandidateSeed(
            candidateID: "terminal",
            title: "terminal",
            prompt: prompt,
            role: .core,
            expectedBenefit: 0.7,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.8)
        let candidates = try await loop.generateCandidates(
            sessionID: sessionID,
            seeds: [seed])
        let eagerFinal = try XCTUnwrap(candidates.first)

        let decoratedInvocationCount = await counter.delta()
        let physicalInvocationCount = await rawProvider.calls()
        var violations: [String] = []
        if decoratedInvocationCount != 1 || physicalInvocationCount != 1 {
            violations.append("execution.plan-provider-router.missing-exactly-once-call")
            violations.append("release.spool-publication.stream-then-regenerate")
            violations.append("runtime.turn-operation.multiple-provider-invocations")
        }
        if streamFinal.cumulativeBody != eagerFinal.body {
            violations.append("release.spool-publication.stream-eager-final-mismatch")
        }

        XCTAssertTrue(
            violations.isEmpty,
            "SILICON-W0-VIOLATIONS \(violations.sorted())")
    }

    func testBoundaryScannerHasTeethAndUnderstandsSwiftLexing() {
        let planted = ###"""
        let url = "https://example.invalid/path"
        let literal = "MLXOrganAdapter("
        let raw = #"// import BASMLXAdapter"#
        let nearMiss = MyQinaoMLXModel
        let multiline = """
        import CoreAI
        """
        let interpolated = "\(CoreAIRunner
            ())"
        let rawInterpolated = ##"\##(AppleFoundationOrganAdapter /* seam */ ())"##
        /* outer /* QinaoMLXModel */ AppleFoundationOrganAdapter( */
        import struct /* seam */ BASAppleAdapters.Endpoint
        """###
        let scan = Self.activeSwiftSource(planted)
        let active = scan.activeSource
        let identifiers = Self.swiftIdentifiers(in: active)
        let identifierSet = Set(identifiers)
        let importedModules = Self.importedModules(in: identifiers)
        let rawRegexScan = Self.activeSwiftSource(
            ###"#/https://example.invalid/#; MLXOrganAdapter()"###)

        XCTAssertFalse(scan.encounteredRawRegexLiteral)
        XCTAssertTrue(rawRegexScan.encounteredRawRegexLiteral)
        XCTAssertFalse(active.contains("https://example.invalid"))
        XCTAssertFalse(identifierSet.contains("MLXOrganAdapter"))
        XCTAssertFalse(importedModules.contains("BASMLXAdapter"))
        XCTAssertFalse(identifierSet.contains("QinaoMLXModel"))
        XCTAssertTrue(identifierSet.contains("MyQinaoMLXModel"))
        XCTAssertTrue(identifierSet.contains("CoreAIRunner"))
        XCTAssertTrue(identifierSet.contains("AppleFoundationOrganAdapter"))
        XCTAssertTrue(importedModules.contains("BASAppleAdapters"))
        XCTAssertFalse(importedModules.contains("CoreAI"))
    }
}
