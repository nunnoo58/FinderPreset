import Foundation

enum ViewStyle: String, Codable, CaseIterable, Identifiable {
    case icon, list, column, gallery
    var id: Self { self }

    var title: String {
        switch self {
        case .icon: L("아이콘", "Icons")
        case .list: L("목록", "List")
        case .column: L("계층", "Columns")
        case .gallery: L("갤러리", "Gallery")
        }
    }

    // Finder 사전에서 갤러리 보기는 flow view로 남아 있다
    var term: String {
        switch self {
        case .icon: "icon view"
        case .list: "list view"
        case .column: "column view"
        case .gallery: "flow view"
        }
    }
}

// Finder는 AppleScript로 바꾼 정렬을 화면에 반영하지 않아 보기 > 다음으로 정렬 메뉴를 직접 누른다.
// 정렬은 보기 방식마다 따로 저장되고, 없음·자동 격자 정렬은 아이콘 보기에만 있다.
enum SortKey: String, Codable, CaseIterable, Identifiable {
    case none, snapToGrid, name, kind, lastOpened, dateAdded, modificationDate, creationDate, size, label
    var id: Self { self }

    var title: String { L(koreanName, englishName) }

    // Finder 메뉴와 보기 옵션의 열 체크박스 이름. macOS 언어가 한국어나 영어일 때 찾을 수 있다.
    var menuNames: [String] { [koreanName, englishName] }

    private var koreanName: String {
        switch self {
        case .none: "없음"
        case .snapToGrid: "자동 격자 정렬"
        case .name: "이름"
        case .kind: "종류"
        case .lastOpened: "최근 사용일"
        case .dateAdded: "추가된 날짜"
        case .modificationDate: "수정일"
        case .creationDate: "생성일"
        case .size: "크기"
        case .label: "태그"
        }
    }

    private var englishName: String {
        switch self {
        case .none: "None"
        case .snapToGrid: "Snap to Grid"
        case .name: "Name"
        case .kind: "Kind"
        case .lastOpened: "Date Last Opened"
        case .dateAdded: "Date Added"
        case .modificationDate: "Date Modified"
        case .creationDate: "Date Created"
        case .size: "Size"
        case .label: "Tags"
        }
    }

    var iconViewOnly: Bool { self == .none || self == .snapToGrid }
}

struct Preset: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var viewStyle: ViewStyle = .list
    var sortKey: SortKey = .name

    // 아이콘 보기
    var iconSize = 64
    var iconTextSize = 12
    var labelOnRight = false
    var showsItemInfo = false
    var showsIconPreview = true

    // 목록 보기
    var listLargeIcons = false
    var listTextSize = 13
    var calculatesFolderSizes = false
    var usesRelativeDates = true
    var listShowsIconPreview = true

    // 계층 보기
    var columnTextSize = 13
    var columnShowsIcon = true
    var columnShowsIconPreview = true
    var showsPreviewColumn = true

    /// 아이콘 크기는 16, 32, 64 … 512만 쓴다. Finder에서 읽은 값이나 예전 프리셋 값은 가장 가까운 단계로 맞춘다.
    static func snappedIconSize(_ size: Int) -> Int {
        min(max(Int(pow(2, log2(Double(max(size, 1))).rounded())), 16), 512)
    }

    // 프리셋 파일이 없을 때 그 시점의 언어로 만든다
    static var defaults: [Preset] {
        [
            Preset(name: L("목록 · 이름순", "List · By Name")),
            Preset(name: L("목록 · 최근 수정순", "List · Recently Modified"), sortKey: .modificationDate),
            Preset(name: L("큰 아이콘", "Large Icons"), viewStyle: .icon, sortKey: .kind, iconSize: 128, iconTextSize: 13),
        ]
    }
}

enum PresetStore {
    // 샌드박스 안에서는 홈이 컨테이너로 바뀌므로 실제 홈 경로를 쓴다. 엔타이틀먼트의 경로 예외와 맞춰야 한다.
    static var folderURL: URL {
        let home = String(cString: getpwuid(getuid()).pointee.pw_dir)
        return URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/FinderPresets")
    }

    static var fileURL: URL { folderURL.appendingPathComponent("presets.json") }

    static func load() -> [Preset] {
        guard let data = try? Data(contentsOf: fileURL),
              let presets = try? JSONDecoder().decode([Preset].self, from: data)
        else { return Preset.defaults }
        return presets.map { var p = $0; p.iconSize = Preset.snappedIconSize(p.iconSize); return p }
    }

    static func save(_ presets: [Preset]) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
