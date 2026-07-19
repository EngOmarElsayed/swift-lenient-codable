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
import SwiftDiagnostics

public struct LenientDecodableMacro: MemberMacro  {
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
//       guard !protocols.isEmpty else {
//           context.diagnose(Diagnostic(node: node, message: LenientDiagnostic.redundantConformance))
//           return []
//       }

       let decl: DeclSyntax =
           """
           extension \(type.trimmed): Decodable {}
           """
       return [decl.cast(ExtensionDeclSyntax.self)]
   }
}

// MARK: - Private LenientDecodableMacro methods
private extension LenientDecodableMacro {
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

    static func annotationFixIt(_ name: String, annotationNode: AttributeSyntax?, sourceDecl: VariableDeclSyntax) -> FixIt? {
        if let annotationNode {
            return LenientFixItHelperMethods.replaceAnnotation(annotationNode, with: name)
        }
        return LenientFixItHelperMethods.addAnnotation(name, to: sourceDecl)
    }
}
