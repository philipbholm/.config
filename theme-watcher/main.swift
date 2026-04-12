import Foundation

let home = FileManager.default.homeDirectoryForCurrentUser.path
let script = "\(home)/.config/switch-theme.sh"

// Sync theme on launch
let initial = Process()
initial.executableURL = URL(fileURLWithPath: "/bin/bash")
initial.arguments = [script]
try? initial.run()
initial.waitUntilExit()

// Watch for appearance changes
DistributedNotificationCenter.default().addObserver(
    forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
    object: nil,
    queue: .main
) { _ in
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = [script]
    try? task.run()
}

RunLoop.main.run()
