//
//  LenientDecodableMacro.swift
//  LenientCodableMacro
//
//  Created by Omar Elsayed on 15/07/2026.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

/// The implementation of `@LenientDecodable` — the type-level macro that
/// turns a struct's property shapes and marker annotations into a lenient
/// `Decodable` conformance.
///
/// The macro plays two attached roles on the same struct:
///
/// - **`MemberMacro`** generates the members: a `CodingKeys` enum (unless
///   the struct declares its own) and the `init(from:)` whose body is one
///   decoding line per stored property.
/// - **`ExtensionMacro`** adds the `extension T: Decodable {}` conformance.
///
/// All validation lives here, in the member expansion's pipeline — the
/// marker annotations themselves are inert (`MarkerMacro`), and this is the
/// only place with the whole-struct view the rules need:
///
/// 1. `filterProperties` — collect the decodable stored properties, skipping
///    statics, computed properties, and initialized `let`s.
/// 2. `resolveStrategies` — read each property's marker annotation into a
///    `StoredPropertyStrategy`; unannotated properties default to implicit
///    `@NilOnFailure`.
/// 3. `validateShapes` — cross strategy with the declared `TypeShape` and
///    produce a `DecodingPlan` per property, or diagnostics with fix-its.
/// 4. `resolveCodingKeys` + `buildInitFromDecoder` — render the members.
///
/// Any diagnosed error makes the expansion return no members: the macro
/// never generates code for a struct it has complained about.
public struct LenientDecodableMacro: MemberMacro  {
    /// Generates `CodingKeys` and `init(from:)` for the attached struct by
    /// running the four-stage pipeline described on the type.
    ///
    /// Two structural checks run before the pipeline: the declaration must
    /// be a struct (`structsOnly` otherwise, anchored at the attribute), and
    /// `@LenientDecodable` must appear only once (`duplicateAttribute`,
    /// anchored at the last occurrence). `resolveStrategies` and
    /// `validateShapes` report failure through their `Bool` return after
    /// diagnosing every offending property — so a struct with three bad
    /// properties gets three diagnostics from one compile.
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let structDec = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: LenientDiagnostic.structsOnly))
            return []
        }

        let occurrences = structDec.lenientDecodableOccurrences()
        guard occurrences.count < 2 else {
            if let node = Syntax(occurrences.last), occurrences.count >= 2 {
                context.diagnose(Diagnostic(node: node, message: LenientDiagnostic.duplicateAttribute))
            }
            return []
        }

        var properties: [StoredProperty] = filterProperties(structDec: structDec, in: context)
        guard resolveStrategies(for: &properties, in: context) else { return [] }
        guard validateShapes(for: &properties, in: context) else { return [] }

        var members: [DeclSyntax] = []
        if let codingDec = resolveCodingKeys(in: structDec, for: properties) { members.append(codingDec) }
        members.append(buildInitFromDecoder(for: properties, structDecl: structDec))

        return members
    }
}

// MARK: - LenientDecodableMacro ExtensionMacro
extension LenientDecodableMacro: ExtensionMacro {
   /// Adds `extension T: Decodable {}` for the attached struct.
   ///
   /// The structural early-outs mirror the member expansion's, but *silently*
   /// — the member role has already anchored the `structsOnly` /
   /// `duplicateAttribute` diagnostics, and repeating them here would double
   /// every error.
   ///
   /// The `protocols` guard emits the `redundantConformance` warning when
   /// the conformance the macro would add is pointless.
   ///
   public static func expansion(
       of node: SwiftSyntax.AttributeSyntax,
       attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
       providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
       conformingTo protocols: [SwiftSyntax.TypeSyntax],
       in context: some SwiftSyntaxMacros.MacroExpansionContext
   ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
       guard let structDec = declaration.as(StructDeclSyntax.self) else { return [] }
       let occurrences = structDec.lenientDecodableOccurrences()
       guard occurrences.count < 2 else { return [] }

       guard !protocols.contains(where: { $0.as(IdentifierTypeSyntax.self)?.name == "Decodable" }) else {
           context.diagnose(Diagnostic(node: node, message: LenientDiagnostic.redundantConformance))
           return []
       }

       let decl: DeclSyntax =
           """
           extension \(type.trimmed): Decodable {}
           """
       return [decl.cast(ExtensionDeclSyntax.self)]
   }
}

