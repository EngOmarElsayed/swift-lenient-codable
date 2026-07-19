//
//  LenientFixItBuilder.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 19/07/2026.
//

import SwiftSyntax
import SwiftDiagnostics

enum LenientFixItHelperMethods {
    /// `T` → `T?`
    static func makeOptional(_ binding: PatternBindingSyntax) -> FixIt? {
        guard let old = binding.typeAnnotation?.type else { return nil }
        let new = preservingTrivia(TypeSyntax(OptionalTypeSyntax(wrappedType: old.trimmed)), from: old)
        return replaceType(old: old, new: new)
    }

    /// `[E]` → `[E?]`
    static func makeElementsOptional(_ binding: PatternBindingSyntax, element: TypeSyntax) -> FixIt? {
        guard let old = binding.typeAnnotation?.type else { return nil }
        let new = preservingTrivia(TypeSyntax(ArrayTypeSyntax(element: OptionalTypeSyntax(wrappedType: element.trimmed))), from: old)
        return replaceType(old: old, new: new)
    }

    /// `[E]?` → `[E?]?` — adds the element hole, deliberately KEEPS the outer
    /// optional the user already declared.
    static func makeElementsOptionalKeepingOuter( _ binding: PatternBindingSyntax, element: TypeSyntax) -> FixIt? {
        guard let old = binding.typeAnnotation?.type else { return nil }
        let new = preservingTrivia(
            TypeSyntax(
                OptionalTypeSyntax(
                    wrappedType: ArrayTypeSyntax(
                        element: OptionalTypeSyntax(
                            wrappedType: element.trimmed
                        )
                    )
                )
            ),
            from: old
        )

        return replaceType(old: old, new: new)
    }

    /// `[E]?` → `[E]` and `[E?]` → `[E]`
    static func makePlainArray(_ binding: PatternBindingSyntax, element: TypeSyntax) -> FixIt? {
        guard let old = binding.typeAnnotation?.type else { return nil }
        let new = preservingTrivia(TypeSyntax(ArrayTypeSyntax(element: element.trimmed)), from: old)
        return replaceType(old: old, new: new)
    }

    // MARK: Annotation changes
    /// Prepends `@Name ` to the property declaration. Used when the strategy
    /// was implicit — there is no annotation node to replace.
    static func addAnnotation(_ name: String, to varDecl: VariableDeclSyntax) -> FixIt {
        var attribute = AttributeSyntax(attributeName: TypeSyntax(IdentifierTypeSyntax(name: .identifier(name))))
        attribute.trailingTrivia = .space

        var newDecl = varDecl
        attribute.leadingTrivia = varDecl.leadingTrivia
        newDecl.leadingTrivia = Trivia()
        newDecl.attributes = varDecl.attributes + [.attribute(attribute)]

        return FixIt(
            message: LenientFixItMessage.addAnnotation(name),
            changes: [.replace(oldNode: Syntax(varDecl), newNode: Syntax(newDecl))])
    }

    /// Rewrites an existing marker annotation's name in place: `@NilOnFailure`
    /// → `@Strict`. Trivia (position, spacing) is untouched because only the
    /// name node changes.
    static func replaceAnnotation(_ attribute: AttributeSyntax, with name: String) -> FixIt {
        let newTypeSyntax = TypeSyntax(IdentifierTypeSyntax(name: .identifier(name)))
        var newAttribute = AttributeSyntax(newTypeSyntax)
        newAttribute.leadingTrivia = attribute.leadingTrivia
        newAttribute.trailingTrivia = attribute.trailingTrivia

        return FixIt(
            message: LenientFixItMessage.replaceAnnotation(with: name),
            changes: [.replace(oldNode: Syntax(attribute), newNode: Syntax(newAttribute))]
        )
    }

    // MARK: Missing type annotation
    /// `var x = 0` → `var x: <#Type#> = 0` — the editor-placeholder token
    /// renders as a fill-in-the-blank in Xcode.
    static func addTypePlaceholder(to binding: PatternBindingSyntax) -> FixIt {
        var newBinding = binding
        var pattern = binding.pattern
        pattern.trailingTrivia = Trivia()
        newBinding.pattern = pattern
        newBinding.typeAnnotation = TypeAnnotationSyntax(
            type: TypeSyntax(
                IdentifierTypeSyntax(name: .identifier("<#Type#>"))
            ),
            trailingTrivia: .space
        )

        return FixIt(
            message: LenientFixItMessage.addTypeAnnotation,
            changes: [.replace(
                oldNode: Syntax(binding),
                newNode: Syntax(newBinding)
            )]
        )
    }

    // MARK: ReplaceType
    private static func replaceType(old: TypeSyntax, new: TypeSyntax) -> FixIt {
        FixIt(
            message: LenientFixItMessage.changeType(
                from: old.trimmedDescription, to: new.trimmedDescription),
            changes: [.replace(oldNode: Syntax(old), newNode: Syntax(new))])
    }

    private static func preservingTrivia(_ new: TypeSyntax, from old: TypeSyntax) -> TypeSyntax {
        var node = new
        node.leadingTrivia = old.leadingTrivia
        node.trailingTrivia = old.trailingTrivia
        return node
    }
}
