//
//  AttributeSyntax+Extension.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 18/07/2026.
//

import SwiftSyntax

extension AttributeSyntax {
    func getBaseName() -> String? {
        if let identifier = attributeName.as(IdentifierTypeSyntax.self) { return identifier.name.text }
        if let member = attributeName.as(MemberTypeSyntax.self) { return member.name.text }
        return nil
    }
}
