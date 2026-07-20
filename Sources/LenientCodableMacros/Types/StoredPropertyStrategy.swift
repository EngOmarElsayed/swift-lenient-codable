//
//  StoredPropertyStrategy.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 18/07/2026.
//

import Foundation

/// The leniency strategy resolved for one stored property — *what the user
/// asked for*, before `validateShapes` checks whether the declared type can
/// deliver it.
///
/// `resolveStrategies` assigns one per property: a written annotation maps
/// through `MarkerAnnotation.strategy`, and an unannotated property gets
/// ``nilOnFailure(implicit:)`` with `implicit: true` — the
/// `@LenientDecodable` default. This is the intermediate step between
/// annotation and ``DecodingPlan``: a strategy says "nil on failure", and
/// only strategy × `TypeShape` decides whether that means whole-value
/// (`T?`), element padding (`[T?]`), or a diagnostic.
enum StoredPropertyStrategy {
    /// Nil where it broke. `implicit` records *provenance*: `false` for a
    /// written `@NilOnFailure`, `true` when applied by `@LenientDecodable`'s
    /// default. The flag never changes decoding behavior — it adjusts the
    /// human-facing output: diagnostic wording ("applied by
    /// @LenientDecodable"), the fix-it kind (*add* `@Strict` vs *replace*
    /// the annotation), and the provenance comment in generated code (see
    /// ``shouldAddProvenanceComment()``).
    case nilOnFailure(implicit: Bool)

    /// Failed elements are removed. Carries no `implicit` flag because
    /// dropping is never applied by defaulting — it must be written.
    case dropOnFailure

    /// Opt out of leniency: plain synthesized decoding, may throw. Also
    /// never a default — strictness is an explicit choice per property.
    case strict

    /// The comment `buildInitFromDecoder` places above an implicitly-lenient
    /// property's decoding line, so a reader of the expanded code can tell
    /// defaulted leniency from written `@NilOnFailure`:
    ///
    /// ```swift
    /// // implicit @NilOnFailure (applied by @LenientDecodable)
    /// self.status = LenientDecoding.nilOnFailure(...)
    /// ```
    ///
    /// - Returns: The comment line for `.nilOnFailure(implicit: true)`;
    ///   `nil` for every explicit strategy — code the user asked for by name
    ///   needs no provenance trail.
    func shouldAddProvenanceComment() -> String? {
        guard case .nilOnFailure(implicit: true) = self else { return nil }
        return "// implicit @NilOnFailure (applied by @LenientDecodable)"
    }
}
