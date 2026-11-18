import FinderSync
import SwiftUI

struct ContentView: View {
    @State private var presets = PresetStore.load()
    @State private var selection: Preset.ID?
    @State private var extensionEnabled = FIFinderSyncController.isExtensionEnabled
    @State private var busy = false
    @State private var errorMessage: String?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(presets) { Text($0.name) }
                    .onMove { presets.move(fromOffsets: $0, toOffset: $1) }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button(L("추가", "Add"), systemImage: "plus") {
                        let preset = Preset(name: L("새 프리셋", "New Preset"))
                        presets.append(preset)
                        selection = preset.id
                    }
                    Button(L("삭제", "Delete"), systemImage: "minus") {
                        presets.removeAll { $0.id == selection }
                        selection = nil
                    }
                    .disabled(selection == nil)
                    Button(L("현재 Finder 창에서 새 프리셋", "New Preset from Current Finder Window"), systemImage: "square.and.arrow.down.on.square") { readNew() }
                        .help(L("맨 앞 Finder 창의 보기 설정으로 새 프리셋을 만듭니다", "Creates a new preset from the frontmost Finder window's view settings"))
                        .disabled(busy)
                    Spacer()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .padding(8)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            VStack(spacing: 0) {
                if !extensionEnabled {
                    HStack {
                        Text(L("Finder 확장이 꺼져 있어 우클릭 메뉴에 나타나지 않습니다.", "The Finder extension is off, so it doesn't appear in the right-click menu."))
                        Spacer()
                        Button(L("확장 켜기", "Turn On Extension")) { FIFinderSyncController.showExtensionManagementInterface() }
                    }
                    .padding(10)
                    .background(.yellow.opacity(0.2))
                }
                if let i = presets.firstIndex(where: { $0.id == selection }) {
                    PresetEditor(preset: $presets[i])
                        .toolbar {
                            Button(L("현재 창에서 가져오기", "Import from Current Window"), systemImage: "square.and.arrow.down") { read(into: i) }
                                .help(L("맨 앞 Finder 창의 보기 설정을 이 프리셋에 덮어씁니다", "Overwrites this preset with the frontmost Finder window's view settings"))
                            Button(L("현재 창에 적용", "Apply to Current Window"), systemImage: "play") { apply(presets[i]) }
                                .help(L("맨 앞 Finder 창에 이 프리셋을 적용합니다", "Applies this preset to the frontmost Finder window"))
                        }
                        .disabled(busy)
                } else {
                    ContentUnavailableView(L("프리셋을 선택해 편집", "Select a Preset to Edit"), systemImage: "folder")
                }
            }
        }
        .onChange(of: presets) { PresetStore.save(presets) }
        .onAppear {
            AppDelegate.openMainWindow = { openWindow(id: "main") }
            if AppDelegate.hidingForRequest {
                DispatchQueue.main.async { AppDelegate.closeMainWindows() }
            }
        }
        // 우클릭으로 저장한 프리셋을 목록에 바로 반영한다
        .onReceive(NotificationCenter.default.publisher(for: .presetsChanged)) { _ in
            presets = PresetStore.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            extensionEnabled = FIFinderSyncController.isExtensionEnabled
            // Finder 확장이 우클릭으로 저장한 프리셋을 덮어쓰지 않도록 다시 읽는다
            presets = PresetStore.load()
        }
        .alert(L("Finder 오류", "Finder Error"), isPresented: .constant(errorMessage != nil)) {
            Button(L("확인", "OK")) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func apply(_ preset: Preset) {
        busy = true
        FinderScript.queue.async {
            let error = FinderScript.apply(preset, to: [])
            DispatchQueue.main.async {
                busy = false
                errorMessage = error
            }
        }
    }

    private func read(into index: Int) {
        let original = presets[index]
        readFront { read in
            var updated = read
            updated.id = original.id
            updated.name = original.name
            if let i = presets.firstIndex(where: { $0.id == original.id }) { presets[i] = updated }
        }
    }

    private func readNew() {
        readFront { preset in
            presets.append(preset)
            selection = preset.id
        }
    }

    private func readFront(_ completion: @escaping (Preset) -> Void) {
        busy = true
        FinderScript.queue.async {
            let result = FinderScript.read(path: nil)
            DispatchQueue.main.async {
                busy = false
                switch result {
                case .success(let preset): completion(preset)
                case .failure(let error): errorMessage = error.message
                }
            }
        }
    }
}

