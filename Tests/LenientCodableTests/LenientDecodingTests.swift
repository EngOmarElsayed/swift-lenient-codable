//
//  LenientDecodingTests.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 19/07/2026.
//

import Foundation
import Testing
@testable import LenientDecoding

@Suite("LenientDecoding Tests")
class LenientDecodingTests {
    // MARK: - nilOnFailure (whole-value, T?)
    @Suite("LenientDecoding.nilOnFailure")
    struct NilOnFailureTests {
        @Test("valid value decodes")
        func validValue() throws {
            let order = try decode(Order.self, #"{ "status": "shipped", "docs": [], "tags": [] }"#)
            #expect(order.status == .shipped)
        }

        @Test("unknown enum raw value → nil, decode survives")
        func unknownEnumCase() throws {
            let order = try decode(Order.self, #"{ "status": "refunded", "docs": [], "tags": [] }"#)
            #expect(order.status == nil)
        }

        @Test("type mismatch → nil, decode survives")
        func typeMismatch() throws {
            let order = try decode(Order.self, #"{ "status": 7, "docs": [], "tags": [] }"#)
            #expect(order.status == nil)
        }

        @Test("JSON null → nil")
        func nullValue() throws {
            let order = try decode(Order.self, #"{ "status": null, "docs": [], "tags": [] }"#)
            #expect(order.status == nil)
        }

        @Test("missing key → nil")
        func missingKey() throws {
            let order = try decode(Order.self, #"{ "docs": [], "tags": [] }"#)
            #expect(order.status == nil)
        }
    }

    // MARK: - nilPadding (element padding, [T?])
    @Suite("LenientDecoding.nilPadding")
    struct NilPaddingTests {
        @Test("all elements valid → full array, order preserved")
        func allValid() throws {
            let order = try decode(Order.self, #"{ "docs": [{ "type": "a" }, { "type": "b" }], "tags": [] }"#)
            #expect(order.docs == [Doc(type: "a"), Doc(type: "b")])
        }

        @Test("malformed element → nil IN PLACE, count preserved")
        func malformedElementIsPadded() throws {
            let order = try decode(Order.self, #"{ "docs": [{ "type": "a" }, { "wrong": 1 }, { "type": "c" }], "tags": [] }"#)
            #expect(order.docs == [Doc(type: "a"), nil, Doc(type: "c")])
            #expect(order.docs.count == 3)
        }

        @Test("null element → nil in place (intentional null, kept)")
        func nullElement() throws {
            let order = try decode(Order.self, #"{ "docs": [{ "type": "a" }, null, { "type": "c" }], "tags": [] }"#)
            #expect(order.docs == [Doc(type: "a"), nil, Doc(type: "c")])
        }

        @Test("scalar garbage element → nil in place — the cursor-advance case")
        func scalarElement() throws {
            // A synthesized (keyed-container) AnyDecodableValue would hang forever
            // on the scalar; this test finishing at all proves cursor advancement.
            let order = try decode(Order.self, #"{ "docs": [5, { "type": "b" }], "tags": [] }"#)
            #expect(order.docs == [nil, Doc(type: "b")])
        }

        @Test("the one-line evidence gate works")
        func evidenceGate() throws {
            let order = try decode(Order.self, #"{ "docs": [{ "type": "a" }, 5], "tags": [] }"#)
            #expect(order.docs.count != order.docs.compactMap { $0 }.count)
        }

        @Test("missing key → []")
        func missingKey() throws {
            let order = try decode(Order.self, #"{ "tags": [] }"#)
            #expect(order.docs == [])
        }

        @Test("JSON null → []")
        func nullArray() throws {
            let order = try decode(Order.self, #"{ "docs": null, "tags": [] }"#)
            #expect(order.docs == [])
        }

        @Test("wrong container shape → []")
        func wrongShape() throws {
            let order = try decode(Order.self, #"{ "docs": "hello", "tags": [] }"#)
            #expect(order.docs == [])
        }
    }

    // MARK: - nilPaddingOptional ([T?]?)
    @Suite("LenientDecoding.nilPaddingOptional")
    struct NilPaddingOptionalTests {

        @Test("present array pads like nilPadding")
        func presentArrayPads() throws {
            let shipment = try decode(Shipment.self, #"{ "docs": [{ "type": "a" }, 5] }"#)
            #expect(shipment.docs == [Doc(type: "a"), nil])
        }

        @Test("empty array → [], NOT nil — present and empty are different facts")
        func emptyArray() throws {
            let shipment = try decode(Shipment.self, #"{ "docs": [] }"#)
            #expect(shipment.docs == [])
            #expect(shipment.docs != nil)
        }

        @Test("missing key → nil, NOT []")
        func missingKey() throws {
            let shipment = try decode(Shipment.self, #"{ }"#)
            #expect(shipment.docs == nil)
        }

        @Test("JSON null → nil")
        func nullValue() throws {
            let shipment = try decode(Shipment.self, #"{ "docs": null }"#)
            #expect(shipment.docs == nil)
        }

        @Test("wrong container shape → nil")
        func wrongShape() throws {
            let shipment = try decode(Shipment.self, #"{ "docs": 42 }"#)
            #expect(shipment.docs == nil)
        }
    }

    // MARK: - dropOnFailure ([T])
    @Suite("LenientDecoding.dropOnFailure")
    struct DropOnFailureTests {

        @Test("all elements valid → full array, order preserved")
        func allValid() throws {
            let order = try decode(Order.self, #"{ "docs": [], "tags": [{ "type": "a" }, { "type": "b" }] }"#)
            #expect(order.tags == [Doc(type: "a"), Doc(type: "b")])
        }

        @Test("malformed element → dropped, survivors keep order")
        func malformedElementDropped() throws {
            let order = try decode(Order.self, #"{ "docs": [], "tags": [{ "type": "a" }, { "wrong": 1 }, { "type": "c" }] }"#)
            #expect(order.tags == [Doc(type: "a"), Doc(type: "c")])
        }

        @Test("null element → dropped (unlike nilPadding, null is not representable in [T])")
        func nullElementDropped() throws {
            let order = try decode(Order.self, #"{ "docs": [], "tags": [{ "type": "a" }, null, { "type": "c" }] }"#)
            #expect(order.tags == [Doc(type: "a"), Doc(type: "c")])
        }

        @Test("scalar garbage element → dropped — the cursor-advance case")
        func scalarElement() throws {
            let order = try decode(Order.self, #"{ "docs": [], "tags": [5, { "type": "b" }, "oops"] }"#)
            #expect(order.tags == [Doc(type: "b")])
        }

        @Test("every element broken → []")
        func allBroken() throws {
            let order = try decode(Order.self, #"{ "docs": [], "tags": [1, "x", null, {}] }"#)
            #expect(order.tags == [])
        }

        @Test("missing key → []")
        func missingKey() throws {
            let order = try decode(Order.self, #"{ "docs": [] }"#)
            #expect(order.tags == [])
        }

        @Test("JSON null → []")
        func nullArray() throws {
            let order = try decode(Order.self, #"{ "docs": [], "tags": null }"#)
            #expect(order.tags == [])
        }

        @Test("wrong container shape → []")
        func wrongShape() throws {
            let order = try decode(Order.self, #"{ "docs": [], "tags": { "a": 1 } }"#)
            #expect(order.tags == [])
        }
    }

    // MARK: - Non-throwing contract
    @Suite("LenientDecoding never fails the decode")
    struct NonThrowingContractTests {

        @Test("a payload broken at every lenient position still decodes")
        func totalGarbage() throws {
            let order = try decode(Order.self, #"{ "status": 999, "docs": "not an array", "tags": false }"#)
            #expect(order == Order(status: nil, docs: [], tags: []))
        }

        @Test("empty object decodes to all fallback values")
        func emptyObject() throws {
            let order = try decode(Order.self, "{}")
            #expect(order == Order(status: nil, docs: [], tags: []))
        }
    }
}

// MARK: - Helper types
private enum Status: String, Decodable, Equatable {
    case pending, shipped
}

private struct Doc: Decodable, Equatable {
    let type: String
}

/// Exercises `nilOnFailure` (T?), `nilPadding` ([T?]), and `dropOnFailure` ([T]).
private struct Order: Decodable, Equatable {
    let status: Status?
    let docs: [Doc?]
    let tags: [Doc]

    enum CodingKeys: String, CodingKey { case status, docs, tags }

    init(status: Status?, docs: [Doc?], tags: [Doc]) {
        self.status = status
        self.docs = docs
        self.tags = tags
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = LenientDecoding.nilOnFailure(Status.self, in: container, forKey: .status, decoder: decoder)
        docs = LenientDecoding.nilPadding(Doc.self, in: container, forKey: .docs, decoder: decoder)
        tags = LenientDecoding.dropOnFailure(Doc.self, in: container, forKey: .tags, decoder: decoder)
    }
}

/// Exercises `nilPaddingOptional` ([T?]?) separately, since its absent-vs-empty
/// behavior is the whole point of the outer optional.
private struct Shipment: Decodable, Equatable {
    let docs: [Doc?]?

    enum CodingKeys: String, CodingKey { case docs }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        docs = LenientDecoding.nilPaddingOptional(Doc.self, in: container, forKey: .docs, decoder: decoder)
    }
}

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}
