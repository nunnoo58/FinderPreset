import Foundation

enum FinderScript {
    // NSAppleScript는 스레드 안전하지 않아 하나의 직렬 큐에서만 실행한다
    static let queue = DispatchQueue(label: "com.nunnoo.FinderPresets.script")

    /// paths가 비어 있으면 맨 앞 Finder 창에 적용한다. 파일 경로는 그 파일이 든 폴더로 바꿔 적용한다.
    static func apply(_ preset: Preset, to paths: [String]) -> String? {
        let calls = paths.isEmpty
            ? [frontTarget, "applyPreset(t)"]
            : paths.map { "applyPreset((POSIX file \(quoted($0))) as alias)" }
        return run(helpers + applyHandler(preset) + calls.joined(separator: "\n")).error
    }

    /// path 폴더(nil이면 맨 앞 Finder 창)의 보기 설정을 읽어 그 폴더 이름을 붙인 새 프리셋으로 돌려준다.
    static func read(path: String?) -> Result<Preset, ScriptError> {
        let call = path.map { "return readPreset((POSIX file \(quoted($0))) as alias)" }
            ?? frontTarget + "\nreturn readPreset(t)"
        let result = run(helpers + readHandler + call)
        if let error = result.error { return .failure(ScriptError(message: error)) }
        guard let d = result.descriptor, d.numberOfItems >= 17 else {
            return .failure(ScriptError(message: "Finder 창 설정을 읽지 못했습니다."))
        }
        func string(_ i: Int) -> String { d.atIndex(i)?.stringValue ?? "" }
        func int(_ i: Int) -> Int { Int(d.atIndex(i)?.int32Value ?? 0) }
        func bool(_ i: Int) -> Bool { d.atIndex(i)?.booleanValue ?? false }

        var p = Preset(name: string(1))
        p.viewStyle = ViewStyle(rawValue: string(2)) ?? p.viewStyle
        p.sortKey = SortKey.allCases.first { $0.title == string(3) } ?? p.sortKey
        p.iconSize = int(4)
        p.iconTextSize = int(5)
        p.labelOnRight = bool(6)
        p.showsItemInfo = bool(7)
        p.showsIconPreview = bool(8)
        p.listLargeIcons = bool(9)
        p.listTextSize = int(10)
        p.calculatesFolderSizes = bool(11)
        p.usesRelativeDates = bool(12)
        p.listShowsIconPreview = bool(13)
        p.columnTextSize = int(14)
        p.columnShowsIcon = bool(15)
        p.columnShowsIconPreview = bool(16)
        p.showsPreviewColumn = bool(17)
        return .success(p)
    }

    /// 각 경로(파일이면 그 폴더)와 그 아래 모든 하위 폴더의 경로. 샌드박스 안에서는 폴더를 직접 훑을 수 없어 Finder에 묻는다.
    static func withSubfolders(_ paths: [String]) -> Result<[String], ScriptError> {
        let calls = paths.map { "set end of out to treeOf((POSIX file \(quoted($0))) as alias)" }
        let source = helpers + """
        on treeOf(t)
            set t to folderOf(t)
            set out to {POSIX path of t}
            tell application "Finder"
                set subs to folders of entire contents of folder (t as text)
                -- 하위 폴더가 하나면 목록이 아닌 항목 하나가 돌아온다
                if class of subs is not list then set subs to {subs}
                repeat with f in subs
                    set end of out to POSIX path of (f as alias)
                end repeat
            end tell
            return out
        end treeOf

        set out to {}
        \(calls.joined(separator: "\n"))
        return out
        """
        let result = run(source)
        if let error = result.error { return .failure(ScriptError(message: error)) }
        guard let d = result.descriptor else { return .success([]) }
        var found: [String] = []
        for i in 0..<d.numberOfItems {
            guard let tree = d.atIndex(i + 1) else { continue }
            for j in 0..<tree.numberOfItems {
                if let path = tree.atIndex(j + 1)?.stringValue, !found.contains(path) { found.append(path) }
            }
        }
        return .success(found)
    }

    struct ScriptError: Error {
        let message: String
    }

    // MARK: - 스크립트

    private static let frontTarget = "tell application \"Finder\" to set t to (target of Finder window 1) as alias"

