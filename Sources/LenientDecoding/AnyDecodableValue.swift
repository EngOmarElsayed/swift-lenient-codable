//
//  AnyDecodableValue.swift
//  LenientCodable
//
//  Created by Omar Elsayed on 19/07/2026.
//

import Foundation

/// The cursor-advance device for the element loops in ``LenientDecoding``.
///
/// `UnkeyedDecodingContainer` has no "skip" API — the only way to move its
/// cursor past an element is to successfully decode *something* at that
/// position. After an element fails to decode as `T`, `nilPadding`,
/// `nilPaddingOptional`, and `dropOnFailure` decode the same element as
/// `AnyDecodableValue` to consume it and reach the next one:
///
/// ```swift
/// _ = try? unKeyedContainer.decode(AnyDecodableValue.self)
/// ```
///
/// The whole trick is the hand-written, empty `init(from:)`: it asks the
/// decoder for **nothing** — no container, no value — so it succeeds for
/// every element shape (object, array, scalar, `null`) while the container
/// still advances past exactly one element.
///
/// - Warning: Never delete the empty initializer. A compiler-synthesized
///   `init(from:)` for a property-less struct requests a *keyed* container,
///   which throws on scalar and `null` elements — the decode would fail, the
///   cursor would stay put, and the element loops would spin forever. The
///   loops' "cursor stuck" safeguard exists as defense-in-depth for exactly
///   this class of failure, and the "scalar garbage element" tests in
///   `LenientDecodingTests` pin the working behavior.
internal struct AnyDecodableValue: Decodable {
    init(from decoder: any Decoder) throws {}
}
