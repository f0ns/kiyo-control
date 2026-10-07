import Carbon.HIToolbox

/// System-wide ⌃⌥1…5 shortcuts for the zoom presets. Carbon hot keys work without
/// accessibility permission, also while another app (Zoom, Meet, OBS…) is in front.
enum ZoomPresetHotKeys {
    private static var handler: ((Int) -> Void)?
    private static var installed = false

    static let keyCodes = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5]
    static let label = "⌃⌥"

    /// Registers the shortcuts once; `onPress` gets the slot index 0...4 on the main thread.
    static func register(_ onPress: @escaping (Int) -> Void) {
        handler = onPress
        guard !installed else { return }
        installed = true

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            ZoomPresetHotKeys.handler?(Int(id.id))
            return noErr
        }, 1, &spec, nil, nil)

        for (slot, code) in keyCodes.enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x4B59_4F43), id: UInt32(slot))  // 'KYOC'
            RegisterEventHotKey(UInt32(code), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &ref)
        }
    }
}
