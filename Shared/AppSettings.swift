import Foundation
import Observation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system, korean, english
    var id: Self { self }
}

/// 앱과 Finder 확장이 함께 쓰는 설정. 확장은 앱의 UserDefaults를 볼 수 없어 프리셋 옆 파일에 저장한다.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var language: AppLanguage {
        didSet { if language != oldValue { save() } }
    }

    private init() {
        language = Self.load()
    }

    var usesKorean: Bool {
        switch language {
        case .korean: true
        case .english: false
        case .system: Locale.preferredLanguages.first?.hasPrefix("ko") ?? false
        }
    }

    /// 다른 프로세스(앱 ↔ 확장)가 바꾼 설정을 다시 읽는다
    func reload() {
        let stored = Self.load()
        if stored != language { language = stored }
    }

    private struct Stored: Codable {
        var language: AppLanguage
    }

    private static var fileURL: URL {
        PresetStore.folderURL.appendingPathComponent("settings.json")
    }

    private static func load() -> AppLanguage {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode(Stored.self, from: data)
        else { return .system }
        return stored.language
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(Stored(language: language)) else { return }
        try? FileManager.default.createDirectory(at: PresetStore.folderURL, withIntermediateDirectories: true)
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}

/// 설정한 언어의 문구 하나만 돌려준다
func L(_ korean: String, _ english: String) -> String {
    AppSettings.shared.usesKorean ? korean : english
}
