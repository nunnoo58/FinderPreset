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

        let recursive = NSMenuItem(title: "하위 폴더까지 적용", action: nil, keyEquivalent: "")
        recursive.submenu = NSMenu()
        presetItems(tagOffset: Self.recursiveTag).forEach(recursive.submenu!.addItem)
        submenu.addItem(recursive)
        submenu.addItem(NSMenuItem(title: "현재 보기를 프리셋으로 저장…", action: #selector(saveCurrent(_:)), keyEquivalent: ""))
        submenu.addItem(.separator())
        submenu.addItem(NSMenuItem(title: "프리셋 편집…", action: #selector(openEditor(_:)), keyEquivalent: ""))

        let root = NSMenuItem(title: "보기 프리셋", action: nil, keyEquivalent: "")
        root.image = NSImage(systemSymbolName: "rectangle.grid.2x2", accessibilityDescription: nil)
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

    @objc private func applyPreset(_ sender: NSMenuItem) {
        let recursive = sender.tag >= Self.recursiveTag
        let index = sender.tag % Self.recursiveTag
        let presets = PresetStore.load()
        let paths = targetPaths()
        guard presets.indices.contains(index), !paths.isEmpty else { return }
        let preset = presets[index]

        FinderScript.queue.async {
            var targets = paths
            // 상속은 지금 있는 하위 폴더에 한 번 복사하는 것이고, 나중에 만든 폴더는 따르지 않는다
            if recursive {
                switch FinderScript.withSubfolders(paths) {
                case .success(let all): targets = all
                case .failure(let error): return Self.showError(error.message)
                }
                // 폴더마다 창을 열고 닫아 오래 걸리므로 많으면 먼저 묻는다
                if targets.count > 20, !Self.confirm(count: targets.count) { return }
            }
            if let error = FinderScript.apply(preset, to: targets) { Self.showError(error) }
        }
    }

    @objc private func saveCurrent(_ sender: NSMenuItem) {
        guard let path = targetPaths().first else { return }
        FinderScript.queue.async {
            switch FinderScript.read(path: path) {
            case .success(var preset):
                guard let name = Self.askName(defaultName: preset.name) else { return }
                preset.name = name
                var presets = PresetStore.load()
                presets.append(preset)
                PresetStore.save(presets)
            case .failure(let error):
                Self.showError(error.message)
            }
        }
    }

    @objc private func openEditor(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(URL(string: "finderpresets://")!)
    }

    // MARK: - 대화 상자 (스크립트 큐에서 불러 메인 스레드에서 띄운다)

    private static func onMain<T>(_ body: () -> T) -> T {
        Thread.isMainThread ? body() : DispatchQueue.main.sync(execute: body)
    }

    private static func askName(defaultName: String) -> String? {
        onMain {
            let alert = NSAlert()
            alert.messageText = "현재 보기를 프리셋으로 저장"
            alert.informativeText = "프리셋 이름을 입력한다."
            alert.addButton(withTitle: "저장")
            alert.addButton(withTitle: "취소")
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
            field.stringValue = defaultName
            alert.accessoryView = field
            alert.window.initialFirstResponder = field
            NSApp.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
            let name = field.stringValue.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? defaultName : name
        }
    }

    private static func confirm(count: Int) -> Bool {
        onMain {
            let alert = NSAlert()
            alert.messageText = "폴더 \(count)개에 적용한다"
            alert.informativeText = "폴더마다 창을 열어 적용해 약 \(max(1, count * 3 / 60))분 걸린다. 그동안 Finder를 조작하지 않아야 한다."
            alert.addButton(withTitle: "적용")
            alert.addButton(withTitle: "취소")
            NSApp.activate(ignoringOtherApps: true)
            return alert.runModal() == .alertFirstButtonReturn
        }
    }

    private static func showError(_ message: String) {
        onMain {
            let alert = NSAlert()
            alert.messageText = "Finder 프리셋 오류"
            alert.informativeText = message
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}
