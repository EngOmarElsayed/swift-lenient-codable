//
//  TypeShape.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 18/07/2026.
//

import SwiftSyntax
import Foundation

/// The purely *syntactic* classification of a property's written type — the
/// second input to the strategy × shape matrix in `validateShapes`.
///
/// Produced by `TypeSyntax.parseToTypeShape()`, which pattern-matches the
/// sugared spelling of the type annotation: is there an outer `?`, is there
/// a `[...]`, is there a `?` on the element. That yields the six analyzable
/// shapes — optionality at the two depths leniency cares about (whole value
/// and element), crossed with array-ness — plus one sentinel for spellings
/// the parser refuses to guess about.
///
/// "Syntactic" is the operative word: a macro sees source text, not resolved
/// types. `parseToTypeShape()` cannot know that `Optional<String>` *is*
/// `String?` or that a typealias hides an array — it classifies exactly what
/// was written. That is why longhand generics get ``unsupportedLonghand``
/// (surfaced as the `sugarSyntaxRequired` diagnostic) rather than a wrong
/// guess, and why unwrapping stops at one optional and one array level: the
/// payload `TypeSyntax` (`wrapped:`/`element:`) is carried opaquely into the
/// `DecodingPlan` and spelled back out in the generated code, whatever it is.
enum TypeShape {
    /// `T` — no optional, no array. (Dictionaries `[K: V]` land here too:
    /// they are just values with whole-value semantics in v1.)
    ///
    /// Valid for `@Strict` only; `@NilOnFailure` has no nil-shaped hole to
    /// use and diagnoses `requiresOptional`.
    case plain(TypeSyntax)

    /// `T?` — the whole-value shapes: `strictOptional` for `@Strict`,
    /// `nilOnFailureValue` for `@NilOnFailure`. Never valid for
    /// `@DropOnFailure`.
    case optional(wrapped: TypeSyntax)

    /// `[T]` — the only shape `@DropOnFailure` accepts (dropped elements
    /// leave no hole behind). For `@NilOnFailure` it diagnoses
    /// `arrayRequiresOptionalElements`: padding needs somewhere to put the
    /// `nil`.
    case array(element: TypeSyntax)

    /// `[T?]` — the element-padding shape for `@NilOnFailure`. Rejected by
    /// `@DropOnFailure` (`dropRequiresNonOptionalElements`): the element
    /// hole and dropping are competing answers to the same failure.
    case arrayOfOptionals(element: TypeSyntax)

    /// `[T]?` — optional array, non-optional elements. Only `@Strict` can
    /// use it as-is; the lenient strategies each reject it with a fix-it
    /// toward the shape they need (`[T?]?` or `[T]`).
    case optionalArray(element: TypeSyntax)

    /// `[T?]?` — element padding plus "an absent list is `nil`":
    /// `nilPaddingOptionalArray` for `@NilOnFailure`, `strictOptional` for
    /// `@Strict`.
    case optionalArrayOfOptionals(element: TypeSyntax)

    /// `Optional<T>`, `Array<T>`, `Swift.Optional<T>`, … — longhand
    /// spellings the syntactic parser refuses to unwrap (see
    /// `TypeSyntax.isLonghand()`). Carries no payload because nothing
    /// downstream may use such a type; `validateShapes` turns it into the
    /// `sugarSyntaxRequired` diagnostic before any strategy is considered.
    case unsupportedLonghand
}
