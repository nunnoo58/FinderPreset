import Cocoa
import FinderSync

final class FinderSync: FIFinderSync {
    private var lastMenuKind: FIMenuKind = .contextualMenuForContainer

    // 하위 폴더까지 적용 메뉴는 tag에 이 값을 더해 구분한다
    private static let recursiveTag = 10_000

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else { return nil }
        lastMenuKind = menuKind
        // 앱에서 바꾼 언어를 메뉴를 열 때마다 반영한다
        AppSettings.shared.reload()

        let presets = PresetStore.load()
        // Finder는 메뉴 항목을 복사해 쓰므로 representedObject 대신 tag로 프리셋 위치를 넘긴다
        func presetItems(tagOffset: Int) -> [NSMenuItem] {
            presets.enumerated().map { index, preset in
                let item = NSMenuItem(title: preset.name, action: #selector(applyPreset(_:)), keyEquivalent: "")
                item.tag = tagOffset + index
                return item
            }
        }

        let submenu = NSMenu()
        presetItems(tagOffset: 0).forEach(submenu.addItem)
        submenu.addItem(.separator())

        let recursive = NSMenuItem(title: L("하위 폴더까지 적용", "Apply to Subfolders"), action: nil, keyEquivalent: "")
        recursive.submenu = NSMenu()
        presetItems(tagOffset: Self.recursiveTag).forEach(recursive.submenu!.addItem)
        submenu.addItem(recursive)
        submenu.addItem(NSMenuItem(title: L("현재 보기를 프리셋으로 저장…", "Save Current View as Preset…"), action: #selector(saveCurrent(_:)), keyEquivalent: ""))
        submenu.addItem(.separator())
        submenu.addItem(NSMenuItem(title: L("프리셋 편집…", "Edit Presets…"), action: #selector(openEditor(_:)), keyEquivalent: ""))

        let root = NSMenuItem(title: L("보기 프리셋", "View Presets"), action: nil, keyEquivalent: "")
        root.submenu = submenu
        let menu = NSMenu()
        menu.addItem(root)
        return menu
    }

    /// 빈 곳을 우클릭하면 지금 보고 있는 폴더, 항목을 우클릭하면 선택한 항목(파일이면 그 폴더)
    private func targetPaths() -> [String] {
        let controller = FIFinderSyncController.default()
        var paths = lastMenuKind == .contextualMenuForItems ? (controller.selectedItemURLs() ?? []).map(\.path) : []
        if paths.isEmpty, let target = controller.targetedURL() { paths = [target.path] }
        return paths
    }

    // Finder 조작은 권한을 가진 앱이 하도록 요청만 보낸다. 확장이 직접 하면 확장에도 따로 권한을 줘야 한다.
    @objc private func applyPreset(_ sender: NSMenuItem) {
        let presets = PresetStore.load()
        let index = sender.tag % Self.recursiveTag
        let paths = targetPaths()
        guard presets.indices.contains(index), !paths.isEmpty else { return }
        send("apply", [URLQueryItem(name: "preset", value: presets[index].id.uuidString),
                       URLQueryItem(name: "recursive", value: sender.tag >= Self.recursiveTag ? "1" : "0")]
             + paths.map { URLQueryItem(name: "path", value: $0) })
    }

    @objc private func saveCurrent(_ sender: NSMenuItem) {
        guard let path = targetPaths().first else { return }
        // 이름 입력 창에 바로 입력할 수 있도록 앱을 앞으로 가져온다
        send("save", [URLQueryItem(name: "path", value: path)], activates: true)
    }

    // 요청으로 실행되면 앱이 창을 닫으므로, 편집은 Dock에서 여는 것처럼 앱을 실행한다
    @objc private func openEditor(_ sender: NSMenuItem) {
        let app = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
    }

    private func send(_ action: String, _ items: [URLQueryItem], activates: Bool = false) {
        var components = URLComponents()
        components.scheme = "finderpresets"
        components.host = action
        components.queryItems = items.isEmpty ? nil : items
        guard let url = components.url else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        NSWorkspace.shared.open(url, configuration: configuration)
    }
}
