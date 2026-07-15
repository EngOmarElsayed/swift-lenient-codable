//
//  LenientDecodableMacro.swift
//  LenientCodableMacro
//
//  Created by Omar Elsayed on 15/07/2026.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct LenientDecodableMacro: MemberMacro  {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        // check it's struct
        // then check if codingKeys exists if not create one
        // then check the annotation added to each property by default we consider the property have NilOnFailure
        // then create the decoding init with the proper method
        // then return

        []
    }
}

// MARK: - LenientDecodableMacro ExtensionMacro
extension LenientDecodableMacro: ExtensionMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
        providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else { return [] }
        guard !protocols.isEmpty else { return [] } // add a warning here that our macro already adds Decodable

        let decl: DeclSyntax =
            """
            extension \(type.trimmed): Decodable {}
            """
        return [decl.cast(ExtensionDeclSyntax.self)]
    }
}
