//
//  StructDeclSyntax+Extension.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 18/07/2026.
//

import SwiftSyntax

extension StructDeclSyntax {
    func hasAttribute(named name: String) -> Bool {
        attributes.contains { element in
            guard case .attribute(let attribute) = element else { return false }

            // Common case: @MainActor
            if let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) {
                return identifier.name.text == name
            }

            // Qualified case: @_Concurrency.MainActor
            if let member = attribute.attributeName.as(MemberTypeSyntax.self) {
                return member.name.text == name
            }

            return false
        }
    }

    func hasCodingKeysEnum() -> Bool {
        return self.memberBlock.members.contains { member in
            if let enumDecl = member.decl.as(EnumDeclSyntax.self) { return enumDecl.name.text == "CodingKeys" }
            if let typealiasDecl = member.decl.as(TypeAliasDeclSyntax.self) { return typealiasDecl.name.text == "CodingKeys" }

            return false
        }
    }

    func accessPrefix() -> String {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public):  
                return "public "
            case .keyword(.package):
                return "package "
            case .keyword(.private):
                return "private "
            case .keyword(.internal):
                return "internal "
            default:
                continue
            }
        }

        return ""
    }

    func lenientDecodableOccurrences() -> [AttributeSyntax] {
        attributes.compactMap { element -> AttributeSyntax? in
            guard case .attribute(let attribute) = element,
                  attribute.getBaseName() == "LenientDecodable"
            else { return nil }
            return attribute
        }
    }
}
