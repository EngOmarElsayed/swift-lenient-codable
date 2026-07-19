//
//  MarkerMacro.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 15/07/2026.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct MarkerMacro: PeerMacro {
    static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard declaration.is(VariableDeclSyntax.self) else {
            // Diagnostic that this macro is added on properties only will be added in v1.1.0
            return []
        }
        // add an error that macor drop can't be applied to let with init will be added in v1.1.0

        return []
    }
}
