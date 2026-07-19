//
//  PatternBindingSyntax+Extension.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 18/07/2026.
//

import SwiftSyntax

extension PatternBindingSyntax {
    func isComputed() -> Bool {
        guard let accessorBlock else { return false }
        switch accessorBlock.accessors {
        case .getter:
            return true
            
        case .accessors(let accessorList):
            return accessorList.contains { accessor in
                switch accessor.accessorSpecifier.tokenKind {
                case .keyword(.get),
                        .keyword(.set),
                        .keyword(._read),
                        .keyword(._modify),
                        .keyword(.unsafeAddress),
                        .keyword(.unsafeMutableAddress):
                    return true
                default:
                    return false
                }
            }
        }
    }
}
