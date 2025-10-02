import Flutter
import Foundation

/// 지오펜스 이벤트가 앱을 깨웠을 때 사용할 전용 Flutter 엔진을 관리한다.
final class GeofenceBackgroundEngine {
  static let shared = GeofenceBackgroundEngine()

  /// 이미 엔진이 동작 중인지 확인하기 위한 보관 프로퍼티
  private var engine: FlutterEngine?

  private init() {}

  /// iOS가 위치 이벤트로 앱을 실행했을 때 호출해 헤드리스 엔진을 켠다.
  func startIfNeeded() {
    // ▼ 이미 생성되어 있다면 재실행할 필요가 없다.
    if engine != nil {
      return
    }

    // ▼ allowHeadlessExecution을 true로 지정해야 UI 없이도 엔진을 띄울 수 있다.
    let backgroundEngine = FlutterEngine(
      name: "geofence_background_engine",
      project: nil,
      allowHeadlessExecution: true
    )

    // ▼ Dart 쪽에 만들어 둔 geofenceBackgroundMain 엔트리 포인트를 실행한다.
    let didRun = backgroundEngine.run(
      withEntrypoint: "geofenceBackgroundMain",
      libraryURI: "package:energy_battery/background/geofence_background.dart"
    )

    guard didRun else {
      NSLog("[GeofenceBackgroundEngine] 헤드리스 엔진 실행에 실패했습니다.")
      return
    }

    // ▼ 플러그인 채널을 사용할 수 있도록 자동 생성된 등록 코드를 호출한다.
    GeneratedPluginRegistrant.register(with: backgroundEngine)

    engine = backgroundEngine
  }
}