struct PresetEditor: View {
    @Binding var preset: Preset

    private let textSizes = Array(10...16)

    var body: some View {
        Form {
            Section(L("기본", "General")) {
                TextField(L("이름", "Name"), text: $preset.name)
                Picker(L("보기 방식", "View Style"), selection: $preset.viewStyle) {
                    ForEach(ViewStyle.allCases) { Text($0.title).tag($0) }
                }
                Picker(L("정렬 기준", "Sort By"), selection: $preset.sortKey) {
                    ForEach(SortKey.allCases) { Text($0.title).tag($0) }
                }
                .help(L("정렬 방향은 Finder 기본값을 따릅니다. 없음·자동 격자 정렬은 아이콘 보기에서만 적용됩니다.", "Sort direction follows Finder's default. None and Snap to Grid apply only in icon view."))
            }

            Section(L("아이콘 보기", "Icon View")) {
                LabeledContent(L("아이콘 크기", "Icon Size")) {
                    HStack {
                        // 16, 32, 64 … 512로 2배씩 커지도록 지수(2⁴~2⁹)를 움직인다
                        Slider(value: Binding(get: { log2(Double(preset.iconSize)) }, set: { preset.iconSize = Int(pow(2, $0.rounded())) }),
                               in: 4...9, step: 1)
                        Text("\(preset.iconSize)×\(preset.iconSize)").monospacedDigit().frame(width: 80, alignment: .trailing)
                    }
                }
                textSizePicker($preset.iconTextSize)
                Picker(L("레이블 위치", "Label Position"), selection: $preset.labelOnRight) {
                    Text(L("아래", "Bottom")).tag(false)
                    Text(L("오른쪽", "Right")).tag(true)
                }
                .pickerStyle(.segmented)
                Toggle(L("항목 정보 보기", "Show Item Info"), isOn: $preset.showsItemInfo)
                Toggle(L("아이콘 미리보기 보기", "Show Icon Preview"), isOn: $preset.showsIconPreview)
            }

            Section(L("목록 보기", "List View")) {
                Picker(L("아이콘 크기", "Icon Size"), selection: $preset.listLargeIcons) {
                    Text(L("작게", "Small")).tag(false)
                    Text(L("크게", "Large")).tag(true)
                }
                .pickerStyle(.segmented)
                textSizePicker($preset.listTextSize)
                Toggle(L("상대적 날짜 사용", "Use Relative Dates"), isOn: $preset.usesRelativeDates)
                Toggle(L("모든 크기 계산", "Calculate All Sizes"), isOn: $preset.calculatesFolderSizes)
                Toggle(L("아이콘 미리보기 보기", "Show Icon Preview"), isOn: $preset.listShowsIconPreview)
            }

            Section(L("계층 보기", "Column View")) {
                textSizePicker($preset.columnTextSize)
                Toggle(L("아이콘 보기", "Show Icons"), isOn: $preset.columnShowsIcon)
                Toggle(L("아이콘 미리보기 보기", "Show Icon Preview"), isOn: $preset.columnShowsIconPreview)
                Toggle(L("미리보기 열 보기", "Show Preview Column"), isOn: $preset.showsPreviewColumn)
            }
        }
        .formStyle(.grouped)
    }

    private func textSizePicker(_ value: Binding<Int>) -> some View {
        Picker(L("텍스트 크기", "Text Size"), selection: value) {
            ForEach(textSizes, id: \.self) { Text("\($0)").tag($0) }
        }
    }
}
