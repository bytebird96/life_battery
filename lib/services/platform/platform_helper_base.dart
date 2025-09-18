/// 플랫폼 관련 공통 인터페이스를 정의한 파일
///
/// 웹/모바일 각각의 구현 파일에서 `PlatformHelper`를 구현하고,
/// 조건부 임포트를 통해 적절한 구현을 사용할 수 있도록 분리한다.
abstract class PlatformHelper {
  /// 현재 플랫폼이 안드로이드인지 여부
  bool get isAndroid;

  /// 안드로이드 SDK 버전 (웹 및 비안드로이드 플랫폼에서는 null 반환)
  Future<int?> getAndroidSdkInt();
}
