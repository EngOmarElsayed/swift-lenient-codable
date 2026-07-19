//
//  TypeShape.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 18/07/2026.
//

import SwiftSyntax
import Foundation

enum TypeShape {
    /// `T` — no optional, no array. (Dictionaries `[K: V]` land here too:
    /// they are just values with whole-value semantics in v1.)
    case plain(TypeSyntax)

    /// `T?`
    case optional(wrapped: TypeSyntax)

    /// `[T]`
    case array(element: TypeSyntax)

    /// `[T?]`
    case arrayOfOptionals(element: TypeSyntax)

    /// `[T]?`
    case optionalArray(element: TypeSyntax)

    /// `[T?]?`
    case optionalArrayOfOptionals(element: TypeSyntax)

    /// `Optional<T>`, `Array<T>`, `Swift.Optional<T>`, ... — not analyzable.
    case unsupportedLonghand
}
