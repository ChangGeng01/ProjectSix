import SwiftParser
import SwiftSyntax

struct BASEventLogHeadSyntaxFacts {
    struct Alias {
        let name: String
        let referencedTypeNames: Set<String>
    }

    let declarationKinds: [String]
    let aliases: [Alias]
    let extendedTypeNames: [String]
    let identifierNames: Set<String>
}

enum BASEventLogHeadSyntaxAudit {
    static let targetName = "BASEventLogHead"

    static func parse(_ source: String) -> BASEventLogHeadSyntaxFacts {
        let tree = Parser.parse(source: source)
        let visitor = Visitor(viewMode: .sourceAccurate)
        visitor.walk(tree)

        return BASEventLogHeadSyntaxFacts(
            declarationKinds: visitor.declarationKinds,
            aliases: visitor.aliases,
            extendedTypeNames: visitor.extendedTypeNames,
            identifierNames: Set(
                tree.tokens(viewMode: .sourceAccurate)
                    .compactMap { Identifier($0)?.name }))
    }

    /// Deliberately treats every typealias whose RHS mentions the head (or
    /// another such alias) as forbidden alias surface. Ordinary fields and
    /// parameters remain legal; only aliases and alias wrappers are closed.
    static func namesMentioningHeadThroughAliases(
        in facts: [BASEventLogHeadSyntaxFacts]
    ) -> Set<String> {
        var names: Set<String> = [targetName]
        var changed = true
        while changed {
            changed = false
            for alias in facts.flatMap(\.aliases)
            where !names.isDisjoint(with: alias.referencedTypeNames) {
                changed = names.insert(alias.name).inserted || changed
            }
        }
        return names
    }

    static func extensionCount(
        in facts: [BASEventLogHeadSyntaxFacts]
    ) -> Int {
        let names = namesMentioningHeadThroughAliases(in: facts)
        return facts
            .flatMap(\.extendedTypeNames)
            .filter(names.contains)
            .count
    }

    private final class Visitor: SyntaxVisitor {
        var declarationKinds: [String] = []
        var aliases: [BASEventLogHeadSyntaxFacts.Alias] = []
        var extendedTypeNames: [String] = []

        override func visit(
            _ node: StructDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            recordDeclaration(name: node.name, kind: "struct")
            return .visitChildren
        }

        override func visit(
            _ node: EnumDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            recordDeclaration(name: node.name, kind: "enum")
            return .visitChildren
        }

        override func visit(
            _ node: ClassDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            recordDeclaration(name: node.name, kind: "class")
            return .visitChildren
        }

        override func visit(
            _ node: ActorDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            recordDeclaration(name: node.name, kind: "actor")
            return .visitChildren
        }

        override func visit(
            _ node: ProtocolDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            recordDeclaration(name: node.name, kind: "protocol")
            return .visitChildren
        }

        override func visit(
            _ node: TypeAliasDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            guard let aliasName = Identifier(node.name)?.name else {
                return .visitChildren
            }
            recordDeclaration(name: node.name, kind: "typealias")
            let referencedTypeNames = Set(
                node.initializer.value
                    .tokens(viewMode: .sourceAccurate)
                    .compactMap { Identifier($0)?.name })
            if !referencedTypeNames.isEmpty {
                aliases.append(.init(
                    name: aliasName,
                    referencedTypeNames: referencedTypeNames))
            }
            return .visitChildren
        }

        override func visit(
            _ node: ExtensionDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            if let name = unqualifiedTypeName(node.extendedType) {
                extendedTypeNames.append(name)
            }
            return .visitChildren
        }

        private func recordDeclaration(
            name: TokenSyntax,
            kind: String
        ) {
            if Identifier(name)?.name ==
                BASEventLogHeadSyntaxAudit.targetName {
                declarationKinds.append(kind)
            }
        }

        private func unqualifiedTypeName(_ type: TypeSyntax) -> String? {
            if let identifier = type.as(IdentifierTypeSyntax.self) {
                return Identifier(identifier.name)?.name
            }
            if let member = type.as(MemberTypeSyntax.self) {
                return Identifier(member.name)?.name
            }
            if let attributed = type.as(AttributedTypeSyntax.self) {
                return unqualifiedTypeName(attributed.baseType)
            }
            if let tuple = type.as(TupleTypeSyntax.self),
               tuple.elements.count == 1,
               let element = tuple.elements.first,
               element.inoutKeyword == nil,
               element.firstName == nil,
               element.secondName == nil,
               element.colon == nil,
               element.ellipsis == nil {
                return unqualifiedTypeName(element.type)
            }
            return nil
        }
    }
}
