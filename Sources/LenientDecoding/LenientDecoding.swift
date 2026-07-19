//
//  LenientDecoding.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 19/07/2026.
//

import Foundation

public enum LenientDecoding {
    /// Whole-value leniency: any failure decodes as `nil`.
    ///
    /// - missing key → `nil`
    /// - JSON `null` → `nil`
    /// - decodes cleanly → the value
    /// - fails for ANY reason (unknown enum case, type mismatch, malformed
    ///   nested object, ...) → `nil`
    public static func nilOnFailure<T: Decodable, Key: CodingKey>(
        _ type: T.Type,
        in container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        decoder: any Decoder
    ) -> T? {
        do {
            return try container.decodeIfPresent(T.self, forKey: key)
        } catch {
            // Reporting hook: this catch is where the failure gets recorded.
            return nil
        }
    }

    /// @NilOnFailure on [T?]
    /// Element padding: failed elements become `nil` in place, count and
    /// positions preserved.
    ///
    /// - missing key → `[]`
    /// - JSON `null` → `[]`
    /// - value is not an array → `[]`
    /// - `null` element → `nil` at that position (intentional null, not an error)
    /// - malformed element → `nil` at that position
    public static func nilPadding<T: Decodable, Key: CodingKey>(
        _ type: T.Type,
        in container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        decoder: any Decoder
    ) -> [T?] {
        guard container.contains(key) else {
            // report that key isn't found
            return []
        }

        if (try? container.decodeNil(forKey: key)) == true {
            // report that the value was nil
            return []
        }

        guard var unKeyedContainer = try? container.nestedUnkeyedContainer(forKey: key) else {
            // Wrong container shape ("offers": "hello").
            // Reporting hook: containerFailed.
            return []
        }
        return decodeNilPaddedElements(T.self, from: &unKeyedContainer)
    }

    /// @NilOnFailure on [T?]?
    /// As `nilPadding`, but an absent or unusable array decodes as `nil`
    /// instead of `[]` — the outer optional in `[T?]?` answers exactly one
    /// question: what does "no array at all" decode to.
    public static func nilPaddingOptional<T: Decodable, Key: CodingKey>(
        _ type: T.Type,
        in container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        decoder: any Decoder
    ) -> [T?]? {
        guard container.contains(key) else {
            // report that key isn't found
            return nil
        }

        if (try? container.decodeNil(forKey: key)) == true {
            // report that the value was nil
            return nil
        }

        guard var unKeyedContainer = try? container.nestedUnkeyedContainer(forKey: key) else {
            // Reporting hook: containerFailed.
            return nil
        }
        return decodeNilPaddedElements(T.self, from: &unKeyedContainer)
    }

    /// @DropOnFailure on [T]
    /// Element dropping: failed elements are removed, survivors keep their
    /// original order.
    ///
    /// - missing key → `[]`
    /// - JSON `null` → `[]`
    /// - value is not an array → `[]`
    /// - failed element (any reason, including a `null` element) → removed
    public static func dropOnFailure<T: Decodable, Key: CodingKey>(
        _ type: T.Type,
        in container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        decoder: any Decoder
    ) -> [T] {
        guard container.contains(key) else { return [] }
        if (try? container.decodeNil(forKey: key)) == true { return [] }

        guard var unKeyedContainer = try? container.nestedUnkeyedContainer(forKey: key) else {
            // Reporting hook: containerFailed.
            return []
        }

        var result: [T] = []
        while !unKeyedContainer.isAtEnd {
            let index = unKeyedContainer.currentIndex
            do {
                result.append(try unKeyedContainer.decode(T.self))
            } catch {
                // Reporting hook: droppedElement(index:, underlying: error).
                _ = try? unKeyedContainer.decode(AnyDecodableValue.self)
                if unKeyedContainer.currentIndex == index { break }
            }
        }
        return result
    }

    // MARK: Shared element loop

    private static func decodeNilPaddedElements<T: Decodable>(
        _ type: T.Type,
        from unKeyedContainer: inout UnkeyedDecodingContainer
    ) -> [T?] {
        var result: [T?] = []
        while !unKeyedContainer.isAtEnd {
            let index = unKeyedContainer.currentIndex

            do {
                result.append(try unKeyedContainer.decode(T.self))
            } catch {
                // Reporting hook: nilPaddedElement(index:, underlying: error).
                _ = try? unKeyedContainer.decode(AnyDecodableValue.self)
                result.append(nil)
                if unKeyedContainer.currentIndex == index {
                    break // same safety valve as dropOnFailure
                }
            }
        }

        return result
    }
}