    private static let helpers = """
    on folderOf(t)
        tell application "Finder"
            if class of item (t as text) is not in {folder, disk} then set t to (container of item (t as text)) as alias
        end tell
        return t
    end folderOf

    -- 폴더를 보여주는 창과, 그 창을 이번에 열었는지를 돌려준다.
    -- 닫힌 폴더는 일부 설정이 저장되지 않아 잠깐 열어서 다룬다.
    on windowFor(t)
        tell application "Finder"
            set targetPath to POSIX path of t
            -- repeat with w in Finder windows는 target을 alias로 바꾸지 못해 인덱스로 돈다
            repeat with i from 1 to count of Finder windows
                try
                    if POSIX path of ((target of Finder window i) as alias) is targetPath then
                        return {Finder window id (id of Finder window i), false}
                    end if
                end try
            end repeat
            open t
            delay 1
            return {Finder window id (id of Finder window 1), true}
        end tell
    end windowFor

    -- 보기 메뉴는 맨 앞 창에 적용되므로 대상 창을 앞으로 가져온다
    on sortMenu(cw)
        tell application "Finder"
            activate
            set index of cw to 1
        end tell
        delay 0.3
        tell application "System Events" to tell process "Finder"
            return menu 1 of menu item "다음으로 정렬" of menu 1 of menu bar item "보기" of menu bar 1
        end tell
    end sortMenu

    -- 보기 옵션의 "항상 ○○ 보기로 열기"가 꺼진 폴더는 보기 방식과 정렬을 기억하지 않고
    -- 마지막에 쓴 보기를 따라가므로 켠다. AppleScript로는 바꿀 수 없어 보기 옵션 창을 직접 다룬다.
    -- 목록 보기에서 정렬한 열이 숨겨져 있으면 다시 열 때 이름순으로 돌아가므로 그 열도 켠다.
    -- 대상 창이 맨 앞에 있어야 한다. "항상 ○○ 보기로 열기"를 이번에 켰는지를 돌려준다.
    on keepPerFolder(sortTitle)
        tell application "System Events" to tell process "Finder"
            if not (exists (first window whose subrole is "AXSystemFloatingWindow")) then
                click menu item "보기 옵션" of menu 1 of menu bar item "보기" of menu bar 1
                delay 0.5
            end if
            set panel to first window whose subrole is "AXSystemFloatingWindow"
            set box to first checkbox of panel whose name starts with "항상"
            set toggled to (value of box is 0)
            if toggled then click box
            -- 열 체크박스는 그룹 안에 있어 전체를 뒤진다
            set els to entire contents of panel
            repeat with i from 1 to count of els
                -- 창 내용이 바뀌는 중이면 사라진 요소를 만나 오류가 나므로 건너뛴다
                try
                    set el to item i of els
                    if role of el is "AXCheckBox" and name of el is sortTitle then
                        if value of el is 0 then click el
                        exit repeat
                    end if
                end try
            end repeat
            click (first button of panel whose subrole is "AXCloseButton")
        end tell
        return toggled
    end keepPerFolder

    -- 바로 닫으면 Finder가 설정을 저장하기 전에 버리는 경우가 있다
    on finish(cw, openedHere)
        if openedHere then
            delay 1.5
            tell application "Finder" to close cw
        end if
    end finish


    """

    private static func applyHandler(_ p: Preset) -> String {
        let options = """
            tell application "Finder"
                tell list view options of cw
                    set icon size to \(p.listLargeIcons ? "large icon" : "small icon")
                    set text size to \(p.listTextSize)
                    set calculates folder sizes to \(p.calculatesFolderSizes)
                    set uses relative dates to \(p.usesRelativeDates)
                    set shows icon preview to \(p.listShowsIconPreview)
                end tell
                tell icon view options of cw
                    set icon size to \(p.iconSize)
                    set text size to \(p.iconTextSize)
                    set label position to \(p.labelOnRight ? "right" : "bottom")
                    set shows item info to \(p.showsItemInfo)
                    set shows icon preview to \(p.showsIconPreview)
                end tell
                tell column view options of cw
                    set text size to \(p.columnTextSize)
                    set shows icon to \(p.columnShowsIcon)
                    set shows icon preview to \(p.columnShowsIconPreview)
                    set shows preview column to \(p.showsPreviewColumn)
                end tell
            end tell
        """
        return """
        on applyPreset(t)
            set t to folderOf(t)
            set {cw, openedHere} to windowFor(t)
            tell application "Finder"
                set viewChanged to (current view of cw is not \(p.viewStyle.term))
                set current view of cw to \(p.viewStyle.term)
            end tell
            set m to sortMenu(cw)
            -- 정렬할 열이 켜져 있어야 정렬이 저장되므로 보기 옵션을 정렬보다 먼저 다룬다
            set toggled to keepPerFolder("\(p.sortKey.title)")
            tell application "System Events"
                -- 없음·자동 격자 정렬은 아이콘 보기에만 있어 다른 보기에서는 건너뛴다
                if exists menu item "\(p.sortKey.title)" of m then click menu item "\(p.sortKey.title)" of m
            end tell
            -- 메뉴 정렬이 그 전에 AppleScript로 바꾼 값을 되돌리는 경우가 있어 값은 정렬 뒤에 넣는다
            \(options)
            finish(cw, openedHere)
            -- "항상 ○○ 보기로 열기"를 이번에 켰거나 보기 방식을 바꾼 창에서는 Finder가 AppleScript로
            -- 바꾼 값을 저장하지 않아 한 번 더 적용한다. 두 번째에는 둘 다 그대로라 다시 돌지 않는다.
            if toggled or viewChanged then applyPreset(t)
        end applyPreset


        """
    }

    private static let readHandler = """
    on readPreset(t)
        set t to folderOf(t)
        set {cw, openedHere} to windowFor(t)
        tell application "Finder"
            set folderName to name of (item (t as text))
            set v to current view of cw
            if v is icon view then
                set viewName to "icon"
            else if v is list view then
                set viewName to "list"
            else if v is column view then
                set viewName to "column"
            else
                set viewName to "gallery"
            end if
            set ivo to icon view options of cw
            set lvo to list view options of cw
            set cvo to column view options of cw
            set values to {icon size of ivo, text size of ivo, (label position of ivo is right), shows item info of ivo, shows icon preview of ivo, ¬
                (icon size of lvo is large icon), text size of lvo, calculates folder sizes of lvo, uses relative dates of lvo, shows icon preview of lvo, ¬
                text size of cvo, shows icon of cvo, shows icon preview of cvo, shows preview column of cvo}
        end tell
        set m to sortMenu(cw)
        set sortName to ""
        tell application "System Events"
            repeat with mi in menu items of m
                if value of attribute "AXMenuItemMarkChar" of mi is "✓" then set sortName to name of mi
            end repeat
        end tell
        finish(cw, openedHere)
        return {folderName, viewName, sortName} & values
    end readPreset


    """

    private static func quoted(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static func run(_ source: String) -> (descriptor: NSAppleEventDescriptor?, error: String?) {
        var info: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return (nil, "스크립트를 만들지 못했습니다.") }
        let result = script.executeAndReturnError(&info)
        if let info { return (nil, info[NSAppleScript.errorMessage] as? String ?? "\(info)") }
        return (result, nil)
    }
}
