import AudioToolbox
import Foundation

struct UserPresetRecord: Codable, Equatable, Sendable {
    var number: Int
    var name: String
    var values: [String: Float]

    var auPreset: AUAudioUnitPreset {
        let preset = AUAudioUnitPreset()
        preset.number = number
        preset.name = name
        return preset
    }
}

/// The user-preset list as a value: every rule about matching, numbering and
/// replacing presets, with no storage and no audio unit attached. The audio
/// unit loads one, edits it, and hands it back to `UserPresetStore`.
///
/// User presets take negative numbers, as the AUAudioUnit API requires;
/// factory presets own zero and up.
struct UserPresetLibrary: Equatable, Sendable {
    private(set) var records: [UserPresetRecord]

    init(records: [UserPresetRecord] = []) {
        self.records = records
    }

    /// The record a host's preset refers to. Number and name together first;
    /// then number alone, for a preset renamed since the host saw it; then
    /// name alone, for a host that kept the name and lost the number.
    func record(number: Int, name: String) -> UserPresetRecord? {
        records.first { $0.number == number && $0.name == name }
            ?? records.first { $0.number == number }
            ?? records.first { $0.name == name }
    }

    /// Names are unique ignoring case: "Clean" and "clean" are one preset.
    func record(named name: String) -> UserPresetRecord? {
        records.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// The highest unused number, counting down from -1.
    var nextNumber: Int {
        let used = Set(records.map(\.number))
        var number = -1
        while used.contains(number) {
            number -= 1
        }
        return number
    }

    /// Stores `values` under `number`, renaming that record if it exists.
    /// Failing that, a record with the same name takes the values, so saving
    /// over an existing name replaces it rather than adding a twin.
    mutating func save(number: Int, name: String, values: [String: Float]) {
        if let index = records.firstIndex(where: { $0.number == number }) {
            records[index].name = name
            records[index].values = values
        } else if let index = records.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            records[index].values = values
        } else {
            records.append(UserPresetRecord(number: number, name: name, values: values))
        }
    }

    mutating func rename(number: Int, to name: String) throws {
        guard let index = records.firstIndex(where: { $0.number == number }) else {
            throw JJMidnightPresetError.notFound
        }
        records[index].name = name
    }

    mutating func remove(number: Int) {
        records.removeAll { $0.number == number }
    }
}

/// The one UserDefaults domain both processes read and write.
///
/// The App Group suite whenever the container exists — that is what lets the
/// companion app and the extension see the same presets and trial state.
/// Without it (a build missing the entitlement) each process falls back to
/// its own standard defaults, which still works, just not across the two.
///
/// Writes go to this domain only. Earlier builds also wrote copies to
/// standard defaults and, for presets, to a JSON file; those are read once,
/// as a fallback when the primary has nothing, and copied forward.
enum SharedDefaults {
    static let appGroupID = "group.com.gerov.jjmidnight"

    // UserDefaults is documented thread-safe but not marked Sendable, and
    // this is only ever read after its one-time initialisation.
    nonisolated(unsafe) static let primary: UserDefaults = {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil,
              let suite = UserDefaults(suiteName: appGroupID)
        else { return .standard }
        return suite
    }()

    /// Where earlier builds kept a second copy, if that is a different
    /// domain from `primary`.
    static var legacy: UserDefaults? {
        primary === UserDefaults.standard ? nil : .standard
    }
}

enum UserPresetStore {
    private static let defaultsKey = "jjmidnight.userPresets.v1"

    static func loadLibrary() -> UserPresetLibrary {
        UserPresetLibrary(records: load())
    }

    static func save(_ library: UserPresetLibrary) throws {
        try save(library.records)
    }

    static func load() -> [UserPresetRecord] {
        if let records = decode(SharedDefaults.primary.data(forKey: defaultsKey)) { return records }
        // Nothing in the primary yet: migrate whatever an earlier build left.
        if let records = decode(SharedDefaults.legacy?.data(forKey: defaultsKey)) ?? decode(legacyFileData()) {
            try? save(records)
            return records
        }
        return []
    }

    private static func decode(_ data: Data?) -> [UserPresetRecord]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([UserPresetRecord].self, from: data)
    }

    static func save(_ records: [UserPresetRecord]) throws {
        let data = try JSONEncoder().encode(records)
        SharedDefaults.primary.set(data, forKey: defaultsKey)
    }

    /// The JSON copy earlier builds wrote beside the defaults. Read only.
    private static func legacyFileData() -> Data? {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedDefaults.appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let url = base?.appendingPathComponent("jj-midnight/user-presets.json") else { return nil }
        return try? Data(contentsOf: url)
    }
}
