import LenientCodable

@LenientDecodable
struct Test {
    @Strict var omr: Int
    @Strict var om: Int
}
