//
//  LenientDecoding.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 19/07/2026.
//

import Foundation

/// The runtime engine behind the `@LenientDecodable` macro.
///
/// Every lenient property in a `@LenientDecodable` struct decodes through one
/// of the four static helpers on this type — the macro-generated
/// `init(from:)` contains one call per property, chosen from the property's
/// declared shape and annotation:
///
/// | Declared shape | Annotation | Helper |
/// |----------------|------------|--------|
/// | `T?` | `@NilOnFailure` (or implicit) | ``nilOnFailure(_:in:forKey:decoder:)`` |
/// | `[T?]` | `@NilOnFailure` (or implicit) | ``nilPadding(_:in:forKey:decoder:)`` |
/// | `[T?]?` | `@NilOnFailure` (or implicit) | ``nilPaddingOptional(_:in:forKey:decoder:)`` |
/// | `[T]` | `@DropOnFailure` | ``dropOnFailure(_:in:forKey:decoder:)`` |
///
/// - Note: `@Strict` properties bypass this type entirely — they decode with
///   the normal synthesized behavior (`decode` for non-optionals,
///   `decodeIfPresent` for optionals) and are the only calls in a generated
///   initializer that can throw.
///
/// ## Never throws, always reports
///
/// No helper here throws or returns an error. A failure is *absorbed* into
/// the return value — `nil`, `[]`, a `nil` element, or a dropped element —
/// and simultaneously *reported* through the internal `LenientErrorLogger`
/// (DEBUG builds only: unified logging under subsystem `LenientCodable`,
/// category `decoding`). A **missing key** is also reported — the backend
/// omitting a field entirely is worth surfacing. JSON `null` is the one
/// absorbed **silently**: an explicit `null` is the backend saying "no
/// value" on purpose.
///
/// ## Direct use
///
/// The helpers are plain functions over a `KeyedDecodingContainer`, so a
/// hand-written `init(from:)` can call them directly next to strict
/// `decode` calls:
///
/// ```swift
/// init(from decoder: any Decoder) throws {
///     let container = try decoder.container(keyedBy: CodingKeys.self)
///     self.id = try container.decode(Int.self, forKey: .id)
///     self.status = LenientDecoding.nilOnFailure(Status.self, in: container, forKey: .status, decoder: decoder)
/// }
/// ```
///
/// ## Topics
///
/// ### Whole-value leniency
/// - ``nilOnFailure(_:in:forKey:decoder:)``
///
/// ### Element-level leniency
/// - ``nilPadding(_:in:forKey:decoder:)``
/// - ``nilPaddingOptional(_:in:forKey:decoder:)``
/// - ``dropOnFailure(_:in:forKey:decoder:)``
public enum LenientDecoding {
    /// Whole-value leniency: any failure decodes as `nil`.
    ///
    /// Backs `@NilOnFailure` (explicit or implicit) on a `T?` property.
    ///
    /// | Input | Result | Reported |
    /// |-------|--------|----------|
    /// | value decodes cleanly | the value | — |
    /// | missing key | `nil` | yes ("key not found") |
    /// | JSON `null` | `nil` | no (intentional null) |
    /// | any failure — unknown enum case, type mismatch, malformed nested object, … | `nil` | yes |
    ///
    /// - Note: A `nil` result therefore never distinguishes "the backend sent
    ///   nothing" from "the backend sent something broken" — that distinction
    ///   lives only in the error report.
    ///
    /// - Parameters:
    ///   - type: The wrapped type `T` to decode.
    ///   - container: The keyed container to read from.
    ///   - key: The key to decode.
    ///   - decoder: The decoder for the value being initialized. Accepted for
    ///     call-site uniformity of macro-generated code; currently unused.
    /// - Returns: The decoded value, or `nil` when the key is absent, `null`,
    ///   or fails to decode for any reason.
    public static func nilOnFailure<T: Decodable, Key: CodingKey>(
        _ type: T.Type,
        in container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        decoder: any Decoder
    ) -> T? {
        guard container.contains(key) else {
            LenientErrorLogger.log("decoded nil for '\(LenientErrorLogger.path(of: container, key: key))' — key not found")
            return nil
        }

        do {
            return try container.decodeIfPresent(T.self, forKey: key)
        } catch {
            LenientErrorLogger.log("decoded nil for '\(LenientErrorLogger.path(of: container, key: key))' — \(error)")
            return nil
        }
    }

