//
//  StoredProperty.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 16/07/2026.
//

import SwiftSyntax

/// The macro's working record for one decodable stored property — the value
/// that flows through `LenientDecodableMacro`'s expansion pipeline and picks
/// up a decision at each stage.
///
/// One `StoredProperty` is created per surviving binding by
/// `filterProperties` (static, computed, and initialized-`let` members never
/// get one — they are skipped, not diagnosed). The record then accumulates
/// state in place:
///
/// 1. `filterProperties` fills the four `let` fields from source.
/// 2. `resolveStrategies` writes ``strategy`` from the property's marker
///    annotations (or the implicit default).
/// 3. `validateShapes` crosses strategy with declared shape and writes
///    ``plan`` — or records a diagnostic and leaves it `nil`.
/// 4. `buildInitFromDecoder` renders `plan` into the generated `init(from:)`.
///
/// The fields are deliberately a mix of extracted values (``name``) and
/// *original syntax nodes* (``type``, ``declAttributes``, ``sourceDecl``,
/// ``sourceBinding``): diagnostics and fix-its must anchor to — and build
/// replacements against — real nodes from the user's source, so the record
/// keeps them alongside anything it pre-computes.
struct StoredProperty {
    /// The property name — becomes the `CodingKeys` case and the `self.x`
    /// assignment target in the generated initializer.
    let name: String

    /// The *written* type, exactly as it appears in source.
    /// `validateShapes` pattern-matches its shape (via `parseToTypeShape()`);
    /// the resulting plan interpolates (parts of) it into the generated code.
    let type: TypeSyntax

    /// The attribute list of the enclosing `VariableDeclSyntax`.
    /// `resolveStrategies` reads the marker annotations from here. Kept
    /// (rather than a pre-parsed strategy) so `validateShapes` can attach
    /// diagnostics and fix-its to the actual attribute nodes.
    let declAttributes: AttributeListSyntax

    /// The whole enclosing `VariableDeclSyntax`. Needed by exactly one
    /// fix-it: "add '@Strict'" (and friends) on a property with an
    /// *implicit* strategy — there is no attribute node to replace, so the
    /// fix-it must rebuild the entire declaration with the new attribute
    /// prepended, and only this node reaches the attribute-list position.
    let sourceDecl: VariableDeclSyntax

    /// The original binding node — diagnostics and fix-its in
    /// `validateShapes` need real source nodes to anchor to and to build
    /// replacements against (e.g. rewriting the type annotation).
    let sourceBinding: PatternBindingSyntax

    /// Filled in by `resolveStrategies`; `nil` until then. Explicit
    /// annotations map through `MarkerAnnotation.strategy`; unannotated
    /// properties get `.nilOnFailure(implicit: true)`.
    var strategy: StoredPropertyStrategy?

    /// Written by `validateShapes` for every property that passed shape
    /// validation. `nil` afterwards means the shape was invalid (a
    /// diagnostic was recorded) — and the expansion aborts before codegen,
    /// so `buildInitFromDecoder` never sees a nil plan. This is the *only*
    /// field codegen consumes besides ``name``.
    var plan: DecodingPlan? = nil
}
