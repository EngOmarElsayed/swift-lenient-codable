//
//  DecodingPlan.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 18/07/2026.
//

import SwiftSyntax
import Foundation

/// The final, validated decoding decision for one stored property — each case
/// renders as exactly one line of the generated `init(from:)`.
///
/// A plan is the *output* of `LenientDecodableMacro.validateShapes`: the
/// point where a property's strategy (`StoredPropertyStrategy`, from its
/// annotation or the implicit default) is crossed with its declared shape
/// (`TypeShape`, parsed from the type annotation). Only the valid cells of
/// that matrix construct a plan — every invalid combination emits a
/// `LenientDiagnostic` and leaves `StoredProperty.plan` as `nil` instead:
///
/// | | `T` | `T?` | `[T]` | `[T?]` | `[T]?` | `[T?]?` |
/// |---|---|---|---|---|---|---|
/// | `.strict` | ``strictRequired(type:)`` | ``strictOptional(wrapped:)`` | ``strictRequired(type:)`` | ``strictRequired(type:)`` | ``strictOptional(wrapped:)`` | ``strictOptional(wrapped:)`` |
/// | `.nilOnFailure` | ❌ | ``nilOnFailureValue(wrapped:)`` | ❌ | ``nilPadding(element:)`` | ❌ | ``nilPaddingOptionalArray(element:)`` |
/// | `.dropOnFailure` | ❌ | ❌ | ``dropOnFailure(element:)`` | ❌ | ❌ | ❌ |
///
/// Holding a `DecodingPlan` is therefore a proof of validity: by the time
/// `buildInitFromDecoder` calls ``decodingLine(name:)``, there is nothing
/// left to check.
///
/// Each case stores the one type the generated line needs to spell — the
/// whole type for a strict `decode`, the *wrapped* type for
/// `decodeIfPresent` (which re-adds the optionality itself), or the bare
/// *element* type for the array helpers (which build the array shape at
/// runtime).
enum DecodingPlan {
    /// `self.x = try container.decode(T.self, forKey: .x)`
    ///
    /// `@Strict` on a non-optional property — byte-for-byte synthesized
    /// behavior, and one of the only lines in a generated initializer that
    /// can throw.
    case strictRequired(type: TypeSyntax)

    /// `self.x = try container.decodeIfPresent(W.self, forKey: .x)`
    ///
    /// `@Strict` on an optional property (`W?`, `[E]?`, `[E?]?` — the stored
    /// type is the wrapped part). Absence decodes as `nil`, but a
    /// present-and-broken value throws.
    case strictOptional(wrapped: TypeSyntax)

    /// `self.x = LenientDecoding.nilOnFailure(W.self, in:forKey:decoder:)`
    ///
    /// `@NilOnFailure` on `W?` — whole-value leniency, any failure decodes
    /// as `nil`.
    case nilOnFailureValue(wrapped: TypeSyntax)

    /// `self.x = LenientDecoding.nilPadding(E.self, ...)` → `[E?]`
    ///
    /// `@NilOnFailure` on `[E?]` — element padding, failed elements become
    /// `nil` in place.
    case nilPadding(element: TypeSyntax)

    /// `self.x = LenientDecoding.nilPaddingOptional(E.self, ...)` → `[E?]?`
    ///
    /// `@NilOnFailure` on `[E?]?` — as ``nilPadding(element:)``, but an
    /// absent or unusable array decodes as `nil` instead of `[]`.
    case nilPaddingOptionalArray(element: TypeSyntax)

    /// `self.x = LenientDecoding.dropOnFailure(E.self, ...)` → `[E]`
    ///
    /// `@DropOnFailure` on `[E]` — failed elements are removed, survivors
    /// keep their order.
    case dropOnFailure(element: TypeSyntax)

}

// MARK: - DecodingPlan decodingLine
extension DecodingPlan {
    /// Renders this plan as the property's line in the generated
    /// `init(from:)`.
    ///
    /// The stored type is emitted `.trimmed` so surrounding trivia from the
    /// source declaration can't leak into the generated code. The four
    /// lenient cases call into the `LenientDecoding` runtime module (which
    /// `LenientCodable` re-exports, so the name resolves wherever the macro
    /// is used); the two strict cases are plain Codable calls — the `try` on
    /// them is what makes `@Strict` properties the only possible failure
    /// points of the decode.
    ///
    /// - Parameter name: The property name, used both for the assignment
    ///   target and the `CodingKeys` case.
    /// - Returns: One `self.<name> = ...` line, unindented; the caller
    ///   handles placement inside the initializer body.
    func decodingLine(name: String) -> String {
        switch self {
        case .strictRequired(let type):
            return "self.\(name) = try container.decode(\(type.trimmed).self, forKey: .\(name))"

        case .strictOptional(let wrapped):
            return "self.\(name) = try container.decodeIfPresent(\(wrapped.trimmed).self, forKey: .\(name))"

        case .nilOnFailureValue(let wrapped):
            return "self.\(name) = LenientDecoding.nilOnFailure(\(wrapped.trimmed).self, in: container, forKey: .\(name), decoder: decoder)"

        case .nilPadding(let element):
            return "self.\(name) = LenientDecoding.nilPadding(\(element.trimmed).self, in: container, forKey: .\(name), decoder: decoder)"

        case .nilPaddingOptionalArray(let element):
            return "self.\(name) = LenientDecoding.nilPaddingOptional(\(element.trimmed).self, in: container, forKey: .\(name), decoder: decoder)"

        case .dropOnFailure(let element):
            return "self.\(name) = LenientDecoding.dropOnFailure(\(element.trimmed).self, in: container, forKey: .\(name), decoder: decoder)"
        }
    }
}
