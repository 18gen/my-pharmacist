//
//  UserDefaults+JSON.swift
//  MyPharmacist
//

import Foundation
import os

/// What is saved under a key, as `UserDefaults.saved(_:forKey:)` reads it.
enum SavedValue<Value> {
    /// Nothing was ever saved there.
    case none
    case value(Value)
    /// Something is saved but can't be read, by a newer version, say. It has been set
    /// aside before anything can replace it.
    case unreadable
}

nonisolated extension UserDefaults {
    /// A value saved as JSON under `key`. When what is there can't be read, it is kept
    /// under "<key>.unreadable" first, so nothing the person entered is lost when the
    /// app then saves over it.
    func saved<Value: Decodable>(_ type: Value.Type, forKey key: String) -> SavedValue<Value> {
        guard let data = data(forKey: key) else { return .none }
        do {
            return .value(try JSONDecoder().decode(type, from: data))
        } catch {
            set(data, forKey: key + ".unreadable")
            Log.storage.error("Couldn't read \(key, privacy: .public): \(String(describing: error), privacy: .public)")
            return .unreadable
        }
    }

    func save(_ value: some Encodable, forKey key: String) {
        do {
            set(try JSONEncoder().encode(value), forKey: key)
        } catch {
            Log.storage.error("Couldn't save \(key, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }
}
