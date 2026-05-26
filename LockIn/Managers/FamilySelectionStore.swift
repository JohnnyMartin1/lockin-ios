//
//  FamilySelectionStore.swift
//  LockIn
//
//  Phase A: Holds the user's real `FamilyActivitySelection` and persists it to
//  the LockIn App Group container so the Device Activity Monitor extension
//  (Phase B) can read the same selection without re-prompting the user.
//
//  Tokens inside `FamilyActivitySelection` are intentionally opaque — LockIn
//  never sees real app names. Do not attempt to display app names or icons
//  from these tokens; show counts only.
//

import Combine
import FamilyControls
import Foundation

@MainActor
final class FamilySelectionStore: ObservableObject {

    static let shared = FamilySelectionStore()

    /// The current FamilyActivitySelection. Mutating this property
    /// automatically persists to the App Group container.
    @Published var selection: FamilyActivitySelection {
        didSet { save() }
    }

    // MARK: - Storage

    /// App Group container shared with future Monitor Extension.
    private static let appGroupSuiteName = "group.com.JohnMartin.LockInapp"
    private static let storageKey = "lockin.familyActivitySelection.v1"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupSuiteName)
    }

    private init() {
        // Try to load any previously saved selection from the App Group container.
        // FamilyActivitySelection conforms to Codable as of iOS 15.4.
        if let data = UserDefaults(suiteName: Self.appGroupSuiteName)?.data(forKey: Self.storageKey),
           let decoded = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
            self.selection = decoded
            print("[LockIn] FamilySelectionStore loaded selection from App Group "
                  + "(apps=\(decoded.applicationTokens.count) "
                  + "categories=\(decoded.categoryTokens.count) "
                  + "webs=\(decoded.webDomainTokens.count)).")
        } else {
            self.selection = FamilyActivitySelection()
            print("[LockIn] FamilySelectionStore initialized with empty selection.")
        }
    }

    // MARK: - Inspection (counts only — tokens are opaque)

    var hasAnySelection: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    var totalCount: Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    /// Human-readable, name-free summary of what's selected.
    var summary: String {
        let apps = selection.applicationTokens.count
        let cats = selection.categoryTokens.count
        let webs = selection.webDomainTokens.count
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        if webs > 0 { parts.append("\(webs) site\(webs == 1 ? "" : "s")") }
        return parts.isEmpty ? "Nothing selected" : parts.joined(separator: ", ")
    }

    // MARK: - Mutations

    func clear() {
        selection = FamilyActivitySelection()
    }

    /// Re-reads the persisted selection from the App Group before starting
    /// DeviceActivity monitoring so tokens match what was saved in the picker.
    func reloadFromAppGroup() {
        guard let sharedDefaults,
              let data = sharedDefaults.data(forKey: Self.storageKey) else {
            print("[LockIn] FamilySelectionStore reload: no data in App Group (\(Self.storageKey)).")
            return
        }
        do {
            let decoded = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
            selection = decoded
            print("[LockIn] FamilySelectionStore reload OK "
                  + "apps=\(decoded.applicationTokens.count) "
                  + "categories=\(decoded.categoryTokens.count) "
                  + "webs=\(decoded.webDomainTokens.count)")
        } catch {
            print("[LockIn] FamilySelectionStore reload decode failed: \(error)")
        }
    }

    // MARK: - Persistence

    // TODO: Phase B — finalize cross-process persistence here when the Device
    // Activity Monitor extension reads this same key from the App Group. The
    // shape (`PropertyListEncoder` of `FamilyActivitySelection`) is already
    // forward-compatible; only the read-side in the extension needs to land.
    private func save() {
        guard let sharedDefaults else {
            print("[LockIn] FamilySelectionStore: App Group UserDefaults unavailable. "
                  + "Selection lives in memory for this session only.")
            return
        }
        do {
            let data = try PropertyListEncoder().encode(selection)
            sharedDefaults.set(data, forKey: Self.storageKey)
            print("[LockIn] FamilySelectionStore persisted selection "
                  + "(apps=\(selection.applicationTokens.count) "
                  + "categories=\(selection.categoryTokens.count) "
                  + "webs=\(selection.webDomainTokens.count)).")
        } catch {
            print("[LockIn] FamilySelectionStore failed to persist FamilyActivitySelection: \(error). "
                  + "Selection lives in memory for this session.")
        }
    }
}
