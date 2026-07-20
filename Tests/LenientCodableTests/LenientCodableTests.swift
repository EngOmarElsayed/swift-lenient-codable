//
//  LenientCodableTests.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 19/07/2026.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(LenientCodableMacros)
import LenientCodableMacros

let testMacros: [String: Macro.Type] = [
    "LenientDecodable": LenientDecodableMacro.self,
    "NilOnFailure": MarkerMacro.self,
    "DropOnFailure": MarkerMacro.self,
    "Strict": MarkerMacro.self,
]
#endif

final class LenientDecodableExpansionTests: XCTestCase {
    override func invokeTest() {
        #if canImport(LenientCodableMacros)
        super.invokeTest()
        #endif
    }

    // MARK: Implicit @NilOnFailure
    func testOptionalPropertyGetsImplicitNilOnFailureWithProvenanceComment() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                var status: String?
            }
            """,
            expandedSource: """
            struct Order {
                var status: String?

                private enum CodingKeys: String, CodingKey {
                    case status
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        // implicit @NilOnFailure (applied by @LenientDecodable)
                        self.status = LenientDecoding.nilOnFailure(String.self, in: container, forKey: .status, decoder: decoder)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testExplicitNilOnFailureOmitsProvenanceComment() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @NilOnFailure var status: String?
            }
            """,
            expandedSource: """
            struct Order {
                var status: String?

                private enum CodingKeys: String, CodingKey {
                    case status
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        self.status = LenientDecoding.nilOnFailure(String.self, in: container, forKey: .status, decoder: decoder)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testArrayOfOptionalsUsesNilPadding() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                var docs: [Doc?]
            }
            """,
            expandedSource: """
            struct Order {
                var docs: [Doc?]

                private enum CodingKeys: String, CodingKey {
                    case docs
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        // implicit @NilOnFailure (applied by @LenientDecodable)
                        self.docs = LenientDecoding.nilPadding(Doc.self, in: container, forKey: .docs, decoder: decoder)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testOptionalArrayOfOptionalsUsesNilPaddingOptional() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                var docs: [Doc?]?
            }
            """,
            expandedSource: """
            struct Order {
                var docs: [Doc?]?

                private enum CodingKeys: String, CodingKey {
                    case docs
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        // implicit @NilOnFailure (applied by @LenientDecodable)
                        self.docs = LenientDecoding.nilPaddingOptional(Doc.self, in: container, forKey: .docs, decoder: decoder)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    // MARK: @DropOnFailure

    func testDropOnFailureOnPlainArray() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @DropOnFailure var tags: [String]
            }
            """,
            expandedSource: """
            struct Order {
                var tags: [String]

                private enum CodingKeys: String, CodingKey {
                    case tags
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        self.tags = LenientDecoding.dropOnFailure(String.self, in: container, forKey: .tags, decoder: decoder)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    // MARK: @Strict

    func testStrictOnPlainTypeUsesDecode() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @Strict var id: Int
            }
            """,
            expandedSource: """
            struct Order {
                var id: Int

                private enum CodingKeys: String, CodingKey {
                    case id
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        self.id = try container.decode(Int.self, forKey: .id)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testStrictOnOptionalUsesDecodeIfPresent() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @Strict var note: String?
            }
            """,
            expandedSource: """
            struct Order {
                var note: String?

                private enum CodingKeys: String, CodingKey {
                    case note
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        self.note = try container.decodeIfPresent(String.self, forKey: .note)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testStrictOnPlainArrayUsesDecode() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @Strict var tags: [String]
            }
            """,
            expandedSource: """
            struct Order {
                var tags: [String]

                private enum CodingKeys: String, CodingKey {
                    case tags
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        self.tags = try container.decode([String].self, forKey: .tags)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testStrictOnOptionalArrayUsesDecodeIfPresentOfArray() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @Strict var tags: [String]?
            }
            """,
            expandedSource: """
            struct Order {
                var tags: [String]?

                private enum CodingKeys: String, CodingKey {
                    case tags
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testStrictOnOptionalArrayOfOptionalsUsesDecodeIfPresentOfArrayOfOptionals() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @Strict var tags: [String?]?
            }
            """,
            expandedSource: """
            struct Order {
                var tags: [String?]?

                private enum CodingKeys: String, CodingKey {
                    case tags
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        self.tags = try container.decodeIfPresent([String?].self, forKey: .tags)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    // MARK: Mixed strategies

    func testMixedStrategiesGenerateOneLinePerPropertyInDeclarationOrder() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @Strict var id: Int
                var status: Status?
                @DropOnFailure var tags: [String]
            }
            """,
            expandedSource: """
            struct Order {
                var id: Int
                var status: Status?
                var tags: [String]

                private enum CodingKeys: String, CodingKey {
                    case id
                    case status
                    case tags
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        self.id = try container.decode(Int.self, forKey: .id)
                        // implicit @NilOnFailure (applied by @LenientDecodable)
                        self.status = LenientDecoding.nilOnFailure(Status.self, in: container, forKey: .status, decoder: decoder)
                        self.tags = LenientDecoding.dropOnFailure(String.self, in: container, forKey: .tags, decoder: decoder)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    // MARK: CodingKeys handling

    func testExistingCodingKeysEnumIsNotRegenerated() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                var status: String?

                private enum CodingKeys: String, CodingKey {
                    case status = "order_status"
                }
            }
            """,
            expandedSource: """
            struct Order {
                var status: String?

                private enum CodingKeys: String, CodingKey {
                    case status = "order_status"
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        // implicit @NilOnFailure (applied by @LenientDecodable)
                        self.status = LenientDecoding.nilOnFailure(String.self, in: container, forKey: .status, decoder: decoder)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testExistingCodingKeysTypealiasIsNotRegenerated() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                typealias CodingKeys = SharedKeys
                var status: String?
            }
            """,
            expandedSource: """
            struct Order {
                typealias CodingKeys = SharedKeys
                var status: String?

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        // implicit @NilOnFailure (applied by @LenientDecodable)
                        self.status = LenientDecoding.nilOnFailure(String.self, in: container, forKey: .status, decoder: decoder)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    // MARK: Access control

    func testPublicStructGetsPublicInit() {
        assertMacroExpansion(
            """
            @LenientDecodable
            public struct Order {
                public var status: String?
            }
            """,
            expandedSource: """
            public struct Order {
                public var status: String?

                private enum CodingKeys: String, CodingKey {
                    case status
                }

                public init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        // implicit @NilOnFailure (applied by @LenientDecodable)
                        self.status = LenientDecoding.nilOnFailure(String.self, in: container, forKey: .status, decoder: decoder)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    // MARK: Skipped members

    func testStaticComputedAndInitializedLetPropertiesAreSkipped() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                static var shared: Order?
                let kind: String = "order"
                var isEmpty: Bool { true }
                var status: String?
            }
            """,
            expandedSource: """
            struct Order {
                static var shared: Order?
                let kind: String = "order"
                var isEmpty: Bool { true }
                var status: String?

                private enum CodingKeys: String, CodingKey {
                    case status
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        // implicit @NilOnFailure (applied by @LenientDecodable)
                        self.status = LenientDecoding.nilOnFailure(String.self, in: container, forKey: .status, decoder: decoder)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testLetWithoutInitializerIsDecoded() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                let status: String?
            }
            """,
            expandedSource: """
            struct Order {
                let status: String?

                private enum CodingKeys: String, CodingKey {
                    case status
                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        // implicit @NilOnFailure (applied by @LenientDecodable)
                        self.status = LenientDecoding.nilOnFailure(String.self, in: container, forKey: .status, decoder: decoder)
                }
            }

            extension Order: Decodable {
            }
            """,
            macros: testMacros
        )
    }
}

// MARK: - Diagnostics

final class LenientDecodableDiagnosticTests: XCTestCase {
    override func invokeTest() {
        #if canImport(LenientCodableMacros)
        super.invokeTest()
        #endif
    }

    // MARK: Type-level

    func testAppliedToClassEmitsStructsOnlyError() {
        assertMacroExpansion(
            """
            @LenientDecodable
            class Order {
                var status: String?
            }
            """,
            expandedSource: """
            class Order {
                var status: String?
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@LenientDecodable' can only be applied to a struct",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
    }

    func testAppliedToEnumEmitsStructsOnlyError() {
        assertMacroExpansion(
            """
            @LenientDecodable
            enum Status {
                case shipped
            }
            """,
            expandedSource: """
            enum Status {
                case shipped
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@LenientDecodable' can only be applied to a struct",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
    }

    func testHandWrittenInitFromDecoderIsRejected() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                var status: String?

                init(from decoder: any Decoder) throws {
                    self.status = nil
                }
            }
            """,
            expandedSource: """
            struct Order {
                var status: String?

                init(from decoder: any Decoder) throws {
                    self.status = nil
                }

                private enum CodingKeys: String, CodingKey {

                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                }
            }

            extension Order: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@LenientDecodable' cannot be applied to a type that declares its own 'init(from:)'",
                    line: 5,
                    column: 5
                )
            ],
            macros: testMacros
        )
    }

    func testMissingTypeAnnotationEmitsErrorWithFixIt() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                var count = 0
            }
            """,
            expandedSource: """
            struct Order {
                var count = 0

                private enum CodingKeys: String, CodingKey {

                }

                init(from decoder: any Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                }
            }

            extension Order: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@LenientDecodable' requires an explicit type annotation on stored properties",
                    line: 3,
                    column: 9,
                    fixIts: [FixItSpec(message: "add an explicit type annotation")]
                )
            ],
            macros: testMacros
        )
    }

    // MARK: Property-level: multiple annotations

    func testMultipleAnnotationsOnOnePropertyIsRejected() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @NilOnFailure @Strict
                var status: String?
            }
            """,
            expandedSource: """
            struct Order {

                var status: String?
            }

            extension Order: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "property has multiple leniency annotations ('@NilOnFailure', '@Strict'); choose one",
                    line: 3,
                    column: 19
                )
            ],
            macros: testMacros
        )
    }

    // MARK: Property-level: implicit @NilOnFailure shape errors

    func testImplicitNilOnFailureOnPlainTypeRequiresOptional() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                var id: Int
            }
            """,
            expandedSource: """
            struct Order {
                var id: Int
            }

            extension Order: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@NilOnFailure' (applied by @LenientDecodable) requires an optional type",
                    line: 3,
                    column: 13,
                    fixIts: [
                        FixItSpec(message: "change 'Int' to 'Int?'"),
                        FixItSpec(message: "add '@Strict'"),
                    ]
                )
            ],
            macros: testMacros
        )
    }

    func testExplicitNilOnFailureOnPlainTypeAnchorsAtAnnotation() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @NilOnFailure var id: Int
            }
            """,
            expandedSource: """
            struct Order {
                var id: Int
            }

            extension Order: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@NilOnFailure' requires an optional type",
                    line: 3,
                    column: 5,
                    fixIts: [
                        FixItSpec(message: "change 'Int' to 'Int?'"),
                        FixItSpec(message: "replace with '@Strict'"),
                    ]
                )
            ],
            macros: testMacros
        )
    }

    func testImplicitNilOnFailureOnArrayRequiresOptionalElements() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                var tags: [String]
            }
            """,
            expandedSource: """
            struct Order {
                var tags: [String]
            }

            extension Order: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@NilOnFailure' (applied by @LenientDecodable) on an array requires optional elements — elements that fail to decode become 'nil' in place",
                    line: 3,
                    column: 15,
                    fixIts: [
                        FixItSpec(message: "change '[String]' to '[String?]'"),
                        FixItSpec(message: "add '@DropOnFailure'"),
                        FixItSpec(message: "add '@Strict'"),
                    ]
                )
            ],
            macros: testMacros
        )
    }

    func testImplicitNilOnFailureOnOptionalArrayRequiresOptionalElements() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                var tags: [String]?
            }
            """,
            expandedSource: """
            struct Order {
                var tags: [String]?
            }

            extension Order: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@NilOnFailure' (applied by @LenientDecodable) on an array requires optional elements — elements that fail to decode become 'nil' in place",
                    line: 3,
                    column: 15,
                    fixIts: [
                        FixItSpec(message: "change '[String]?' to '[String?]?'"),
                        FixItSpec(message: "add '@Strict'"),
                    ]
                )
            ],
            macros: testMacros
        )
    }

    // MARK: Property-level: @DropOnFailure shape errors

    func testDropOnFailureOnNonArrayIsRejected() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @DropOnFailure var status: String?
            }
            """,
            expandedSource: """
            struct Order {
                var status: String?
            }

            extension Order: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@DropOnFailure' can only be applied to an array property",
                    line: 3,
                    column: 5,
                    fixIts: [FixItSpec(message: "replace with '@Strict'")]
                )
            ],
            macros: testMacros
        )
    }

    func testDropOnFailureOnOptionalArrayIsRejected() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @DropOnFailure var tags: [String]?
            }
            """,
            expandedSource: """
            struct Order {
                var tags: [String]?
            }

            extension Order: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@DropOnFailure' requires a non-optional array — a missing or null key already decodes as '[]'",
                    line: 3,
                    column: 5,
                    fixIts: [
                        FixItSpec(message: "change '[String]?' to '[String]'"),
                        FixItSpec(message: "replace with '@Strict'"),
                    ]
                )
            ],
            macros: testMacros
        )
    }

    func testDropOnFailureOnArrayOfOptionalsIsRejected() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @DropOnFailure var tags: [String?]
            }
            """,
            expandedSource: """
            struct Order {
                var tags: [String?]
            }

            extension Order: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@DropOnFailure' requires non-optional elements — use '@NilOnFailure' to keep null placeholders",
                    line: 3,
                    column: 5,
                    fixIts: [
                        FixItSpec(message: "change '[String?]' to '[String]'"),
                        FixItSpec(message: "replace with '@NilOnFailure'"),
                    ]
                )
            ],
            macros: testMacros
        )
    }

    // MARK: Longhand syntax

    func testLonghandOptionalIsRejected() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                var status: Optional<String>
            }
            """,
            expandedSource: """
            struct Order {
                var status: Optional<String>
            }

            extension Order: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "LenientCodable requires sugar syntax ('T?', '[T]') to determine leniency shape",
                    line: 3,
                    column: 17
                )
            ],
            macros: testMacros
        )
    }

    func testLonghandArrayIsRejected() {
        assertMacroExpansion(
            """
            @LenientDecodable
            struct Order {
                @Strict var tags: Array<String>
            }
            """,
            expandedSource: """
            struct Order {
                var tags: Array<String>
            }

            extension Order: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "LenientCodable requires sugar syntax ('T?', '[T]') to determine leniency shape",
                    line: 3,
                    column: 23
                )
            ],
            macros: testMacros
        )
    }
}
