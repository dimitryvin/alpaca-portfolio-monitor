import Foundation
import ServiceManagement
import OSLog

/// Thin wrapper over `SMAppService.mainApp` for registering the app as a login
/// item (macOS 13+). Requires the app to be a signed bundle (ad-hoc is fine),
/// ideally installed in /Applications.
enum LaunchAtLogin {
    private static let log = Logger(
        subsystem: "com.alpacamonitor.AlpacaPortfolioMonitor",
        category: "login-item"
    )

    /// Whether the app is currently registered to open at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the login item. Returns `true` on success.
    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            log.error("login item toggle failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
