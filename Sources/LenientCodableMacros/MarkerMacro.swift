//
//  MarkerMacro.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 15/07/2026.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// The shared, deliberately inert implementation behind all three property
/// annotations: `@NilOnFailure`, `@DropOnFailure`, and `@Strict`.
///
/// The annotations exist so that `@LenientDecodable` can *read them off the
/// attribute list* during its own expansion (via `MarkerAnnotation`) — they
/// carry information, not behavior. But an attached macro must be backed by
/// *some* implementation for the attribute to be legal Swift, so all three
/// declarations in the `LenientCodable` module point here, and the expansion
/// intentionally returns nothing.
///
/// A peer macro is the least invasive attachment role for this job: it adds
/// no members, no accessors, and no conformances, so the annotated property
/// stays a plain stored property — `Equatable`/`Hashable`/memberwise-init
/// synthesis keep working, and there is zero runtime footprint. (Compare a
/// property-wrapper approach, which would change the stored type itself.)
///
/// Validation is *not* done here, by design: this macro expands once per
/// annotation in isolation, with no view of the property's declared shape or
/// competing annotations. All rules about where an annotation may appear
/// live in `LenientDecodableMacro.resolveStrategies`/`validateShapes`, which
/// see the whole struct at once.
public struct MarkerMacro: PeerMacro {
    /// Expands to no peers, always.
    ///
    /// The one check distinguishes attachment to a variable declaration from
    /// anything else (a function, a type, …); both paths currently return
    /// `[]`, but misattached annotations are also invisible to
    /// `@LenientDecodable` — it only reads attributes from stored-property
    /// declarations — so they are silently inert today.
    ///
    /// Planned for v1.1.0:
    /// - an error when the annotation is attached to anything that is not a
    ///   property;
    /// - an error for annotations on a `let` with an initializer, which the
    ///   type-level macro skips entirely (the annotation looks meaningful
    ///   but does nothing).
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard declaration.is(VariableDeclSyntax.self) else {
            // Diagnostic that this macro is added on properties only will be added in v1.1.0
            return []
        }
        // add an error that macro drop can't be applied to let with init will be added in v1.1.0

        return []
    }
}
