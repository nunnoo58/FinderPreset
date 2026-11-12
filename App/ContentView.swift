import FinderSync
import SwiftUI

struct ContentView: View {
    @State private var presets = PresetStore.load()
    @State private var selection: Preset.ID?
    @State private var extensionEnabled = FIFinderSyncController.isExtensionEnabled
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(presets) { Text($0.name) }
                    .onMove { presets.move(fromOffsets: $0, toOffset: $1) }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button("추가", systemImage: "plus") {
                        let preset = Preset(name: "새 프리셋")
                        presets.append(preset)
                        selection = preset.id
                    }
                    Button("현재 Finder 창에서 새 프리셋", systemImage: "square.and.arrow.down.on.square") { readNew() }
                        .help("맨 앞 Finder 창의 보기 설정으로 새 프리셋을 만듭니다")
                        .disabled(busy)
                    Button("삭제", systemImage: "minus") {
                        presets.removeAll { $0.id == selection }
                        selection = nil
                    }
                    .disabled(selection == nil)
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
                        Text("Finder 확장이 꺼져 있어 우클릭 메뉴에 나타나지 않습니다.")
                        Spacer()
                        Button("확장 켜기") { FIFinderSyncController.showExtensionManagementInterface() }
                    }
                    .padding(10)
                    .background(.yellow.opacity(0.2))
                }
                if let i = presets.firstIndex(where: { $0.id == selection }) {
                    PresetEditor(preset: $presets[i])
                        .toolbar {
                            Button("현재 창에서 가져오기", systemImage: "square.and.arrow.down") { read(into: i) }
                                .help("맨 앞 Finder 창의 보기 설정을 이 프리셋에 덮어씁니다")
                            Button("현재 창에 적용", systemImage: "play") { apply(presets[i]) }
                                .help("맨 앞 Finder 창에 이 프리셋을 적용합니다")
                        }
                        .disabled(busy)
                } else {
                    ContentUnavailableView("프리셋을 선택해 편집", systemImage: "folder")
                }
            }
        }
        .onChange(of: presets) { PresetStore.save(presets) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            extensionEnabled = FIFinderSyncController.isExtensionEnabled
            // Finder 확장이 우클릭으로 저장한 프리셋을 덮어쓰지 않도록 다시 읽는다
            presets = PresetStore.load()
        }
        .alert("Finder 오류", isPresented: .constant(errorMessage != nil)) {
            Button("확인") { errorMessage = nil }
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
            Section("기본") {
                TextField("이름", text: $preset.name)
                Picker("보기 방식", selection: $preset.viewStyle) {
                    ForEach(ViewStyle.allCases) { Text($0.title).tag($0) }
                }
                Picker("정렬 기준", selection: $preset.sortKey) {
                    ForEach(SortKey.allCases) { Text($0.title).tag($0) }
                }
                .help("정렬 방향은 Finder 기본값을 따릅니다. 없음·자동 격자 정렬은 아이콘 보기에서만 적용됩니다.")
            }

            Section("아이콘 보기") {
                LabeledContent("아이콘 크기") {
                    HStack {
                        Slider(value: Binding(get: { Double(preset.iconSize) }, set: { preset.iconSize = Int($0) }),
                               in: 16...512, step: 4)
                        Text("\(preset.iconSize)×\(preset.iconSize)").monospacedDigit().frame(width: 80, alignment: .trailing)
                    }
                }
                textSizePicker($preset.iconTextSize)
                Picker("레이블 위치", selection: $preset.labelOnRight) {
                    Text("아래").tag(false)
                    Text("오른쪽").tag(true)
                }
                .pickerStyle(.segmented)
                Toggle("항목 정보 보기", isOn: $preset.showsItemInfo)
                Toggle("아이콘 미리보기 보기", isOn: $preset.showsIconPreview)
            }

            Section("목록 보기") {
                Picker("아이콘 크기", selection: $preset.listLargeIcons) {
                    Text("작게").tag(false)
                    Text("크게").tag(true)
                }
                .pickerStyle(.segmented)
                textSizePicker($preset.listTextSize)
                Toggle("상대적 날짜 사용", isOn: $preset.usesRelativeDates)
                Toggle("모든 크기 계산", isOn: $preset.calculatesFolderSizes)
                Toggle("아이콘 미리보기 보기", isOn: $preset.listShowsIconPreview)
            }

            Section("계층 보기") {
                textSizePicker($preset.columnTextSize)
                Toggle("아이콘 보기", isOn: $preset.columnShowsIcon)
                Toggle("아이콘 미리보기 보기", isOn: $preset.columnShowsIconPreview)
                Toggle("미리보기 열 보기", isOn: $preset.showsPreviewColumn)
            }
        }
        .formStyle(.grouped)
    }

    private func textSizePicker(_ value: Binding<Int>) -> some View {
        Picker("텍스트 크기", selection: value) {
            ForEach(textSizes, id: \.self) { Text("\($0)").tag($0) }
        }
    }
}
