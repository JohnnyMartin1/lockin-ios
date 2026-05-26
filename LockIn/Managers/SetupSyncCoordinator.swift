//
//  SetupSyncCoordinator.swift
//  LockIn (main app target only)
//
//  Pulls the user's current AppStorage-backed setup, pre-resolves voice clips
//  from VoiceLibrary, and writes a SharedLockInConfiguration to the App Group
//  store so the Device Activity Monitor extension sees the same setup.
//
//  Call `syncCurrentSetupToSharedStore()` after every save in the setup flow.
//

import Foundation

enum SetupSyncCoordinator {

    /// Snapshot everything the extension needs and persist it to the App Group.
    /// Safe to call repeatedly; cheap on a 9-clip catalog.
    @discardableResult
    static func syncCurrentSetupToSharedStore() -> SharedLockInConfiguration {
        let defaults = UserDefaults.standard

        let modeType             = defaults.string(forKey: LockInSetupKeys.modeType) ?? ""
        let dailyLimitMinutes    = (defaults.object(forKey: LockInSetupKeys.dailyLimitMinutes)    as? Int) ?? LockInDefaults.dailyLimitMinutes
        let sessionLengthMinutes = (defaults.object(forKey: LockInSetupKeys.sessionLengthMinutes) as? Int) ?? LockInDefaults.sessionLengthMinutes
        let slipThresholdSeconds = (defaults.object(forKey: LockInSetupKeys.slipThresholdSeconds) as? Int) ?? LockInDefaults.slipThresholdSeconds
        let cooldownMinutes      = (defaults.object(forKey: LockInSetupKeys.cooldownMinutes)      as? Int) ?? LockInDefaults.cooldownMinutes
        let shuffleSayings       = (defaults.object(forKey: LockInSetupKeys.randomizeSayings)     as? Bool) ?? LockInDefaults.randomizeSayings

        let selectedCharacterId  = defaults.string(forKey: SelectedVoiceKeys.characterId) ?? ""
        let selectedClipIdsRaw   = defaults.string(forKey: SelectedVoiceKeys.clipIds) ?? ""
        let selectedClipIds      = SelectedClipsStorage.decode(selectedClipIdsRaw)

        // Pre-resolve clip payloads so the extension never has to import VoiceLibrary.
        // Only include clips that actually belong to the selected character — guards
        // against stale clipIds left over from a previous character selection.
        let resolvedClips: [SharedVoiceClipPayload] = selectedClipIds.compactMap { id in
            guard let clip = VoiceLibrary.clip(withID: id),
                  selectedCharacterId.isEmpty || clip.characterId == selectedCharacterId
            else { return nil }
            return SharedVoiceClipPayload(
                id: clip.id,
                sayingTitle: clip.sayingTitle,
                notificationText: clip.notificationText,
                soundFileName: clip.soundFileName
            )
        }

        // Preserve fields owned by the running monitoring path
        // (lastAlertFiredAt + LockIn session window). The setup-screen sync
        // never touches them — only DeviceActivityManager and the extension do.
        let existing = SharedConfigurationStore.shared.load()

        let configuration = SharedLockInConfiguration(
            modeType: modeType,
            selectedCharacterId: selectedCharacterId,
            selectedClipIds: selectedClipIds,
            shuffleSayings: shuffleSayings,
            dailyLimitMinutes: dailyLimitMinutes,
            sessionLengthMinutes: sessionLengthMinutes,
            slipThresholdSeconds: slipThresholdSeconds,
            cooldownMinutes: cooldownMinutes,
            lastAlertFiredAt: existing.lastAlertFiredAt,
            resolvedClips: resolvedClips,
            lockInSessionStartedAt: existing.lockInSessionStartedAt,
            lockInSessionEndsAt: existing.lockInSessionEndsAt
        )

        let ok = SharedConfigurationStore.shared.save(configuration)
        if ok {
            print("[LockIn] SetupSyncCoordinator wrote shared configuration "
                  + "(mode=\(modeType.isEmpty ? "—" : modeType), "
                  + "character=\(selectedCharacterId.isEmpty ? "—" : selectedCharacterId), "
                  + "clips=\(resolvedClips.count), "
                  + "shuffle=\(shuffleSayings), "
                  + "valid=\(configuration.isValidForMonitoring)).")
        }
        return configuration
    }
}