// MARK: - Private LenientDecodableMacro methods
private extension LenientDecodableMacro {
   /// Stage 1: walks the member block and collects one `StoredProperty` per
   /// decodable stored property.
   ///
   /// Skipped without diagnostics (never decoded, so never wrong): static
   /// properties, computed properties, and `let`s with an initializer (their
   /// value is fixed; assigning in `init(from:)` would not compile).
   ///
   /// Two member shapes are errors, not skips: a hand-written `init(from:)`
   /// (would collide with the generated one — `handWrittenInitFromDecoder`,
   /// anchored at the initializer) and a stored `var` without a type
   /// annotation (`var x = 0` — macros see syntax, not inferred types;
   /// `missingTypeAnnotation` with a `<#Type#>` fix-it). Both return an
   /// empty list immediately.
   static func filterProperties(structDec: StructDeclSyntax, in context: some MacroExpansionContext) -> [StoredProperty] {
       var properties: [StoredProperty] = []
       memberLoop: for member in structDec.memberBlock.members {
           if let initDecl = member.decl.as(InitializerDeclSyntax.self),
              initDecl.signature.parameterClause.parameters.count == 1,
              initDecl.signature.parameterClause.parameters.first?.firstName.text == "from" {
               context.diagnose(Diagnostic(
                   node: initDecl,
                   message: LenientDiagnostic.handWrittenInitFromDecoder))
               return []
           }

           guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
           guard !varDecl.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) else { continue }
           let isLet = varDecl.bindingSpecifier.tokenKind == .keyword(.let)
           for binding in varDecl.bindings {
               if isLet && binding.initializer != nil { continue memberLoop }
               guard !binding.isComputed() else { continue memberLoop }
               guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue memberLoop }
               guard let type = binding.typeAnnotation?.type else {
                   context.diagnose(Diagnostic(
                       node: binding,
                       message: LenientDiagnostic.missingTypeAnnotation,
                       fixIts: [LenientFixItHelperMethods.addTypePlaceholder(to: binding)]))
                   return []
               }

               properties.append(StoredProperty(
                   name: pattern.identifier.text,
                   type: type,
                   declAttributes: varDecl.attributes,
                   sourceDecl: varDecl,
                   sourceBinding: binding
               ))
           }
       }

       return properties
   }

   /// Stage 2: writes each property's `strategy` from its marker
   /// annotations.
   ///
   /// Zero annotations → the `@LenientDecodable` default,
   /// `.nilOnFailure(implicit: true)`. Exactly one → its
   /// `MarkerAnnotation.strategy`. Two or more → `multipleAnnotations`,
   /// anchored at the second annotation and listing all of them.
   ///
   /// - Returns: `false` if any property was diagnosed — but only after
   ///   *every* property has been visited, so all conflicts surface in one
   ///   compile.
   static func resolveStrategies(
       for properties: inout [StoredProperty],
       in context: some MacroExpansionContext
   ) -> Bool {
       var hadError = false
       for index in properties.indices {
           let found = properties[index].declAttributes.getLenientMarkerAnnotations()

           switch found.count {
           case 0:
               properties[index].strategy = .nilOnFailure(implicit: true)

           case 1:
               properties[index].strategy = found[0].marker.strategy

           default:
               context.diagnose(Diagnostic(
                   node: found[1].node,
                   message: LenientDiagnostic.multipleAnnotations(
                       annotations: found.map(\.marker.rawValue))))
               hadError = true
           }
       }

       return !hadError
   }

   /// Stage 3: executes the strategy × shape matrix — every valid
   /// combination writes the property's `DecodingPlan`, every invalid one
   /// emits a `LenientDiagnostic` with fix-its from both families (reshape
   /// the type, or switch the annotation via `annotationFixIt`).
   ///
   /// The full matrix, including which plan or diagnostic each cell
   /// produces, is documented on `DecodingPlan`. Longhand types
   /// (`Optional<T>`, `Array<T>`) short-circuit to `sugarSyntaxRequired`
   /// before any strategy is considered.
   ///
   /// Diagnostics anchor at the property's annotation when one was written,
   /// else at the type annotation — an implicit-strategy error should point
   /// at the type, not at an attribute the user never wrote.
   ///
   /// - Returns: `false` if any property was diagnosed; like stage 2, it
   ///   visits every property first.
   static func validateShapes(
       for properties: inout [StoredProperty],
       in context: some MacroExpansionContext
   ) -> Bool {
       var hadError = false
       for index in properties.indices {
           guard let StoredPropertyStrategy = properties[index].strategy else { continue }
           let shape = properties[index].type.parseToTypeShape()

           let annotationNode = properties[index].declAttributes.getLenientMarkerAnnotations().first?.node
           let anchor: Syntax = annotationNode.map(Syntax.init) ?? Syntax(properties[index].type)
           let sourceBinding = properties[index].sourceBinding
           let sourceDecl = properties[index].sourceDecl

           if case .unsupportedLonghand = shape {
               context.diagnose(Diagnostic(
                   node: properties[index].type,
                   message: LenientDiagnostic.sugarSyntaxRequired))
               hadError = true
               continue
           }

           switch StoredPropertyStrategy {
           case .strict:
               switch shape {
               case .optional(let wrapped):
                   properties[index].plan = .strictOptional(wrapped: wrapped)
                   
               case .optionalArray(let element):
                   properties[index].plan = .strictOptional(wrapped: TypeSyntax(ArrayTypeSyntax(element: element)))
                   
               case .optionalArrayOfOptionals(let element):
                   properties[index].plan = .strictOptional(wrapped: TypeSyntax(ArrayTypeSyntax(element: OptionalTypeSyntax(wrappedType: element))))
                   
               case .plain, .array, .arrayOfOptionals:
                   properties[index].plan = .strictRequired(type: properties[index].type)
               case .unsupportedLonghand:
                   break // handled above
               }
               
           case .nilOnFailure(let implicit):
               switch shape {
               case .optional(let wrapped):
                   properties[index].plan = .nilOnFailureValue(wrapped: wrapped)
                   
               case .arrayOfOptionals(let element):
                   properties[index].plan = .nilPadding(element: element)
                   
               case .optionalArrayOfOptionals(let element):
                   properties[index].plan = .nilPaddingOptionalArray(element: element)
                   
               case .plain:
                   context.diagnose(Diagnostic(
                       node: anchor,
                       message: LenientDiagnostic.requiresOptional(implicit: implicit),
                       fixIts: [
                           LenientFixItHelperMethods.makeOptional(sourceBinding),
                           annotationFixIt("Strict", annotationNode: annotationNode, sourceDecl: sourceDecl),
                       ].compactMap { $0 }))
                   hadError = true
                   
               case .array(let element):
                   context.diagnose(Diagnostic(
                       node: anchor,
                       message: LenientDiagnostic.arrayRequiresOptionalElements(implicit: implicit),
                       fixIts: [
                           LenientFixItHelperMethods.makeElementsOptional(sourceBinding, element: element),
                           annotationFixIt("DropOnFailure", annotationNode: annotationNode, sourceDecl: sourceDecl),
                           annotationFixIt("Strict", annotationNode: annotationNode, sourceDecl: sourceDecl),
                       ].compactMap { $0 }))
                   hadError = true
                   
               case .optionalArray(let element):
                   context.diagnose(Diagnostic(
                       node: anchor,
                       message: LenientDiagnostic.arrayRequiresOptionalElements(implicit: implicit),
                       fixIts: [
                           LenientFixItHelperMethods.makeElementsOptionalKeepingOuter(sourceBinding, element: element),
                           annotationFixIt("Strict", annotationNode: annotationNode, sourceDecl: sourceDecl),
                       ].compactMap { $0 }))
                   hadError = true
                   
               case .unsupportedLonghand:
                   break // handled above
               }
               
           case .dropOnFailure:
               switch shape {
               case .array(let element):
                   properties[index].plan = .dropOnFailure(element: element)
               case .plain, .optional:
                   context.diagnose(Diagnostic(
                       node: anchor,
                       message: LenientDiagnostic.dropRequiresArray,
                       fixIts: [annotationFixIt("Strict", annotationNode: annotationNode, sourceDecl: sourceDecl)].compactMap { $0 }))
                   hadError = true
                   
               case .optionalArray(let element), .optionalArrayOfOptionals(let element):
                   context.diagnose(Diagnostic(
                       node: anchor,
                       message: LenientDiagnostic.dropRequiresNonOptionalArray,
                       fixIts: [
                           LenientFixItHelperMethods.makePlainArray(sourceBinding, element: element),
                           annotationFixIt("Strict", annotationNode: annotationNode, sourceDecl: sourceDecl),
                       ].compactMap { $0 }))
                   hadError = true
                   
               case .arrayOfOptionals(let element):
                   context.diagnose(Diagnostic(
                       node: anchor,
                       message: LenientDiagnostic.dropRequiresNonOptionalElements,
                       fixIts: [
                           LenientFixItHelperMethods.makePlainArray(sourceBinding, element: element),
                           annotationFixIt("NilOnFailure", annotationNode: annotationNode, sourceDecl: sourceDecl),
                       ].compactMap { $0 }))
                   hadError = true
                   
               case .unsupportedLonghand:
                   break // handled above
               }
           }
       }

       return !hadError
   }

   /// Stage 4a: builds the `private enum CodingKeys: String, CodingKey`
   /// declaration with one case per collected property — or returns `nil`
   /// when the struct already declares a `CodingKeys` enum or typealias
   /// (`hasCodingKeysEnum()`), deferring to the user's key mapping. The
   /// generated `init(from:)` references `CodingKeys` by name either way.
   static func resolveCodingKeys(
       in structDecl: StructDeclSyntax,
       for properties: [StoredProperty]
   ) -> DeclSyntax? {
       var keysDecl: DeclSyntax?
       if structDecl.hasCodingKeysEnum() { return keysDecl }

       let cases = properties
           .map { "    case \($0.name)" }
           .joined(separator: "\n")

       keysDecl =
           """
           private enum CodingKeys: String, CodingKey {
           \(raw: cases)
           }
           """

       return keysDecl
   }

   /// Stage 4b: renders the `init(from:)` declaration.
   ///
   /// The body is the container line followed by each property's
   /// `DecodingPlan.decodingLine(name:)`, preceded by the provenance comment
   /// for implicitly-lenient properties
   /// (`StoredPropertyStrategy.shouldAddProvenanceComment()`). The
   /// initializer inherits the struct's access level via `accessPrefix()` —
   /// a `public` struct needs a `public init(from:)` to be decodable outside
   /// its module.
   ///
   /// Only reached when every property holds a plan (the pipeline gates
   /// guarantee it); the `guard let plan` inside is belt-and-braces, not a
   /// reachable path.
   static func buildInitFromDecoder(
       for properties: [StoredProperty],
       structDecl: StructDeclSyntax
   ) -> DeclSyntax {
       let access = structDecl.accessPrefix()

       var lines: [String] = []
       lines.append("let container = try decoder.container(keyedBy: CodingKeys.self)")

       for property in properties {
           guard let plan = property.plan else { continue } // diagnostic for this one

           if let provenance = property.strategy?.shouldAddProvenanceComment() { lines.append(provenance) }
           lines.append(plan.decodingLine(name: property.name))
       }

       let body = lines
           .map { "        \($0)" }
           .joined(separator: "\n")

       return DeclSyntax(
           """
           \(raw: access)init(from decoder: any Decoder) throws {
           \(raw: body)
           }
           """
       )
   }

    /// Builds the "switch strategy" fix-it for a shape error, picking the
    /// right edit for the annotation's provenance: an explicit annotation is
    /// rewritten in place (`replaceAnnotation`), an implicit strategy has no
    /// node to rewrite so the new annotation is prepended to the declaration
    /// (`addAnnotation`).
    static func annotationFixIt(_ name: String, annotationNode: AttributeSyntax?, sourceDecl: VariableDeclSyntax) -> FixIt? {
        if let annotationNode {
            return LenientFixItHelperMethods.replaceAnnotation(annotationNode, with: name)
        }
        return LenientFixItHelperMethods.addAnnotation(name, to: sourceDecl)
    }
}
