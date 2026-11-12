import Foundation

enum ViewStyle: String, Codable, CaseIterable, Identifiable {
    case icon, list, column, gallery
    var id: Self { self }

    var title: String {
        switch self {
        case .icon: "아이콘"
        case .list: "목록"
        case .column: "계층"
        case .gallery: "갤러리"
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

    // Finder 메뉴 항목 이름과 같아야 한다
    var title: String {
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

    static let defaults: [Preset] = [
        Preset(name: "목록 · 이름순"),
        Preset(name: "목록 · 최근 수정순", sortKey: .modificationDate),
        Preset(name: "큰 아이콘", viewStyle: .icon, sortKey: .kind, iconSize: 128, iconTextSize: 13),
    ]
}

enum PresetStore {
    // 샌드박스 안에서는 홈이 컨테이너로 바뀌므로 실제 홈 경로를 쓴다. 엔타이틀먼트의 경로 예외와 맞춰야 한다.
    static var fileURL: URL {
        let home = String(cString: getpwuid(getuid()).pointee.pw_dir)
        return URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/FinderPresets/presets.json")
    }

    static func load() -> [Preset] {
        guard let data = try? Data(contentsOf: fileURL),
              let presets = try? JSONDecoder().decode([Preset].self, from: data)
        else { return Preset.defaults }
        return presets
    }

    static func save(_ presets: [Preset]) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
