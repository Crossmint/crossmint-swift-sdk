import Foundation
import Testing
@testable import CrossmintService

struct DefaultJSONCoderTest {

    private struct TestModel: Codable {
        let name: String
        let value: Int
    }

    private struct TestModelWithDate: Codable {
        let name: String
        let createdAt: Date
    }

    private struct TestModelWithOptionalDate: Codable {
        let name: String
        let createdAt: Date?
    }

    private struct TestModelWithMultipleDates: Codable {
        let name: String
        let createdAt: Date
        let updatedAt: Date
        let expiredAt: Date?
    }

    @Test("Encodes basic model successfully")
    func encodesBasicModelSuccessfully() throws {
        let coder = DefaultJSONCoder()
        let model = TestModel(name: "test", value: 42)

        let data = try coder.encode(model)

        #expect(data.count > 0)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["name"] as? String == "test")
        #expect(json?["value"] as? Int == 42)
    }

    @Test("Decodes basic model successfully")
    func decodesBasicModelSuccessfully() throws {
        let coder = DefaultJSONCoder()
        let jsonString = """
        {"name": "decoded", "value": 123}
        """
        let data = Data(jsonString.utf8)

        let model: TestModel = try coder.decode(TestModel.self, from: data)

        #expect(model.name == "decoded")
        #expect(model.value == 123)
    }

