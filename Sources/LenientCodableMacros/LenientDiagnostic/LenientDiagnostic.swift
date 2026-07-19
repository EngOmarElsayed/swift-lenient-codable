//
//  LenientDiagnostic.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 19/07/2026.
//

import SwiftSyntax
import SwiftDiagnostics

enum LenientDiagnostic: DiagnosticMessage {
    // Type-level
    case structsOnly
    case duplicateAttribute
    case handWrittenInitFromDecoder
    case redundantConformance

    // Property-level
    case multipleAnnotations(annotations: [String])
    case requiresOptional(implicit: Bool)
    case arrayRequiresOptionalElements(implicit: Bool)
    case dropRequiresArray
    case dropRequiresNonOptionalArray
    case dropRequiresNonOptionalElements
    case sugarSyntaxRequired
    case missingTypeAnnotation

    var message: String {
        switch self {
        case .structsOnly:
            return "'@LenientDecodable' can only be applied to a struct"

        case .duplicateAttribute:
            return "'@LenientDecodable' is already applied to this type"

        case .handWrittenInitFromDecoder:
            return "'@LenientDecodable' cannot be applied to a type that declares its own 'init(from:)'"

        case .redundantConformance:
            return "'@LenientDecodable' already adds the 'Decodable' conformance; the explicit conformance is redundant"

        case .multipleAnnotations(let annotations):
            let list = annotations.map { "'@\($0)'" }.joined(separator: ", ")
            return "property has multiple leniency annotations (\(list)); choose one"

        case .requiresOptional(let implicit):
            return "'@NilOnFailure'\(implicit ? " (applied by @LenientDecodable)" : "") requires an optional type"

        case .arrayRequiresOptionalElements(let implicit):
            return "'@NilOnFailure'\(implicit ? " (applied by @LenientDecodable)" : "") on an array requires optional elements — elements that fail to decode become 'nil' in place"

        case .dropRequiresArray:
            return "'@DropOnFailure' can only be applied to an array property"

        case .dropRequiresNonOptionalArray:
            return "'@DropOnFailure' requires a non-optional array — a missing or null key already decodes as '[]'"

        case .dropRequiresNonOptionalElements:
            return "'@DropOnFailure' requires non-optional elements — use '@NilOnFailure' to keep null placeholders"

        case .sugarSyntaxRequired:
            return "LenientCodable requires sugar syntax ('T?', '[T]') to determine leniency shape"

        case .missingTypeAnnotation:
            return "'@LenientDecodable' requires an explicit type annotation on stored properties"
        }
    }

    var diagnosticID: MessageID {
        let id: String = String(describing: self)
        return MessageID(domain: "LenientCodable", id: id)
    }

    var severity: DiagnosticSeverity {
        switch self {
        case .redundantConformance:
            return .warning
        default:
            return .error
        }
    }
}
