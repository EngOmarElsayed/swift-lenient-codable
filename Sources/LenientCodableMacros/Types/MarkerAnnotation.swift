//
//  MarkerAnnotation.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 18/07/2026.
//

import Foundation

/// The three property annotations `@LenientDecodable` understands.
/// RawValue == the attribute's base name as written in source.
enum MarkerAnnotation: String, CaseIterable {
    case nilOnFailure = "NilOnFailure"
    case dropOnFailure = "DropOnFailure"
    case strict = "Strict"

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
