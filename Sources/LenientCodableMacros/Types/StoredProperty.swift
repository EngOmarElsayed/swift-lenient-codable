//
//  StoredProperty.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 16/07/2026.
//

import SwiftSyntax

struct StoredProperty {
    /// The property name — becomes the CodingKeys case and the `self.x` target.
    let name: String

    /// The *written* type, exactly as it appears in source.
    /// Step 4 pattern-matches its shape; step 7 interpolates (parts of) it.
    let type: TypeSyntax

    /// The attribute list of the enclosing VariableDeclSyntax.
    /// Step 3 reads the marker annotations from here. Kept (rather than a
    /// pre-parsed strategy) so step 4 can attach diagnostics and fix-its to
    /// the actual attribute nodes.
    let declAttributes: AttributeListSyntax

    /// The whole enclosing VariableDeclSyntax. Needed by exactly one fix-it:
    /// "add '@Strict'" (and friends) on a property with an *implicit*
    /// strategy — there is no attribute node to replace, so the fix-it must
    /// rebuild the entire declaration with the new attribute prepended, and
    /// only this node reaches the attribute-list position.
    let sourceDecl: VariableDeclSyntax

    /// The original binding node — diagnostics and fix-its in step 4 need
    /// real source nodes to anchor to and to build replacements against.
    let sourceBinding: PatternBindingSyntax

    /// Filled in by step 3. `nil` until then.
    var strategy: StoredPropertyStrategy?

    /// Written by step 4 for every property that passed shape validation.
    /// `nil` after step 4 means the shape was invalid (a diagnostic was
    /// recorded) — step 5's gate guarantees codegen never sees a nil plan.
    /// This is the *only* field step 7 consumes besides `name`.
    var plan: DecodingPlan? = nil
}
