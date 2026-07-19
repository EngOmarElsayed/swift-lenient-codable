//
//  DecodingPlan.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 18/07/2026.
//

import SwiftSyntax
import Foundation

enum DecodingPlan {
    /// `self.x = try container.decode(T.self, forKey: .x)`
    case strictRequired(type: TypeSyntax)

    /// `self.x = try container.decodeIfPresent(W.self, forKey: .x)`
    case strictOptional(wrapped: TypeSyntax)

    /// `self.x = LenientDecoding.nilOnFailure(W.self, in:forKey:decoder:)`
    case nilOnFailureValue(wrapped: TypeSyntax)

    /// `self.x = LenientDecoding.nilPadding(E.self, ...)` → `[E?]`
    case nilPadding(element: TypeSyntax)

    /// `self.x = LenientDecoding.nilPaddingOptional(E.self, ...)` → `[E?]?`
    case nilPaddingOptionalArray(element: TypeSyntax)

    /// `self.x = LenientDecoding.dropOnFailure(E.self, ...)` → `[E]`
    case dropOnFailure(element: TypeSyntax)

}

// MARK: - DecodingPlan decodingLine
extension DecodingPlan {
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
