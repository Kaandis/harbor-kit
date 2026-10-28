import Foundation

/// The `settings-schema.json` every Harbor app ships in its Resources: each
/// preference it has, as a plain UserDefaults key, with enough description
/// for the Harbor hub to draw a settings screen for it.
public struct SettingsSchema: Decodable, Sendable {
    public let schemaVersion: Int
    public let app: AppInfo
    /// The preferences domain the keys live in (the app's bundle identifier).
    public let defaultsDomain: String
    public let notes: String?
    public let groups: [Group]

    public struct AppInfo: Decodable, Sendable {
        public let id: String
        public let name: String
        public let site: URL?
        public let repository: URL?
    }

    public struct Group: Decodable, Identifiable, Sendable {
        public let id: String
        public let title: Text
        public let settings: [Setting]
    }

    public struct Setting: Decodable, Identifiable, Sendable {
        public enum Kind: String, Decodable, Sendable {
            case bool, `enum`, number, language, appList, string
        }

        public let key: String
        public let type: Kind
        public let `default`: JSONValue?
        public let options: [Option]?
        public let min: Double?
        public let max: Double?
        public let step: Double?
        public let unit: String?
        public let title: Text
        public let description: Text?
        public let restartRequired: Bool?
        /// Show this setting only while other keys hold these values.
        public let visibleWhen: [String: JSONValue]?
        /// Older values that mean the same as a current one.
        public let aliases: [String: String]?

        public var id: String { key }
    }

    public struct Option: Decodable, Identifiable, Sendable {
        public let value: JSONValue
        public let title: Text
        /// e.g. ["macOS": "26.0"]: hide the option on older systems.
        public let requires: [String: String]?

        public var id: String { value.description }
    }

    /// Text in English and Turkish.
    public struct Text: Decodable, Sendable {
        public let en: String
        public let tr: String?

        public func localized(_ language: String) -> String {
            language.hasPrefix("tr") ? (tr ?? en) : en
        }
    }

    /// Loads the schema an installed app ships, if it has one.
    public static func load(fromApp url: URL) -> SettingsSchema? {
        let file = url.appendingPathComponent("Contents/Resources/settings-schema.json")
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(SettingsSchema.self, from: data)
    }
}

/// Any JSON value, for defaults and option values.
public enum JSONValue: Decodable, Equatable, Hashable, Sendable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    /// Converts a value read from preferences.
    public init(property: Any?) {
        switch property {
        case let value as Bool where CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID(): self = .bool(value)
        case let value as NSNumber: self = .number(value.doubleValue)
        case let value as String: self = .string(value)
        case let value as [Any]: self = .array(value.map { JSONValue(property: $0) })
        default: self = .null
        }
    }

    /// The value as a property-list object, for writing to preferences.
    public var property: Any? {
        switch self {
        case .string(let value): value
        case .number(let value): value
        case .bool(let value): value
        case .array(let values): values.compactMap(\.property)
        case .null: nil
        }
    }

    public var description: String {
        switch self {
        case .string(let value): value
        case .number(let value): String(value)
        case .bool(let value): String(value)
        case .array(let values): values.map(\.description).joined(separator: ",")
        case .null: "null"
        }
    }
}
