# LenientCodable

![Swift](https://img.shields.io/badge/Swift-6.2+-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2013+%20|%20macOS%2010.15+%20|%20tvOS%2013+%20|%20watchOS%206+-blue)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)
![License](https://img.shields.io/badge/License-MIT-green)

Swift macros for resilient `Codable` — one unknown enum case or malformed array element no longer fails your whole response. Lenient by default, strict by explicit opt-in, with compile-time diagnostics and fix-its.

```swift
import LenientCodable

@LenientDecodable
struct ApplicationResponse {
    @Strict var applicationId: String              // decode fails if this fails
    var status: Status?                 // lenient by default: nil on any failure
    @NilOnFailure var documents: [Document?]       // failed elements → nil in place
    @DropOnFailure var offers: [Offer]         // failed elements → removed
}

let response = try JSONDecoder().decode(LendingApplicationResponse.self, from: data)
```

- [The Problem](#the-problem)
- [Installation](#installation)
- [How It Works](#how-it-works)
- [What the Macro Writes](#what-the-macro-writes)
- [The Annotations](#the-annotations)
- [Compile-Time Enforcement](#compile-time-enforcement)
- [Debug Logging](#debug-logging)
- [Rules & Edge Cases](#rules--edge-cases)
- [When NOT to Use This](#when-not-to-use-this)
- [Related Work](#related-work)
- [Requirements](#requirements)

## The Problem

Swift's synthesized `Codable` decoding is all-or-nothing. One surprise anywhere in the payload — the backend adds an enum case your compiled app doesn't know, one element in a 20-element array is malformed, one nested field changes shape — and the **entire** response throws. The bug ships silently and detonates the day the API evolves, usually in the oldest app version still installed.

`LenientCodable` inverts the default: an annotated struct decodes *through* surprises, failures degrade into `nil` (or dropped elements) exactly where they happened, and every fallback is logged in debug builds so nothing degrades invisibly during development.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/EngOmarElsayed/swift-lenient-codable.git", from: "1.0.0"),
]
```

Then add `LenientCodable` to your target's dependencies and `import LenientCodable`. On first build, Xcode asks you to **Trust & Enable** the macro target — macros are compiler plugins, and this is the standard one-time ceremony.

## How It Works

`@LenientDecodable` generates `CodingKeys`, `init(from:)`, and the `Decodable` conformance for a struct. Every stored property without an annotation is implicitly `@NilOnFailure`, which requires the type to have a nil-shaped hole for the failure to land in:

| Declared type | Behavior on failure |
|---|---|
| `T?` | whole value → `nil` |
| `[T?]` | failed element → `nil` **in place**, count preserved |
| `[T?]?` | as `[T?]`; an absent or unusable array → `nil` instead of `[]` |
| `T`, `[T]`, `[T]?` | ❌ compile error with fix-its — change the type, or opt out with `@Strict` |

That last row is the design's core guarantee: **nothing is silently strict and nothing is silently lenient.** Every property's failure behavior is readable at its declaration — lenient by visible type shape, or explicit by visible annotation — and the compiler enforces that the accounting is complete.

## What the Macro Writes

No hidden runtime magic: right-click → *Expand Macro* shows exactly what was generated. For the struct at the top of this page:

```swift
struct ApplicationResponse {
    var applicationId: String
    var status: Status?
    var documents: [Document?]
    var offers: [Offer]

    private enum CodingKeys: String, CodingKey {
        case applicationId
        case status
        case documents
        case offers
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.applicationId = try container.decode(String.self, forKey: .applicationId)
        // implicit @NilOnFailure (applied by @LenientDecodable)
        self.status = LenientDecoding.nilOnFailure(ApplicationStatus.self, in: container, forKey: .status, decoder: decoder)
        self.documents = LenientDecoding.nilPadding(Document.self, in: container, forKey: .documents, decoder: decoder)
        self.offers = LenientDecoding.dropOnFailure(LoanOffer.self, in: container, forKey: .offers, decoder: decoder)
    }
}

extension ApplicationResponse: Decodable {}
```

Three things to notice: `@Strict` properties compile to plain `try container.decode` — the only lines that can throw; implicitly-lenient properties carry a provenance comment so expanded code shows *why* they're lenient; and the lenient helpers are ordinary public functions in the `LenientDecoding` module, callable from a hand-written `init(from:)` if you ever need to mix approaches manually.

## The Annotations

| Annotation | Applies to | On failure | Can fail the decode? |
|---|---|---|---|
| *(none)* / `@NilOnFailure` | `T?`, `[T?]`, `[T?]?` | `nil` exactly where it broke | never |
| `@DropOnFailure` | `[T]` | element removed, order kept | never |
| `@Strict` | any type | throws | **yes — the only way** |

### `@NilOnFailure` — nil where it broke

The default, written explicitly only as documentation. JSON `null` decodes silently as `nil` / `[]` — an explicit `null` is the backend saying "no value" on purpose. Anything else that goes wrong — a missing key, unknown enum raw value, type mismatch, malformed nested object — becomes `nil` at the exact position it occurred **and is reported in the debug log**.

On `[T?]`, count and positions are preserved, which makes incompleteness detectable in one line:

```swift
if documents.count != documents.compactMap({ $0 }).count {
    // something in the payload didn't parse — block submission, prompt an update
}
```

### `@DropOnFailure` — pretend it wasn't there

For `[T]` only. Failed elements (any reason, including `null`) are removed; survivors keep their order. The result is a clean non-optional array with zero `nil` handling at call sites — at the cost of erasing all in-value evidence that anything was dropped.

Dropping is a product decision, which is why it is **never applied by default**. Good fit: decorative lists — banners, tiles, recommendations. Poor fit: anything representing obligations or completeness (a required-documents checklist, a payment breakdown) — silently dropping an entry the user must act on misleads them. For those, prefer `@NilOnFailure` on `[T?]`.

### `@Strict` — synthesized behavior, on purpose

Byte-for-byte what plain `Codable` synthesis would do. Optionality covers *absence* only: a missing key or `null` decodes as `nil`, but a **present-and-broken value throws and fails the entire decode**. That absence-vs-failure distinction is the whole difference between `@Strict var x: [Int]?` and any lenient annotation.

In a `@LenientDecodable` struct, `@Strict` properties are the *only* way a decode can fail — `grep @Strict` audits every hard failure point, and the compiler guarantees the list is complete.

> ⚠️ On an enum property, synthesized decoding throws for an *unknown raw value* — meaning a new backend enum case will fail the decode. Use `@Strict` on enums from evolving APIs deliberately.

## Compile-Time Enforcement

The macro validates every property's type shape against its strategy and refuses to generate against an invalid spec. Errors arrive with fix-its enumerating your actual choices:

```swift
@LenientDecodable
struct Response {
    let count: Int
    // ❌ '@NilOnFailure' (applied by @LenientDecodable) requires an optional type
    //    fix-it: change 'Int' to 'Int?'
    //    fix-it: add '@Strict'

    let docs: [Doc]?
    // ❌ '@NilOnFailure' (applied by @LenientDecodable) on an array requires
    //    optional elements — elements that fail to decode become 'nil' in place
    //    fix-it: change '[Doc]?' to '[Doc?]?'
    //    fix-it: add '@Strict'
}
```

Also diagnosed: conflicting annotations on one property, `@DropOnFailure` on non-arrays / optional arrays / optional elements, longhand spellings (`Optional<T>`, `Array<T>` — use sugar syntax), stored properties without a written type (macros can't see inferred types), a hand-written `init(from:)`, duplicate application, and applying the macro to anything but a struct. A redundant `: Decodable` on the struct is a warning.

## Debug Logging

Leniency without observability would just be silent data loss. Every absorbed failure logs in DEBUG builds via `os.Logger` (subsystem `LenientCodable`, category `decoding`; `print` on platforms without `os`):

```
decoded nil for 'status' — dataCorrupted(...)
decoded nil for 'status' — key not found
padded nil at element 2 of 'documents' — typeMismatch(...)
dropped element 1 of 'offers' — keyNotFound(...)
```

Missing keys are reported (the backend omitting a field is worth knowing about); an explicit JSON `null` is the one silent case. Filter the firehose in Console.app or from the terminal:

```sh
log stream --predicate 'subsystem == "LenientCodable"' --level error
```

Release builds compile the logging out entirely — messages are never even constructed. Production degrades gracefully; development stays loud.

## Rules & Edge Cases

- **Structs only** (v1). Classes and enums are a compile error.
- **Skipped, never decoded:** `static` properties, computed properties, and `let` constants with an initializer — matching synthesis. Properties with `willSet`/`didSet` are stored and *are* decoded.
- **Your `CodingKeys` wins.** Declare your own enum (or typealias) named `CodingKeys` for custom key mappings and the macro references it instead of generating one.
- **Explicit types required.** `var x = 0` is an error: macros see syntax, not inferred types.
- **Sugar syntax required.** `T?` and `[T]`, not `Optional<T>` / `Array<T>`.
- **Nesting composes.** For element-level control *inside* an element type, make that type `@LenientDecodable` too and annotate its properties — leniency at the value level protects the element level.

## When NOT to Use This

Leniency is for **API evolution**, not for hiding bugs. If a field's absence should be impossible — an ID, an amount in a payments flow — mark it `@Strict` and let a broken payload fail loudly. A decode that always succeeds while quietly producing `nil` amounts is strictly worse than a crash you find in QA. The debug logging exists precisely to keep that failure mode visible while you develop.

## Related Work

- [ResilientDecoding](https://github.com/airbnb/ResilientDecoding) (Airbnb) — property-wrapper approach with a rich error-introspection system.
- [BetterCodable](https://github.com/marksands/BetterCodable) — a grab bag of `Codable` property wrappers including `@LossyArray`.

`LenientCodable` differs in being macro-based: no wrapper types in your stored properties (so `Equatable`/`Hashable`/memberwise-init synthesis are untouched), compile-time shape validation with fix-its, lenient-by-default semantics with enforced total accounting, and generated code you can read with *Expand Macro*.

## Requirements

- Swift 6.2+ toolchain (Xcode 26+)
- Platforms: iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, Mac Catalyst 13+

## License

MIT — see [LICENSE](LICENSE).
