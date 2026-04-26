import Foundation
@testable import SecretAgentMan
import Testing

struct JSONValueTests {
    @Test
    func integerJSONDecodesAsInt() throws {
        // Discriminator priority is load-bearing: integers must not collapse
        // into .double, or downstream `decode(as: Int.self)` fails silently.
        let value = try JSONDecoder().decode(JSONValue.self, from: Data("42".utf8))
        #expect(value == .int(42))
    }

    @Test
    func floatingPointJSONDecodesAsDouble() throws {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data("3.14".utf8))
        guard case let .double(d) = value else {
            Issue.record("expected .double, got \(value)")
            return
        }
        #expect(d == 3.14)
    }

    @Test
    func nullRoundTrips() throws {
        let decoded = try JSONDecoder().decode(JSONValue.self, from: Data("null".utf8))
        #expect(decoded == .null)
        let encoded = try JSONEncoder().encode(decoded)
        #expect(String(data: encoded, encoding: .utf8) == "null")
    }

    @Test
    func decodeAsRoundTripsObjectIntoTypedStruct() throws {
        struct Payload: Decodable, Equatable {
            let name: String
            let count: Int
        }
        let value = JSONValue.object([
            "name": .string("widget"),
            "count": .int(7),
        ])
        let payload = try value.decode(as: Payload.self)
        #expect(payload == Payload(name: "widget", count: 7))
    }

    @Test
    func nestedObjectIsEquatableAfterRoundTrip() throws {
        let original = JSONValue.object([
            "outer": .object([
                "list": .array([.int(1), .string("two"), .bool(true)]),
                "nullField": .null,
            ]),
        ])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
        #expect(decoded == original)
    }
}
