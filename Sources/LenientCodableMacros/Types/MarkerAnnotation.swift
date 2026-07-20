//
//  MarkerAnnotation.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 18/07/2026.
//

import Foundation

/// The recognition table for the three property annotations
/// `@LenientDecodable` understands: `@NilOnFailure`, `@DropOnFailure`, and
/// `@Strict`.
///
/// The annotations themselves are inert peer macros (`MarkerMacro` expands
/// to nothing) — their entire meaning is produced *here*, when the
/// type-level macro walks each property's attribute list. The raw value is
/// the attribute's base name exactly as written in source, so recognition is
/// one failable init:
///
/// ```swift
/// MarkerAnnotation(rawValue: attribute.getBaseName())  // nil → not ours
/// ```
///
/// which is how `AttributeListSyntax.getLenientMarkerAnnotations()` separates
/// leniency markers from unrelated attributes (`@available`, property
/// wrappers, …) without any list of names to keep in sync — adding a case
/// here *is* teaching the macro a new annotation.
enum MarkerAnnotation: String, CaseIterable {
    /// `@NilOnFailure` — nil where it broke; requires a nil-shaped hole
    /// (`T?`, `[T?]`, `[T?]?`). Also the behavior applied implicitly to
    /// unannotated properties, but through `resolveStrategies`' default, not
    /// through this case — see ``strategy``.
    case nilOnFailure = "NilOnFailure"

    /// `@DropOnFailure` — failed elements are removed; requires a plain
    /// `[T]`. Never applied by defaulting: element dropping erases evidence,
    /// so it must always be written explicitly.
    case dropOnFailure = "DropOnFailure"

    /// `@Strict` — opt out of leniency; byte-for-byte synthesized decoding
    /// on any type, and the only way a decode of the struct can fail.
    case strict = "Strict"

    /// The decoding strategy this annotation selects for its property.
    ///
    /// A `MarkerAnnotation` only exists when the user *wrote* the attribute,
    /// so ``nilOnFailure`` maps to `.nilOnFailure(implicit: false)` — the
    /// `implicit: true` variant is minted directly by `resolveStrategies` for
    /// unannotated properties, and the flag downstream softens diagnostic
    /// wording ("applied by @LenientDecodable") and switches the fix-it from
    /// *replace annotation* to *add annotation*.
    var strategy: StoredPropertyStrategy {
        switch self {
        case .nilOnFailure:
                return .nilOnFailure(implicit: false)
        case .dropOnFailure:
            return .dropOnFailure
        case .strict:
            return .strict
        }
    }
}
