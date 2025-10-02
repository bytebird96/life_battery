import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // ▼ 위치 이벤트(지오펜스)로 인해 앱이 깨워졌다면 즉시 백그라운드 엔진을 준비한다.
    if launchOptions?[.location] != nil {
      GeofenceBackgroundEngine.shared.startIfNeeded()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    // ▼ 사용자가 앱을 완전히 종료하지 않았더라도, 백그라운드 전환 시 헤드리스 엔진을 켜 두면
    //   iOS가 프로세스를 정리한 뒤에도 지오펜스 이벤트를 바로 처리할 준비를 갖출 수 있다.
    GeofenceBackgroundEngine.shared.startIfNeeded()
  }
}
