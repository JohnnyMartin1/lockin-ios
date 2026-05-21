//
//  VoiceLibrary.swift
//  LockIn
//
//  Central source for the LockIn voice characters and their clips.
//  All seed data lives here so it is easy to scale to 15–20 voices later.
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
    /// SwiftUI color derived from the character's accent hex.
    var accent: Color { Color(hex: accentHex) }

    /// Convenience to look up the clips for this character.
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
    // MARK: Characters

    static let characters: [VoiceCharacter] = [
        VoiceCharacter(
            id: "drill_sergeant",
            name: "Drill Sergeant",
            archetype: "Hard Reset",
            shortDescription: "Direct, loud, no patience.",
            toneTags: ["Aggressive", "Loud", "No excuses"],
            accentHex: 0xB94135,
            isPremium: false,
            clipIDs: [
                "drill_sergeant.get_back_to_work",
                "drill_sergeant.you_said_five_minutes",
                "drill_sergeant.move",
                "drill_sergeant.stop_scrolling",
                "drill_sergeant.lock_in"
            ]
        ),

        VoiceCharacter(
            id: "robot",
            name: "Robot",
            archetype: "Cold Logic",
            shortDescription: "Blunt reminders with zero emotion.",
            toneTags: ["Mechanical", "Dry", "Direct"],
            accentHex: 0x5C8FA3,
            isPremium: false,
            clipIDs: [
                "robot.time_exceeded",
                "robot.attention_threshold",
                "robot.disengage"
            ]
        ),

        VoiceCharacter(
            id: "anime_coach",
            name: "Anime Coach",
            archetype: "Hype Character",
            shortDescription: "High-energy motivation with chaotic optimism.",
            toneTags: ["Energetic", "Playful", "Premium"],
            accentHex: 0xE54F8A,
            isPremium: true,
            clipIDs: [
                "anime_coach.lets_go",
                "anime_coach.power_up",
                "anime_coach.hero_mode",
                "anime_coach.final_form"
            ]
        ),

        VoiceCharacter(
            id: "calm_therapist",
            name: "Calm Therapist",
            archetype: "Gentle Reset",
            shortDescription: "Soft accountability without shame.",
            toneTags: ["Calm", "Supportive", "Reflective"],
            accentHex: 0x6E9D7F,
            isPremium: false,
            clipIDs: [
                "calm_therapist.pause",
                "calm_therapist.reset_cue",
                "calm_therapist.notice_the_urge",
                "calm_therapist.honor_it"
            ]
        ),

        VoiceCharacter(
            id: "gym_bro",
            name: "Gym Bro",
            archetype: "Discipline Mode",
            shortDescription: "Treats scrolling like skipping leg day.",
            toneTags: ["Funny", "Intense", "Motivational"],
            accentHex: 0xE08A33,
            isPremium: true,
            clipIDs: [
                "gym_bro.enough_scrolling",
                "gym_bro.skip_leg_day",
                "gym_bro.rep_your_goals",
                "gym_bro.phone_down"
            ]
        )
    ]

    // MARK: Clips

    static let clips: [VoiceClip] = [
        // Drill Sergeant
        VoiceClip(id: "drill_sergeant.get_back_to_work",     characterId: "drill_sergeant", sayingTitle: "Get Back To Work",    notificationText: "Get back to work.",                          soundFileName: "lockin_default.caf", intensityLevel: 4, isPremium: false),
        VoiceClip(id: "drill_sergeant.you_said_five_minutes", characterId: "drill_sergeant", sayingTitle: "You Said Five Minutes", notificationText: "You said five minutes.",                  soundFileName: "lockin_default.caf", intensityLevel: 3, isPremium: false),
        VoiceClip(id: "drill_sergeant.move",                  characterId: "drill_sergeant", sayingTitle: "Move",                  notificationText: "Time's up. Move.",                        soundFileName: "lockin_default.caf", intensityLevel: 5, isPremium: false),
        VoiceClip(id: "drill_sergeant.stop_scrolling",        characterId: "drill_sergeant", sayingTitle: "Stop Scrolling",        notificationText: "Stop scrolling.",                         soundFileName: "lockin_default.caf", intensityLevel: 4, isPremium: false),
        VoiceClip(id: "drill_sergeant.lock_in",               characterId: "drill_sergeant", sayingTitle: "Lock In",               notificationText: "Lock in.",                                soundFileName: "lockin_default.caf", intensityLevel: 3, isPremium: false),

        // Robot
        VoiceClip(id: "robot.time_exceeded",          characterId: "robot", sayingTitle: "Time Exceeded",      notificationText: "Time exceeded. Return to task.",       soundFileName: "lockin_default.caf", intensityLevel: 1, isPremium: false),
        VoiceClip(id: "robot.attention_threshold",    characterId: "robot", sayingTitle: "Attention Threshold", notificationText: "User attention threshold breached.",  soundFileName: "lockin_default.caf", intensityLevel: 1, isPremium: false),
        VoiceClip(id: "robot.disengage",              characterId: "robot", sayingTitle: "Disengage",          notificationText: "Recommend disengagement.",             soundFileName: "lockin_default.caf", intensityLevel: 2, isPremium: false),

        // Anime Coach
        VoiceClip(id: "anime_coach.lets_go",     characterId: "anime_coach", sayingTitle: "Let's Go",     notificationText: "Let's go! You've got this!",            soundFileName: "lockin_default.caf", intensityLevel: 4, isPremium: true),
        VoiceClip(id: "anime_coach.power_up",    characterId: "anime_coach", sayingTitle: "Power Up",     notificationText: "Power up — stop scrolling!",            soundFileName: "lockin_default.caf", intensityLevel: 5, isPremium: true),
        VoiceClip(id: "anime_coach.hero_mode",   characterId: "anime_coach", sayingTitle: "Hero Mode",    notificationText: "Hero mode: activated. Touch grass.",    soundFileName: "lockin_default.caf", intensityLevel: 3, isPremium: true),
        VoiceClip(id: "anime_coach.final_form",  characterId: "anime_coach", sayingTitle: "Final Form",   notificationText: "Final form: focus. Try it.",            soundFileName: "lockin_default.caf", intensityLevel: 4, isPremium: true),

        // Calm Therapist
        VoiceClip(id: "calm_therapist.pause",           characterId: "calm_therapist", sayingTitle: "Pause",           notificationText: "Pause. You know why this fired.",  soundFileName: "lockin_default.caf", intensityLevel: 1, isPremium: false),
        VoiceClip(id: "calm_therapist.reset_cue",       characterId: "calm_therapist", sayingTitle: "Reset Cue",       notificationText: "This is your reset cue.",          soundFileName: "lockin_default.caf", intensityLevel: 1, isPremium: false),
        VoiceClip(id: "calm_therapist.notice_the_urge", characterId: "calm_therapist", sayingTitle: "Notice The Urge", notificationText: "Notice the urge. Step away.",      soundFileName: "lockin_default.caf", intensityLevel: 2, isPremium: false),
        VoiceClip(id: "calm_therapist.honor_it",        characterId: "calm_therapist", sayingTitle: "Honor It",        notificationText: "You scheduled this. Honor it.",    soundFileName: "lockin_default.caf", intensityLevel: 2, isPremium: false),

        // Gym Bro
        VoiceClip(id: "gym_bro.enough_scrolling", characterId: "gym_bro", sayingTitle: "Enough Scrolling", notificationText: "Bro — that's enough scrolling.",                 soundFileName: "lockin_default.caf", intensityLevel: 3, isPremium: true),
        VoiceClip(id: "gym_bro.skip_leg_day",     characterId: "gym_bro", sayingTitle: "Skip Leg Day",     notificationText: "You don't skip leg day. Don't skip this.",       soundFileName: "lockin_default.caf", intensityLevel: 3, isPremium: true),
        VoiceClip(id: "gym_bro.rep_your_goals",   characterId: "gym_bro", sayingTitle: "Rep Your Goals",   notificationText: "Time to rep your goals, not your feed.",         soundFileName: "lockin_default.caf", intensityLevel: 4, isPremium: true),
        VoiceClip(id: "gym_bro.phone_down",       characterId: "gym_bro", sayingTitle: "Phone Down",       notificationText: "Push through. Phone down.",                      soundFileName: "lockin_default.caf", intensityLevel: 4, isPremium: true)
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

    /// Resolves a saved (characterID, clipID) pair to a concrete clip, falling
    /// back to the character's default clip or the library default.
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

/// New unified keys for the saved voice selection.
/// Older keys from earlier phases are intentionally not migrated.
enum SelectedVoiceKeys {
    static let characterId = "lockin.selectedVoice.characterId"
    static let clipId      = "lockin.selectedVoice.clipId"
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
