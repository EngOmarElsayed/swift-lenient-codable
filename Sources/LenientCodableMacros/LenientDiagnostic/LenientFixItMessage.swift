//
//  LenientFixItMessage.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 19/07/2026.
//

import SwiftDiagnostics

/// The button labels for every fix-it built by `LenientFixItHelperMethods` —
/// the text Xcode shows next to "Fix" in the diagnostic popup.
///
/// One case per rewrite the factories can produce. Where `LenientDiagnostic`
/// explains *what's wrong*, these messages promise *what clicking will do* —
/// so each is a short imperative phrase describing the exact edit, with
/// user-visible names quoted the same way the diagnostics quote them.
enum LenientFixItMessage: FixItMessage {
    /// Labels every type rewrite (`makeOptional`, `makeElementsOptional`,
    /// `makeElementsOptionalKeepingOuter`, `makePlainArray`), carrying the
    /// exact before/after spellings: "change '[String]' to '[String?]'". The
    /// user can judge the rewrite from the label alone, without applying it.
    case changeType(from: String, to: String)

    /// Labels `addAnnotation`: "add '@Strict'" — the strategy was implicit,
    /// so the fix inserts a brand-new annotation.
    case addAnnotation(String)

    /// Labels `replaceAnnotation`: "replace with '@Strict'" — a written
    /// annotation exists and the fix swaps its name in place.
    case replaceAnnotation(with: String)

    /// Labels `addTypePlaceholder`: "add an explicit type annotation" — the
    /// fix inserts a `<#Type#>` placeholder for the user to fill in, so the
    /// label names the obligation rather than a concrete type.
    case addTypeAnnotation

    /// The user-facing label, rendered verbatim in the fix-it popup.
    var message: String {
        switch self {
        case .changeType(let from, let to):
            return "change '\(from)' to '\(to)'"
        case .addAnnotation(let name):
            return "add '@\(name)'"
        case .replaceAnnotation(let name):
            return "replace with '@\(name)'"
        case .addTypeAnnotation:
            return "add an explicit type annotation"
        }
    }

    /// A stable identity in the `LenientCodable` domain, namespaced with a
    /// `fixit.` prefix so fix-it IDs can never collide with the diagnostic
    /// IDs minted by `LenientDiagnostic` in the same domain.
    ///
    /// As with the diagnostics, the `id` comes from `String(describing:
    /// self)`, so associated values are part of the identity — every distinct
    /// before/after pair in ``changeType(from:to:)`` mints its own ID.
    var fixItID: MessageID {
        let id: String = "fixit.\(String(describing: self))"
        return MessageID(domain: "LenientCodable", id: id)
    }
}
