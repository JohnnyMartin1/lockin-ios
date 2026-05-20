//
//  LockInVoiceClip.swift
//  LockIn
//
//  Created by Catherine Fratila on 5/20/26.
//

import Foundation

struct LockInVoiceClip: Identifiable, Hashable, Codable {
    let id: String
    let voiceName: String
    let sayingTitle: String
    let notificationText: String
    let soundFileName: String
    let isPremium: Bool
    let subtitle: String
}

extension LockInVoiceClip {
    static let bundled: [LockInVoiceClip] = [
        LockInVoiceClip(
            id: "default_coach.get_back_to_work",
            voiceName: "Default Coach",
            sayingTitle: "Get Back To Work",
            notificationText: "Get back to work.",
            soundFileName: "lockin_default.caf",
            isPremium: false,
            subtitle: "Clean, direct, no excuses."
        ),
        LockInVoiceClip(
            id: "drill_sergeant.lock_in",
            voiceName: "Drill Sergeant",
            sayingTitle: "Lock In",
            notificationText: "Lock in.",
            soundFileName: "lockin_default.caf",
            isPremium: false,
            subtitle: "Loud, intense, aggressive."
        ),
        LockInVoiceClip(
            id: "robot.stop_scrolling",
            voiceName: "Robot",
            sayingTitle: "Stop Scrolling",
            notificationText: "Stop scrolling.",
            soundFileName: "lockin_default.caf",
            isPremium: false,
            subtitle: "Cold, blunt, mechanical."
        ),
        LockInVoiceClip(
            id: "anime_coach.back_to_work",
            voiceName: "Anime Coach",
            sayingTitle: "Back To Work",
            notificationText: "Back to work.",
            soundFileName: "lockin_default.caf",
            isPremium: true,
            subtitle: "Premium voice pack placeholder."
        )
    ]

    static var defaultClip: LockInVoiceClip { bundled[0] }

    static func clip(withID id: String) -> LockInVoiceClip? {
        bundled.first { $0.id == id }
    }
}

enum SelectedAlertKeys {
    static let id = "lockin.selectedAlert.id"
    static let voiceName = "lockin.selectedAlert.voiceName"
    static let sayingTitle = "lockin.selectedAlert.sayingTitle"
    static let soundFileName = "lockin.selectedAlert.soundFileName"
    static let notificationText = "lockin.selectedAlert.notificationText"
}
