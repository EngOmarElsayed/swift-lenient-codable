//
//  LenientCodablePlugin.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 15/07/2026.
//

// SwiftCompilerPlugin is a host-tools-only module and is unavailable when
// DocC extracts symbol graphs for this target, so the plugin entry point is
// compiled conditionally.
#if canImport(SwiftCompilerPlugin)
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

/// The compiler-plugin entry point: tells the compiler which macro
/// implementations this executable provides. `LenientDecodableMacro` backs
/// `@LenientDecodable`; `MarkerMacro` backs all three property annotations.
@main
struct LenientCodablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LenientDecodableMacro.self,
        MarkerMacro.self,
    ]
}
#endif
