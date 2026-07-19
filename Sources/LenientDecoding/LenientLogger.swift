//
//  LenientLogger.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 19/07/2026.
//

import Foundation
#if canImport(os)
import os
#endif

enum LenientErrorLogger {
    static func log(_ message: @escaping @autoclosure () -> String) {
        #if DEBUG
        #if canImport(os)
        if #available(iOS 14, macOS 11, tvOS 14, watchOS 7, macCatalyst 14, *) {
            Logger(subsystem: "LenientCodable", category: "decoding").error("\(message(), privacy: .public)")
            return
        }
        #endif
        print("[LenientCodable] \(message())")
        #endif
    }

    static func path<Key: CodingKey>(
        of container: KeyedDecodingContainer<Key>, key: Key
    ) -> String {
        (container.codingPath + [key]).map(\.stringValue).joined(separator: ".")
    }
}
