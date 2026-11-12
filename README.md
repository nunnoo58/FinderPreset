# FinderPreset

Finder 폴더 보기 설정을 프리셋으로 저장해 두고, Finder 우클릭 메뉴에서 바로 적용하는 macOS 앱이다.

## 기능

- 우클릭 → 보기 프리셋에서 프리셋을 골라 폴더에 바로 적용
- 설정은 폴더마다 따로 저장되어 다른 폴더에 영향을 주지 않음
- 하위 폴더까지 적용: 지금 있는 하위 폴더 전체에 한 번에 적용(일회성 복사이며, 나중에 만든 폴더는 따르지 않음)
- 현재 보기를 프리셋으로 저장: 지금 보고 있는 폴더의 설정을 새 프리셋으로 저장
- 앱 창에서 프리셋 추가, 편집, 삭제, 순서 변경

### 프리셋에 담기는 항목

| 구분 | 항목 |
| --- | --- |
| 기본 | 보기 방식(아이콘, 목록, 계층, 갤러리), 정렬 기준 |
| 아이콘 보기 | 아이콘 크기, 텍스트 크기, 레이블 위치, 항목 정보, 아이콘 미리보기 |
| 목록 보기 | 아이콘 크기, 텍스트 크기, 상대적 날짜, 모든 크기 계산, 아이콘 미리보기 |
| 계층 보기 | 텍스트 크기, 아이콘, 아이콘 미리보기, 미리보기 열 |

정렬 기준: 없음, 자동 격자 정렬(아이콘 보기 전용), 이름, 종류, 최근 사용일, 추가된 날짜, 수정일, 생성일, 크기, 태그

## 요구 사항

- macOS 15 이상
- macOS 언어가 한국어여야 함(Finder 메뉴 이름으로 정렬과 보기 옵션을 다루기 때문)

## 설치

1. [Releases](https://github.com/nunnoo58/FinderPreset/releases)에서 `FinderPresets-x.x.zip`을 받아 압축을 푼다.
2. `FinderPresets.app`을 `/응용 프로그램` 폴더로 옮긴다.
3. 처음 실행할 때는 앱을 우클릭 → 열기로 연다. 자체 서명 앱이라 Gatekeeper 경고가 뜬다.
4. 앱 상단에 확장이 꺼져 있다는 안내가 보이면 "확장 켜기"를 눌러 Finder 확장을 켠다.

## 권한

처음 적용할 때 뜨는 확인 창에서 모두 허용해야 한다.

- 자동화: Finder, System Events 제어
- 손쉬운 사용: 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 "Finder 프리셋"을 켠다.

앱 본체와 Finder 확장이 각각 권한을 요청한다.

## 사용법

| 동작 | 방법 |
| --- | --- |
| 지금 보는 폴더에 적용 | 창의 빈 곳 우클릭 → 보기 프리셋 → 프리셋 선택 |
| 특정 폴더에 적용 | 폴더 우클릭 → 보기 프리셋 → 프리셋 선택 |
| 하위 폴더까지 적용 | 우클릭 → 보기 프리셋 → 하위 폴더까지 적용 → 프리셋 선택 |
| 현재 보기 저장 | 우클릭 → 보기 프리셋 → 현재 보기를 프리셋으로 저장… |
| 프리셋 편집 | 우클릭 → 보기 프리셋 → 프리셋 편집…, 또는 앱 실행 |

파일을 우클릭하면 그 파일이 들어 있는 폴더에 적용된다.

## 알려진 제약

- 적용하는 동안 대상 폴더 창이 앞으로 오고 보기 옵션 창이 잠깐 나타난다. 그동안 Finder를 조작하지 않아야 한다.
- 폴더 하나에 3~6초 걸린다. 처음 다루는 폴더는 한 번 더 적용하느라 더 걸린다.
- 정렬 방향은 Finder 기본값을 따른다(날짜·크기는 큰 값부터, 이름은 가나다순).
- 목록 보기의 열 표시와 배경색은 지원하지 않는다. Finder가 AppleScript로 바꾼 값을 반영하지 않는다.

## 동작 방식

macOS 15 이후 Finder는 AppleScript로 바꾼 정렬, 열 표시, 배경색을 화면에 반영하지 않는다. 그래서 다음처럼 섞어서 쓴다.

- AppleScript: 보기 방식, 아이콘·텍스트 크기 등 반영되는 항목
- UI 스크립팅(System Events):
  - 보기 → 다음으로 정렬 메뉴를 눌러 정렬한다.
  - 보기 옵션의 "항상 ○○ 보기로 열기"를 켜서 설정이 폴더별로 저장되게 한다.

프리셋은 `~/Library/Application Support/FinderPresets/presets.json`에 저장되고, 앱과 Finder 확장이 함께 쓴다.

## 소스에서 빌드

[XcodeGen](https://github.com/yonaskolb/XcodeGen)과 Xcode가 필요하다.

```sh
brew install xcodegen
git clone https://github.com/nunnoo58/FinderPreset.git
cd FinderPreset
```

`project.yml`의 `CODE_SIGN_IDENTITY`를 자기 코드 서명 인증서 이름으로 바꾼다. 인증서 없이 빌드하려면 `CODE_SIGN_IDENTITY: "-"`(ad-hoc)로 바꾼다. 다만 ad-hoc 서명은 빌드할 때마다 권한을 다시 허용해야 한다.

```sh
xcodegen generate
xcodebuild -project FinderPresets.xcodeproj -scheme FinderPresets -configuration Release -derivedDataPath build build
cp -R build/Build/Products/Release/FinderPresets.app /Applications/
```

## 기여

풀 리퀘스트는 받지 않는다. 버그나 제안은 [Issues](https://github.com/nunnoo58/FinderPreset/issues)로 남긴다.

## 라이선스

[CC BY-ND 4.0](https://creativecommons.org/licenses/by-nd/4.0/deed.ko)

- 저작자를 표시하면 상업적 이용을 포함해 복제·배포할 수 있다.
- 수정하거나 이를 바탕으로 만든 2차 저작물은 배포할 수 없다.
