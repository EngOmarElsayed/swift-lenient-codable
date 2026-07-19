//
//  StoredPropertyStrategy.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 18/07/2026.
//

import Foundation

enum StoredPropertyStrategy {
    case nilOnFailure(implicit: Bool)  // implicit = applied by @LenientDecodable, changes diagnostic wording in step 4
    case dropOnFailure
    case strict
    
    func shouldAddProvenanceComment() -> String? {
        guard case .nilOnFailure(implicit: true) = self else { return nil }
        return "// implicit @NilOnFailure (applied by @LenientDecodable)"
    }
}
