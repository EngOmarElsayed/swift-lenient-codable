//
//  AttributeListSyntax+Extension.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 18/07/2026.
//

import SwiftSyntax

extension AttributeListSyntax {
    func getLenientMarkerAnnotations() -> [(marker: MarkerAnnotation, node: AttributeSyntax)] {
        compactMap { element -> (MarkerAnnotation, AttributeSyntax)? in
            guard case .attribute(let attribute) = element,
                  let name = attribute.getBaseName(),
                  let marker = MarkerAnnotation(rawValue: name) else { return nil }

            return (marker, attribute)
        }
    }
}
