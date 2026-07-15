//
//  LenientCodablePlugin.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 15/07/2026.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

@main
struct LenientCodablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LenientDecodableMacro.self,
        MarkerMacro.self,
    ]
}
