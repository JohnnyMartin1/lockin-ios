//
//  LockInLimit.swift
//  LockIn
//
//  Created by Catherine Fratila on 5/20/26.
//

import Foundation

struct LockInLimitOption: Identifiable, Hashable {
    let minutes: Int

    var id: Int { minutes }

    var shortLabel: String {
        if minutes >= 60 {
            let hours = minutes / 60
            return hours == 1 ? "1h" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    var longLabel: String {
        switch minutes {
        case 1: return "1 minute"
        case 60: return "1 hour"
        case let m where m > 60 && m % 60 == 0: return "\(m / 60) hours"
        default: return "\(minutes) minutes"
        }
    }

    var caption: String {
        switch minutes {
        case 1:   return "Ruthless. Almost evil."
        case 5:   return "Quick hit. Recommended."
        case 10:  return "Short leash."
        case 15:  return "Reasonable scroll."
        case 30:  return "Generous. Too generous."
        case 60:  return "Living dangerously."
        default:  return "Lock in tighter."
        }
    }
}

extension LockInLimitOption {
    static let options: [LockInLimitOption] = [
        LockInLimitOption(minutes: 1),
        LockInLimitOption(minutes: 5),
        LockInLimitOption(minutes: 10),
        LockInLimitOption(minutes: 15),
        LockInLimitOption(minutes: 30),
        LockInLimitOption(minutes: 60)
    ]

    static let defaultMinutes: Int = 5

    static func option(forMinutes minutes: Int) -> LockInLimitOption {
        options.first { $0.minutes == minutes }
            ?? LockInLimitOption(minutes: minutes)
    }
}

enum SelectedLimitKeys {
    static let minutes = "lockin.selectedLimit.minutes"
}