    /// Element padding: failed elements become `nil` in place, count and
    /// positions preserved.
    ///
    /// Backs `@NilOnFailure` (explicit or implicit) on a `[T?]` property.
    ///
    /// | Input | Result | Reported |
    /// |-------|--------|----------|
    /// | all elements decode | full array, original order | — |
    /// | missing key | `[]` | yes ("key not found") |
    /// | JSON `null` | `[]` | no (intentional null) |
    /// | value is not an array | `[]` | yes |
    /// | `null` element | `nil` at that position | no (intentional null) |
    /// | malformed element | `nil` at that position | yes, with its index |
    ///
    /// Because count and positions survive, one line answers "did anything
    /// fail?" at the call site:
    ///
    /// ```swift
    /// let hadFailures = docs.count != docs.compactMap { $0 }.count
    /// ```
    ///
    /// Failed elements are skipped by decoding them as an opaque value to
    /// advance the container's cursor. If the cursor ever fails to advance,
    /// the loop stops rather than spin forever — the elements decoded so far
    /// are returned and the truncation is reported.
    ///
    /// - Parameters:
    ///   - type: The element type `T` to decode.
    ///   - container: The keyed container to read from.
    ///   - key: The key holding the array.
    ///   - decoder: The decoder for the value being initialized. Accepted for
    ///     call-site uniformity of macro-generated code; currently unused.
    /// - Returns: The decoded elements with `nil` in every failed position,
    ///   or `[]` when there is no usable array at `key`.
    public static func nilPadding<T: Decodable, Key: CodingKey>(
        _ type: T.Type,
        in container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        decoder: any Decoder
    ) -> [T?] {
        guard container.contains(key) else {
            LenientErrorLogger.log("decoded [] for '\(LenientErrorLogger.path(of: container, key: key))' — key not found")
            return []
        }

        if (try? container.decodeNil(forKey: key)) == true { return [] }

        guard var unKeyedContainer = try? container.nestedUnkeyedContainer(forKey: key) else {
            LenientErrorLogger.log("decoded [] for '\(LenientErrorLogger.path(of: container, key: key))' — value is not an array")
            return []
        }
        return decodeNilPaddedElements(T.self, from: &unKeyedContainer, path: LenientErrorLogger.path(of: container, key: key))
    }

    /// As ``nilPadding(_:in:forKey:decoder:)``, but an absent or unusable
    /// array decodes as `nil` instead of `[]`.
    ///
    /// Backs `@NilOnFailure` (explicit or implicit) on a `[T?]?` property.
    /// The outer optional in `[T?]?` answers exactly one question: what does
    /// "no array at all" decode to.
    ///
    /// | Input | Result | Reported |
    /// |-------|--------|----------|
    /// | missing key | `nil` | yes ("key not found") |
    /// | JSON `null` | `nil` | no (intentional null) |
    /// | value is not an array | `nil` | yes |
    /// | an actual array | element-padded exactly as ``nilPadding(_:in:forKey:decoder:)`` | per element |
    ///
    /// Use this shape when "the list was omitted" and "the list is empty"
    /// mean different things to the caller.
    ///
    /// - Parameters:
    ///   - type: The element type `T` to decode.
    ///   - container: The keyed container to read from.
    ///   - key: The key holding the array.
    ///   - decoder: The decoder for the value being initialized. Accepted for
    ///     call-site uniformity of macro-generated code; currently unused.
    /// - Returns: The decoded elements with `nil` in every failed position,
    ///   or `nil` when there is no usable array at `key`.
    public static func nilPaddingOptional<T: Decodable, Key: CodingKey>(
        _ type: T.Type,
        in container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        decoder: any Decoder
    ) -> [T?]? {
        guard container.contains(key) else {
            LenientErrorLogger.log("decoded nil for '\(LenientErrorLogger.path(of: container, key: key))' — key not found")
            return nil
        }

        if (try? container.decodeNil(forKey: key)) == true { return nil }

        guard var unKeyedContainer = try? container.nestedUnkeyedContainer(forKey: key) else {
            LenientErrorLogger.log("decoded [] for '\(LenientErrorLogger.path(of: container, key: key))' — value is not an array")
            return nil
        }
        return decodeNilPaddedElements(T.self, from: &unKeyedContainer, path: LenientErrorLogger.path(of: container, key: key))
    }

