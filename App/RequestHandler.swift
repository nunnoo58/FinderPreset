import AppKit

extension Notification.Name {
    static let presetsChanged = Notification.Name("FinderPresetsChanged")
}

/// Finder 확장이 보낸 요청(finderpresets://apply, save, edit)을 처리한다.
/// Finder 조작에 필요한 권한(자동화, 기기 제어 및 데이터 접근)을 앱 하나만 받도록 확장은 요청만 보낸다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// ContentView가 나타날 때 SwiftUI의 openWindow를 넘겨준다
    static var openMainWindow: (() -> Void)?

    private var launchedForRequest = false
    private var pending = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 요청 때문에 실행됐으면 창을 띄우지 않고, 처리가 끝나면 종료한다
        let isDefaultLaunch = notification.userInfo?["NSApplicationLaunchIsDefaultLaunchKey"] as? Bool ?? true
        if !isDefaultLaunch {
            launchedForRequest = true
            NSApp.windows.forEach { $0.orderOut(nil) }
        }
    }

    // 창이 하나뿐인 SwiftUI 앱은 마지막 창이 사라지면 종료하는데, 요청을 처리하려고 창을 숨겼을 때도 꺼지므로 막는다.
    // 요청 때문에 실행된 경우에는 처리가 끝난 뒤 직접 종료한다.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(handle)
    }

    private func handle(_ url: URL) {
        guard url.scheme == "finderpresets" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let paths = items.filter { $0.name == "path" }.compactMap(\.value)

        switch url.host {
        case "apply":
            guard let id = items.first(where: { $0.name == "preset" })?.value.flatMap(UUID.init(uuidString:)),
                  let preset = PresetStore.load().first(where: { $0.id == id }),
                  !paths.isEmpty
            else { return }
            let recursive = items.contains { $0.name == "recursive" && $0.value == "1" }
            run {
                var targets = paths
                // 상속은 지금 있는 하위 폴더에 한 번 복사하는 것이고, 나중에 만든 폴더는 따르지 않는다
                if recursive {
                    switch FinderScript.withSubfolders(paths) {
                    case .success(let all): targets = all
                    case .failure(let error): return Dialogs.showError(error.message)
                    }
                    // 폴더마다 창을 열고 닫아 오래 걸리므로 많으면 먼저 묻는다
                    if targets.count > 20, !Dialogs.confirm(count: targets.count) { return }
                }
                if let error = FinderScript.apply(preset, to: targets) { Dialogs.showError(error) }
            }

        case "save":
            guard let path = paths.first else { return }
            run {
                switch FinderScript.read(path: path) {
                case .success(var preset):
                    guard let name = Dialogs.askName(defaultName: preset.name) else { return }
                    preset.name = name
                    var presets = PresetStore.load()
                    presets.append(preset)
                    PresetStore.save(presets)
                    DispatchQueue.main.async { NotificationCenter.default.post(name: .presetsChanged, object: nil) }
                case .failure(let error):
                    Dialogs.showError(error.message)
                }
            }

        default:
            showMainWindow()
        }
    }

    private func run(_ work: @escaping () -> Void) {
        pending += 1
        FinderScript.queue.async {
            work()
            DispatchQueue.main.async {
                self.pending -= 1
                if self.launchedForRequest, self.pending == 0 { NSApp.terminate(nil) }
            }
        }
    }

    private func showMainWindow() {
        launchedForRequest = false
        NSApp.activate(ignoringOtherApps: true)
        if let open = Self.openMainWindow {
            open()
        } else {
            NSApp.windows.filter(\.canBecomeMain).forEach { $0.makeKeyAndOrderFront(nil) }
        }
    }
}

/// 스크립트 큐에서 불러 메인 스레드에서 띄우는 대화 상자
enum Dialogs {
    private static func onMain<T>(_ body: () -> T) -> T {
        Thread.isMainThread ? body() : DispatchQueue.main.sync(execute: body)
    }

    /// 스크립트가 Finder를 앞으로 가져온 뒤라 일반 activate로는 앱이 앞으로 오지 않아 System Events로 가져온다
    private static func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        let pid = ProcessInfo.processInfo.processIdentifier
        NSAppleScript(source: "tell application \"System Events\" to set frontmost of (first process whose unix id is \(pid)) to true")?
            .executeAndReturnError(nil)
    }

    static func askName(defaultName: String) -> String? {
        onMain {
            let alert = NSAlert()
            alert.messageText = L("현재 보기를 프리셋으로 저장", "Save Current View as Preset")
            alert.informativeText = L("프리셋 이름을 입력하세요.", "Enter a name for the preset.")
            alert.addButton(withTitle: L("저장", "Save"))
            alert.addButton(withTitle: L("취소", "Cancel"))
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
            field.stringValue = defaultName
            alert.accessoryView = field
            alert.window.initialFirstResponder = field
            bringToFront()
            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
            let name = field.stringValue.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? defaultName : name
        }
    }

    static func confirm(count: Int) -> Bool {
        onMain {
            let alert = NSAlert()
            let minutes = max(1, count * 3 / 60)
            alert.messageText = L("폴더 \(count)개에 적용할까요?", "Apply to \(count) folders?")
            alert.informativeText = L("폴더마다 창을 열어 적용하므로 약 \(minutes)분 걸립니다. 그동안 Finder를 조작하지 마세요.",
                                      "Each folder is opened in a window to apply the preset, so this takes about \(minutes) min. Don't use Finder in the meantime.")
            alert.addButton(withTitle: L("적용", "Apply"))
            alert.addButton(withTitle: L("취소", "Cancel"))
            bringToFront()
            return alert.runModal() == .alertFirstButtonReturn
        }
    }

    static func showError(_ message: String) {
        onMain {
            let alert = NSAlert()
            alert.messageText = L("Finder 프리셋 오류", "Finder Presets Error")
            alert.informativeText = message
            bringToFront()
            alert.runModal()
        }
    }
}
