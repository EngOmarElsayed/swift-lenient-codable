//
//  LenientCodable.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 15/07/2026.
//

/// # LenientCodable — macro declarations
///
/// `@LenientDecodable` generates a `Decodable` conformance where **every stored
/// property is lenient by default** (`@NilOnFailure` semantics) and strictness is
/// an explicit, per-property opt-in via `@Strict`.
///
/// The three property annotations (`@NilOnFailure`, `@DropOnFailure`, `@Strict`)
/// are inert peer macros: they expand to nothing and exist only so the
/// type-level macro can read them off each property's attribute list during its
/// own expansion. They add zero runtime footprint and leave the
/// stored property types untouched, so `Equatable`/`Hashable`/memberwise-init
/// synthesis keep working.
///
/// The one-sentence philosophy: **lenient about values, strict about structure —
/// and you pick per property whether "strict" means throw.**

// MARK: - Type-level macro

/// Generates `CodingKeys` (skipped if you declare your own), `init(from:)`, and
/// the `Decodable` conformance for a struct.
///
/// Every stored property without an annotation is implicitly `@NilOnFailure`,
/// which requires a nil-shaped hole in the type:
///
/// | Declared type | Behavior                                              |
/// |---------------|-------------------------------------------------------|
/// | `T?`          | whole-value: any failure decodes as `nil` (reported)  |
/// | `[T?]`        | element padding: failed elements become `nil` in place|
/// | `[T?]?`       | as `[T?]`, but an absent/unusable array is `nil`      |
/// | `T`, `[T]`, `[T]?` | ❌ compile error with fix-its — change the type, |
/// |               | or opt out with `@Strict`                              |
///
/// Skipped entirely (never decoded, never diagnosed): static properties,
/// computed properties, and `let` constants with an initializer. A stored `var`
/// without an explicit type annotation (`var x = 0`) is a compile error, because
/// macros see syntax, not inferred types.
///
/// - Note: Structs only. Applying this to a class, enum, or actor is a compile
///   error.
@attached(member, names: named(init(from:)), named(CodingKeys))
@attached(extension, conformances: Decodable)
public macro LenientDecodable() = #externalMacro(
    module: "LenientCodableMacros",
    type: "LenientDecodableMacro"
)

// MARK: - Property annotations

/// Nil where it broke. Never fails the decode.
///
/// Valid shapes and behavior:
/// - `T?` — missing key / JSON `null` → `nil` (silent); any decoding failure →
///   `nil` (reported).
/// - `[T?]` — missing key / `null` → `[]` (silent); wrong container shape →
///   `[]` (reported); a `null` element → `nil` in place (silent, intentional
///   null is not an error); a malformed element → `nil` in place (reported with
///   its index). Count and positions are preserved: use
///   `values.count != values.compactMap { $0 }.count` as a one-line
///   "something failed" gate.
/// - `[T?]?` — as `[T?]`, but an absent or unusable array decodes as `nil`
///   instead of `[]`.
///
/// Invalid shapes (compile error + fix-its): non-optional `T`, `[T]`, `[T]?`.
/// The rule: this annotation puts `nil` exactly where the failure happened, so
/// the type must have a nil-shaped hole at that spot.
///
/// This is also the behavior `@LenientDecodable` applies implicitly to every
/// unannotated property — writing it explicitly is documentation, not a change
/// in behavior.
@attached(peer)
public macro NilOnFailure() = #externalMacro(
    module: "LenientCodableMacros",
    type: "MarkerMacro"
)

/// Pretend it wasn't there. Applies to `[T]` (non-optional array, non-optional
/// elements) only. Never fails the decode.
///
/// - Missing key / JSON `null` → `[]` (silent).
/// - Wrong container shape → `[]` (reported).
/// - A failed element — for any reason: unknown case inside it, missing
///   required field, `null`, wrong shape — → removed from the result (reported
///   with its index). Surviving elements keep their original order.
///
/// The result is a clean non-optional `[T]` with zero `nil` handling at call
/// sites — at the cost of erasing all in-value evidence that elements were
/// dropped (the evidence lives only in the error report). Element dropping is
/// a product decision: it is never applied by defaulting and must always be
/// written explicitly. Prefer `@NilOnFailure` on `[T?]` for lists that
/// represent obligations or completeness.
@attached(peer)
public macro DropOnFailure() = #externalMacro(
    module: "LenientCodableMacros",
    type: "MarkerMacro"
)

/// Opt this property out of the lenient default: byte-for-byte synthesized
/// behavior (`decode` for non-optionals, `decodeIfPresent` for optionals).
/// Applies to any type.
///
/// Optionality covers *absence* only — a missing key or JSON `null` decodes as
/// `nil`, but a present-and-broken value **throws and fails the entire
/// decode**. That absence-vs-failure distinction is the whole difference
/// between `@Strict var x: [Int]?` and any lenient annotation.
///
/// In a `@LenientDecodable` struct, `@Strict` properties are the **only** way a
/// decode can fail — grep for `@Strict` to audit every hard failure point, and
/// the compiler guarantees the list is complete.
///
/// - Warning: On an enum property, synthesized decoding throws
///   `DecodingError.dataCorrupted` for an *unknown raw value* — meaning a new
///   backend enum case will fail the decode. Only use `@Strict` on enums from
///   evolving APIs deliberately; otherwise prefer `@NilOnFailure` and watch the
///   error digest.
@attached(peer)
public macro Strict() = #externalMacro(
    module: "LenientCodableMacros",
    type: "MarkerMacro"
)
