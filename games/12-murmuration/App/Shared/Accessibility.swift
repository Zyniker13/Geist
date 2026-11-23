// Accessibility system-setting bridge (MU-P8.1).
//
// The shared app code needs the platform Reduce Motion / Increase Contrast
// state without importing UIKit in a mac-only file or AppKit in an iOS
// file. This enum wraps the per-platform reads; both surfaces call the
// same names.

#if canImport(UIKit)
    import UIKit

    /// iOS/iPadOS: UIAccessibility carries both settings.
    enum Accessibility {
        static func macReduceMotionEnabled() -> Bool {
            false  // unreachable on iOS; see platformReduceMotionEnabled
        }

        static func platformReduceMotionEnabled() -> Bool {
            UIAccessibility.isReduceMotionEnabled
        }

        static func platformIncreaseContrastEnabled() -> Bool {
            UIAccessibility.isDarkerSystemColorsEnabled
        }
    }
#else
    import AppKit

    /// macOS: NSWorkspace exposes the accessibility display options.
    enum Accessibility {
        static func macReduceMotionEnabled() -> Bool {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }

        static func platformReduceMotionEnabled() -> Bool {
            macReduceMotionEnabled()
        }

        static func platformIncreaseContrastEnabled() -> Bool {
            NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        }
    }
#endif