    /// Element dropping: failed elements are removed, survivors keep their
    /// original order.
    ///
    /// Backs `@DropOnFailure` on a `[T]` property.
    ///
    /// | Input | Result | Reported |
    /// |-------|--------|----------|
    /// | all elements decode | full array, original order | — |
    /// | missing key | `[]` | yes ("key not found") |
    /// | JSON `null` | `[]` | no (intentional null) |
    /// | value is not an array | `[]` | yes |
    /// | failed element — any reason, including a `null` element | removed | yes, with its index |
    ///
    /// The result is a clean non-optional `[T]` with zero `nil` handling at
    /// call sites — at the cost of erasing all in-value evidence that
    /// elements were dropped. Unlike ``nilPadding(_:in:forKey:decoder:)``,
    /// the returned count tells you nothing; the evidence lives only in the
    /// error report. Prefer nil padding for lists that represent obligations
    /// or completeness.
    ///
    /// Failed elements are skipped by decoding them as an opaque value to
    /// advance the container's cursor. If the cursor ever fails to advance,
    /// the loop stops rather than spin forever — the elements decoded so far
    /// are returned and the truncation is reported.
    ///
    /// - Parameters:
    ///   - type: The element type `T` to decode.
    ///   - container: The keyed container to read from.
    ///   - key: The key holding the array.
    ///   - decoder: The decoder for the value being initialized. Accepted for
    ///     call-site uniformity of macro-generated code; currently unused.
    /// - Returns: The elements that decoded cleanly, in their original order,
    ///   or `[]` when there is no usable array at `key`.
    public static func dropOnFailure<T: Decodable, Key: CodingKey>(
        _ type: T.Type,
        in container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        decoder: any Decoder
    ) -> [T] {
        let path = LenientErrorLogger.path(of: container, key: key)
        guard container.contains(key) else {
            LenientErrorLogger.log("decoded [] for '\(path)' — key not found")
            return []
        }
        if (try? container.decodeNil(forKey: key)) == true { return [] }
        guard var unKeyedContainer = try? container.nestedUnkeyedContainer(forKey: key) else {
            LenientErrorLogger.log("decoded [] for '\(path)' — value is not an array")
            return []
        }

        var result: [T] = []
        while !unKeyedContainer.isAtEnd {
            let index = unKeyedContainer.currentIndex
            do {
                result.append(try unKeyedContainer.decode(T.self))
            } catch {
                LenientErrorLogger.log("dropped element \(index) of '\(path)' — \(error)")
                _ = try? unKeyedContainer.decode(AnyDecodableValue.self)
                if unKeyedContainer.currentIndex == index {
                    LenientErrorLogger.log("cursor stuck at element \(index) of '\(path)' — remaining elements dropped")
                    break
                }
            }
        }
        return result
    }

    // MARK: Shared element loop
    private static func decodeNilPaddedElements<T: Decodable>(
        _ type: T.Type,
        from unKeyedContainer: inout UnkeyedDecodingContainer,
        path: String
    ) -> [T?] {
        var result: [T?] = []
        while !unKeyedContainer.isAtEnd {
            let index = unKeyedContainer.currentIndex

            do {
                result.append(try unKeyedContainer.decode(T.self))
            } catch {
                LenientErrorLogger.log("padded nil at element \(index) of '\(path)' — \(error)")
                _ = try? unKeyedContainer.decode(AnyDecodableValue.self)
                result.append(nil)
                if unKeyedContainer.currentIndex == index {
                    LenientErrorLogger.log("cursor stuck at element \(index) of '\(path)' — remaining elements dropped")
                    break
                }
            }
        }

        return result
    }
}