    @Test("Handles ISO8601 date with fractional seconds")
    func handlesISO8601DateWithFractionalSeconds() throws {
        let coder = DefaultJSONCoder()
        let jsonString = """
        {"name": "dateTest", "createdAt": "2023-12-25T10:30:45.123Z"}
        """
        let data = Data(jsonString.utf8)

        let model: TestModelWithDate = try coder.decode(TestModelWithDate.self, from: data)

        #expect(model.name == "dateTest")

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: model.createdAt)
        #expect(components.year == 2023)
        #expect(components.month == 12)
        #expect(components.day == 25)
        #expect(components.hour == 10)
        #expect(components.minute == 30)
        #expect(components.second == 45)
    }

    @Test("Handles ISO8601 date without fractional seconds")
    func handlesISO8601DateWithoutFractionalSeconds() throws {
        let coder = DefaultJSONCoder()
        let jsonString = """
        {"name": "dateTest", "createdAt": "2023-12-25T10:30:45Z"}
        """
        let data = Data(jsonString.utf8)

        let model: TestModelWithDate = try coder.decode(TestModelWithDate.self, from: data)

        #expect(model.name == "dateTest")

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: model.createdAt)
        #expect(components.year == 2023)
        #expect(components.month == 12)
        #expect(components.day == 25)
        #expect(components.hour == 10)
        #expect(components.minute == 30)
        #expect(components.second == 45)
    }

    @Test("Handles ISO8601 date with timezone offset")
    func handlesISO8601DateWithTimezoneOffset() throws {
        let coder = DefaultJSONCoder()
        let jsonString = """
        {"name": "dateTest", "createdAt": "2023-12-25T10:30:45+02:00"}
        """
        let data = Data(jsonString.utf8)

        let model: TestModelWithDate = try coder.decode(TestModelWithDate.self, from: data)

        #expect(model.name == "dateTest")
        #expect(model.createdAt.timeIntervalSince1970 > 0)
    }

    @Test("Handles ISO8601 date with milliseconds precision")
    func handlesISO8601DateWithMillisecondsPrecision() throws {
        let coder = DefaultJSONCoder()
        let jsonString = """
        {"name": "dateTest", "createdAt": "2023-12-25T10:30:45.456789Z"}
        """
        let data = Data(jsonString.utf8)

        let model: TestModelWithDate = try coder.decode(TestModelWithDate.self, from: data)

        #expect(model.name == "dateTest")

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: model.createdAt)
        #expect(components.year == 2023)
        #expect(components.month == 12)
        #expect(components.day == 25)
    }

    @Test("Handles multiple dates in same model")
    func handlesMultipleDatesInSameModel() throws {
        let coder = DefaultJSONCoder()
        let jsonString = """
        {
            "name": "multipleDates",
            "createdAt": "2023-12-25T10:30:45.123Z",
            "updatedAt": "2023-12-26T15:45:30Z",
            "expiredAt": "2024-01-01T00:00:00.000Z"
        }
        """
        let data = Data(jsonString.utf8)

        let model: TestModelWithMultipleDates = try coder.decode(TestModelWithMultipleDates.self, from: data)

        #expect(model.name == "multipleDates")
        #expect(model.expiredAt != nil)

        let createdComponents = calendar.dateComponents([.year, .month, .day], from: model.createdAt)
        let updatedComponents = calendar.dateComponents([.year, .month, .day], from: model.updatedAt)

        #expect(createdComponents.year == 2023)
        #expect(createdComponents.month == 12)
        #expect(createdComponents.day == 25)

        #expect(updatedComponents.year == 2023)
        #expect(updatedComponents.month == 12)
        #expect(updatedComponents.day == 26)
    }

    @Test("Handles optional date when null")
    func handlesOptionalDateWhenNull() throws {
        let coder = DefaultJSONCoder()
        let jsonString = """
        {"name": "nullDate", "createdAt": null}
        """
        let data = Data(jsonString.utf8)

        let model: TestModelWithOptionalDate = try coder.decode(TestModelWithOptionalDate.self, from: data)

        #expect(model.name == "nullDate")
        #expect(model.createdAt == nil)
    }

    @Test("Handles optional date when present")
    func handlesOptionalDateWhenPresent() throws {
        let coder = DefaultJSONCoder()
        let jsonString = """
        {"name": "presentDate", "createdAt": "2023-12-25T10:30:45Z"}
        """
        let data = Data(jsonString.utf8)

        let model: TestModelWithOptionalDate = try coder.decode(TestModelWithOptionalDate.self, from: data)

        #expect(model.name == "presentDate")
        #expect(model.createdAt != nil)
    }

    @Test("Throws error for invalid date format")
    func throwsErrorForInvalidDateFormat() {
        let coder = DefaultJSONCoder()
        let jsonString = """
        {"name": "invalidDate", "createdAt": "2023-25-12 10:30:45"}
        """
        let data = Data(jsonString.utf8)

        #expect(throws: CrossmintServiceError.self) {
            try coder.decode(TestModelWithDate.self, from: data)
        }
    }

    @Test("Throws error for non-ISO8601 date format")
    func throwsErrorForNonISO8601DateFormat() {
        let coder = DefaultJSONCoder()
        let jsonString = """
        {"name": "wrongFormat", "createdAt": "Dec 25, 2023 10:30 AM"}
        """
        let data = Data(jsonString.utf8)

        #expect(throws: CrossmintServiceError.self) {
            try coder.decode(TestModelWithDate.self, from: data)
        }
    }

    @Test("Throws error for invalid JSON structure")
    func throwsErrorForInvalidJSONStructure() {
        let coder = DefaultJSONCoder()
        let invalidJSON = "{ invalid json }"
        let data = Data(invalidJSON.utf8)

        #expect(throws: CrossmintServiceError.self) {
            try coder.decode(TestModel.self, from: data)
        }
    }

    @Test("Throws error for missing required field")
    func throwsErrorForMissingRequiredField() {
        let coder = DefaultJSONCoder()
        let jsonString = """
        {"name": "missingValue"}
        """
        let data = Data(jsonString.utf8)

        #expect(throws: CrossmintServiceError.self) {
            try coder.decode(TestModel.self, from: data)
        }
    }

    @Test("Throws error for type mismatch")
    func throwsErrorForTypeMismatch() {
        let coder = DefaultJSONCoder()
        let jsonString = """
        {"name": "typeMismatch", "value": "not_a_number"}
        """
        let data = Data(jsonString.utf8)

        #expect(throws: CrossmintServiceError.self) {
            try coder.decode(TestModel.self, from: data)
        }
    }

    @Test("Handles empty data during decoding")
    func handlesEmptyDataDuringDecoding() {
        let coder = DefaultJSONCoder()
        let emptyData = Data()

        #expect(throws: CrossmintServiceError.self) {
            try coder.decode(TestModel.self, from: emptyData)
        }
    }

    @Test("Round trip encoding and decoding preserves data")
    func roundTripEncodingAndDecodingPreservesData() throws {
        let coder = DefaultJSONCoder()
        let originalModel = TestModel(name: "roundTrip", value: 999)

        let encodedData = try coder.encode(originalModel)
        let decodedModel: TestModel = try coder.decode(TestModel.self, from: encodedData)

        #expect(decodedModel.name == originalModel.name)
        #expect(decodedModel.value == originalModel.value)
    }

    @Test("Round trip with dates preserves data")
    func roundTripWithDatesPreservesData() throws {
        let coder = DefaultJSONCoder()
        let date = Date()
        let originalModel = TestModelWithDate(name: "dateRoundTrip", createdAt: date)

        let encodedData = try coder.encode(originalModel)
        let decodedModel: TestModelWithDate = try coder.decode(TestModelWithDate.self, from: encodedData)

        #expect(decodedModel.name == originalModel.name)
        #expect(abs(decodedModel.createdAt.timeIntervalSince1970 - originalModel.createdAt.timeIntervalSince1970) < 0.001)
    }

    @Test("Handles complex nested structures")
    func handlesComplexNestedStructures() throws {
        struct NestedModel: Codable {
            let inner: TestModel
            let items: [TestModel]
            let metadata: [String: String]
        }

        let coder = DefaultJSONCoder()
        let originalModel = NestedModel(
            inner: TestModel(name: "nested", value: 123),
            items: [
                TestModel(name: "item1", value: 1),
                TestModel(name: "item2", value: 2)
            ],
            metadata: ["key1": "value1", "key2": "value2"]
        )

        let encodedData = try coder.encode(originalModel)
        let decodedModel: NestedModel = try coder.decode(NestedModel.self, from: encodedData)

        #expect(decodedModel.inner.name == "nested")
        #expect(decodedModel.inner.value == 123)
        #expect(decodedModel.items.count == 2)
        #expect(decodedModel.items[0].name == "item1")
        #expect(decodedModel.items[1].name == "item2")
        #expect(decodedModel.metadata["key1"] == "value1")
        #expect(decodedModel.metadata["key2"] == "value2")
    }

    @Test("Encoding throws CrossmintServiceError.invalidData on failure")
    func encodingThrowsCrossmintServiceErrorInvalidDataOnFailure() {
        struct FailingEncodable: Encodable {
            func encode(to encoder: Encoder) throws {
                throw EncodingError.invalidValue(
                    "test",
                    EncodingError.Context(codingPath: [], debugDescription: "Test encoding failure")
                )
            }
        }

        let coder = DefaultJSONCoder()
        let failingModel = FailingEncodable()

        #expect {
            try coder.encode(failingModel)
        } throws: { error in
            if case .invalidData(let message) = error as? CrossmintServiceError {
                return message.contains("Test encoding failure")
            }
            return false
        }
    }

    @Test("Decoding throws CrossmintServiceError.invalidData on failure")
    func decodingThrowsCrossmintServiceErrorInvalidDataOnFailure() {
        let coder = DefaultJSONCoder()
        let invalidJSON = "not valid json at all"
        let data = Data(invalidJSON.utf8)

        #expect {
            try coder.decode(TestModel.self, from: data)
        } throws: { error in
            if case .invalidData = error as? CrossmintServiceError {
                return true
            }
            return false
        }
    }

    private var calendar: Calendar {
        var calendar = Calendar.current
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}
