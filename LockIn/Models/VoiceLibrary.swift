//
//  VoiceLibrary.swift
//  LockIn
//
//  Central source for the LockIn voice characters and their clips.
//  Keep all character/clip data here so adding more characters later
//  is a single-file edit.
//
//  ──────────────────────────────────────────────────────────────────────
//  AUDIO FILES
//  Audio files must be added to the Xcode target. If missing, notifications
//  fall back to the default notification sound (see NotificationManager
//  `resolvedSound(for:)`). No crash, no scary error for the user — just a
//  developer log: "[LockIn] Sound file <name> not found in bundle — using
//  default sound."
//
//  To add: drag each .caf file into the LockIn app target in Xcode, make
//  sure "Copy items if needed" is on and the LockIn target is checked under
//  "Add to targets". Filenames must match `soundFileName` below exactly.
//  ──────────────────────────────────────────────────────────────────────
//

import SwiftUI

// MARK: - Models

struct VoiceCharacter: Identifiable, Hashable {
    let id: String
    let name: String
    let archetype: String
    let shortDescription: String
    let toneTags: [String]
    let accentHex: UInt32
    let isPremium: Bool
    let clipIDs: [String]
}

extension VoiceCharacter {
    var accent: Color { Color(hex: accentHex) }

    var clips: [VoiceClip] {
        VoiceLibrary.clips(forCharacter: id)
    }
}

struct VoiceClip: Identifiable, Hashable {
    let id: String
    let characterId: String
    let sayingTitle: String
    let notificationText: String
    let soundFileName: String
    let intensityLevel: Int      // 1 (low) ... 5 (high)
    let isPremium: Bool
}

// MARK: - Library

enum VoiceLibrary {
    /// The three starter characters. Add more by appending here AND adding
    /// matching entries to `clips` below.
    static let characters: [VoiceCharacter] = [
        VoiceCharacter(
            id: "police_officer",
            name: "Police Officer",
            archetype: "Authority Check",
            shortDescription: "Direct, commanding, and a little dramatic.",
            toneTags: ["Commanding", "Funny", "Loud"],
            accentHex: 0x3A6FB0,   // muted police blue
            isPremium: false,
            clipIDs: [
                "police_get_off_phone",
                "police_time_is_up",
                "police_final_warning"
            ]
        ),

        VoiceCharacter(
            id: "librarian",
            name: "Librarian",
            archetype: "Quiet Accountability",
            shortDescription: "Calm, disappointed, and quietly devastating.",
            toneTags: ["Quiet", "Judgmental", "Calm"],
            accentHex: 0x8A6D4E,   // warm sepia / library brown
            isPremium: false,
            clipIDs: [
                "librarian_quiet_please",
                "librarian_disappointed",
                "librarian_page_back"
            ]
        ),

        VoiceCharacter(
            id: "drill_sergeant",
            name: "Drill Sergeant",
            archetype: "Hard Reset",
            shortDescription: "Loud, intense, and allergic to excuses.",
            toneTags: ["Aggressive", "Loud", "No excuses"],
            accentHex: 0xB94135,   // muted military red
            isPremium: false,
            clipIDs: [
                "drill_lock_in",
                "drill_get_back_to_work",
                "drill_times_up"
            ]
        )
    ]

    /// One row per clip. Each clip's `characterId` must match a `VoiceCharacter.id`.
    static let clips: [VoiceClip] = [
        // Police Officer
        VoiceClip(id: "police_get_off_phone", characterId: "police_officer", sayingTitle: "Get Off The Phone", notificationText: "Step away from the phone.",            soundFileName: "police_get_off_phone.caf", intensityLevel: 4, isPremium: false),
        VoiceClip(id: "police_time_is_up",    characterId: "police_officer", sayingTitle: "Time Is Up",        notificationText: "Time is up. Move along.",              soundFileName: "police_time_is_up.caf",    intensityLevel: 3, isPremium: false),
        VoiceClip(id: "police_final_warning", characterId: "police_officer", sayingTitle: "Final Warning",     notificationText: "This is your final warning. Lock in.", soundFileName: "police_final_warning.caf", intensityLevel: 5, isPremium: false),

        // Librarian
        VoiceClip(id: "librarian_quiet_please", characterId: "librarian", sayingTitle: "Quiet Please",  notificationText: "Quiet please. Back to work.",           soundFileName: "librarian_quiet_please.caf", intensityLevel: 2, isPremium: false),
        VoiceClip(id: "librarian_disappointed", characterId: "librarian", sayingTitle: "Disappointed",  notificationText: "I expected better from you.",           soundFileName: "librarian_disappointed.caf", intensityLevel: 3, isPremium: false),
        VoiceClip(id: "librarian_page_back",    characterId: "librarian", sayingTitle: "Turn The Page", notificationText: "Turn the page. The scrolling is over.", soundFileName: "librarian_page_back.caf",    intensityLevel: 2, isPremium: false),

        // Drill Sergeant
        VoiceClip(id: "drill_lock_in",          characterId: "drill_sergeant", sayingTitle: "Lock In",          notificationText: "Lock in.",          soundFileName: "drill_lock_in.caf",          intensityLevel: 5, isPremium: false),
        VoiceClip(id: "drill_get_back_to_work", characterId: "drill_sergeant", sayingTitle: "Get Back To Work", notificationText: "Get back to work.", soundFileName: "drill_get_back_to_work.caf", intensityLevel: 4, isPremium: false),
        VoiceClip(id: "drill_times_up",         characterId: "drill_sergeant", sayingTitle: "Time's Up",        notificationText: "Time's up. Move.",  soundFileName: "drill_times_up.caf",         intensityLevel: 5, isPremium: false)
    ]

    // MARK: Lookup helpers

    static var defaultCharacter: VoiceCharacter { characters[0] }

    static var defaultClip: VoiceClip {
        firstClip(forCharacter: defaultCharacter.id) ?? clips[0]
    }

    static func character(withID id: String) -> VoiceCharacter? {
        characters.first { $0.id == id }
    }

    static func clip(withID id: String) -> VoiceClip? {
        clips.first { $0.id == id }
    }

    static func clips(forCharacter characterID: String) -> [VoiceClip] {
        clips.filter { $0.characterId == characterID }
    }

    static func firstClip(forCharacter characterID: String) -> VoiceClip? {
        clips.first { $0.characterId == characterID }
    }

    /// Resolves a (characterID, clipID) pair to a concrete clip, falling back
    /// to the character's first clip and then the library default.
    static func resolveClip(characterID: String, clipID: String) -> VoiceClip {
        if let clip = clip(withID: clipID), clip.characterId == characterID {
            return clip
        }
        if !characterID.isEmpty, let firstClip = firstClip(forCharacter: characterID) {
            return firstClip
        }
        return defaultClip
    }
}

// MARK: - Persisted selection keys

/// AppStorage keys for the saved alert. We now support multiple sayings per
/// character, with optional shuffle.
enum SelectedVoiceKeys {
    static let characterId   = "lockin.selectedVoice.characterId"
    /// Comma-joined list of selected clip IDs for the current character.
    static let clipIds       = "lockin.selectedVoice.clipIds"
}

/// Comma-joined String <-> [String] helper for the saved clip IDs.
enum SelectedClipsStorage {
    static func decode(_ raw: String) -> [String] {
        raw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    static func encode(_ ids: [String]) -> String {
        ids.joined(separator: ",")
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
