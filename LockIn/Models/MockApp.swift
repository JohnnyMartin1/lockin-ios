//
//  MockApp.swift
//  LockIn
//
//  Created by Catherine Fratila on 5/20/26.
//

import SwiftUI

struct MockApp: Identifiable, Hashable {
    let id: String
    let name: String
    let symbolName: String
    let accent: Color
}

extension MockApp {
    static let bundled: [MockApp] = [
        MockApp(
            id: "instagram",
            name: "Instagram",
            symbolName: "camera.fill",
            accent: Color(red: 0.88, green: 0.19, blue: 0.42)
        ),
        MockApp(
            id: "tiktok",
            name: "TikTok",
            symbolName: "music.note",
            accent: Color(red: 0.00, green: 0.85, blue: 0.85)
        ),
        MockApp(
            id: "youtube",
            name: "YouTube",
            symbolName: "play.rectangle.fill",
            accent: Color(red: 0.95, green: 0.20, blue: 0.20)
        ),
        MockApp(
            id: "x",
            name: "X",
            symbolName: "xmark",
            accent: Color.white.opacity(0.85)
        ),
        MockApp(
            id: "reddit",
            name: "Reddit",
            symbolName: "bubble.left.fill",
            accent: Color(red: 1.00, green: 0.42, blue: 0.10)
        ),
        MockApp(
            id: "safari",
            name: "Safari",
            symbolName: "safari.fill",
            accent: Color(red: 0.10, green: 0.55, blue: 0.95)
        ),
        MockApp(
            id: "snapchat",
            name: "Snapchat",
            symbolName: "camera.viewfinder",
            accent: Color(red: 1.00, green: 0.90, blue: 0.10)
        ),
        MockApp(
            id: "facebook",
            name: "Facebook",
            symbolName: "f.cursive.circle.fill",
            accent: Color(red: 0.20, green: 0.50, blue: 0.95)
        )
    ]

    static func app(withID id: String) -> MockApp? {
        bundled.first { $0.id == id }
    }
}

enum SelectedAppsKeys {
    /// Comma-joined list of selected MockApp IDs, stored in @AppStorage.
    static let ids = "lockin.selectedMockApps.ids"
}

enum SelectedAppsStorage {
    static func decode(_ raw: String) -> [String] {
        raw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    static func encode(_ ids: [String]) -> String {
        ids.joined(separator: ",")
    }
}
