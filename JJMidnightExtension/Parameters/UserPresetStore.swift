import Foundation

struct UserPresetRecord: Codable, Equatable, Sendable {
    var number: Int
    var name: String
    var values: [String: Float]
}

extension Notification.Name {
    static let jjMidnightPresetChanged = Notification.Name("jjMidnightPresetChanged")
}

enum UserPresetStore {
    static let appGroupID = "group.com.gerov.jjmidnight"
    private static let defaultsKey = "jjmidnight.userPresets.v1"

    static func load() -> [UserPresetRecord] {
        if let records = decode(groupDefaults?.data(forKey: defaultsKey)) { return records }
        if let records = decode(UserDefaults.standard.data(forKey: defaultsKey)) {
            try? save(records)
            return records
        }
        if let records = decode(fileData()) {
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
        if let suite = groupDefaults {
            suite.set(data, forKey: defaultsKey)
        }
        UserDefaults.standard.set(data, forKey: defaultsKey)
        if let url = try? fileURL() {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: [.atomic])
        }
    }

    private static var groupDefaults: UserDefaults? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            return nil
        }
        return UserDefaults(suiteName: appGroupID)
    }

    private static func fileData() -> Data? {
        guard let url = try? fileURL() else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func directoryURL() throws -> URL {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return group.appendingPathComponent("jj-midnight", isDirectory: true)
        }
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("jj-midnight", isDirectory: true)
    }

    private static func fileURL() throws -> URL {
        try directoryURL().appendingPathComponent("user-presets.json")
    }
}
