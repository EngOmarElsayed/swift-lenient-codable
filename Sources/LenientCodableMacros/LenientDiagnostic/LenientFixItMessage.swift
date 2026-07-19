//
//  LenientFixItMessage.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 19/07/2026.
//

import SwiftDiagnostics

enum LenientFixItMessage: FixItMessage {
    case changeType(from: String, to: String)
    case addAnnotation(String)
    case replaceAnnotation(with: String)
    case addTypeAnnotation

    var message: String {
        switch self {
        case .changeType(let from, let to): 
            return "change '\(from)' to '\(to)'"
        case .addAnnotation(let name):       
            return "add '@\(name)'"
        case .replaceAnnotation(let name):   
            return "replace with '@\(name)'"
        case .addTypeAnnotation:             
            return "add an explicit type annotation"
        }
    }

    var fixItID: MessageID {
        let id: String = "fixit.\(String(describing: self))"
        return MessageID(domain: "LenientCodable", id: id)
    }
}
