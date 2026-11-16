import SwiftUI

@main
struct FinderPresetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // 지난번 창을 복원하면 요청 처리용으로 실행될 때도 창이 나타나서 끈다
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false])
        Self.applyLanguageToSystemUI()
    }

    /// 메뉴 막대와 설정 창 제목처럼 시스템이 그리는 부분은 앱의 AppleLanguages를 따른다.
    /// 시작할 때 맞춰야 그 실행부터 적용된다.
    static func applyLanguageToSystemUI() {
        switch AppSettings.shared.language {
        case .system: UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .korean: UserDefaults.standard.set(["ko"], forKey: "AppleLanguages")
        case .english: UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        }
    }

    var body: some Scene {
        Window(L("Finder 프리셋", "Finder Presets"), id: "main") {
            ContentView()
        }
        .defaultSize(width: 820, height: 640)

        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Picker(L("언어", "Language"), selection: $settings.language) {
                Text(L("시스템 설정 따름", "System Default")).tag(AppLanguage.system)
                Text("한국어").tag(AppLanguage.korean)
                Text("English").tag(AppLanguage.english)
            }
            Text(L("메뉴 막대와 창 제목은 앱을 다시 열면 바뀝니다.", "The menu bar and window title change after you reopen the app."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 420)
        .onChange(of: settings.language) { FinderPresetsApp.applyLanguageToSystemUI() }
    }
}
