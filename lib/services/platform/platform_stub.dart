import 'platform_helper_base.dart';

/// 웹을 비롯한 `dart:io`가 사용 불가능한 환경에서 사용할 구현체
class WebPlatformHelper implements PlatformHelper {
  @override
  bool get isAndroid => false; // 웹에서는 절대 안드로이드가 아니므로 false 고정

  @override
  Future<int?> getAndroidSdkInt() async {
    // 웹에서는 안드로이드 SDK 개념이 없으므로 null 반환
    return null;
  }
}

/// 조건부 임포트에서 사용할 헬퍼 생성 함수
PlatformHelper getPlatformHelper() => WebPlatformHelper();
