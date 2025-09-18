import 'dart:io';

import 'platform_helper_base.dart';

/// `dart:io`를 사용할 수 있는 환경(안드로이드/iOS/데스크톱 등)에서의 구현체
class IoPlatformHelper implements PlatformHelper {
  @override
  bool get isAndroid => Platform.isAndroid; // 안드로이드 단말인지 직접 확인

  @override
  Future<int?> getAndroidSdkInt() async {
    if (!Platform.isAndroid) {
      // 안드로이드가 아니라면 SDK 버전 자체가 의미가 없으므로 null 반환
      return null;
    }

    final versionString = Platform.operatingSystemVersion;

    // 대표적인 문자열 예시: "Android 13 (API 33)"
    final apiMatch =
        RegExp('API(?:\\s+Level)?\\s*(\\d+)').firstMatch(versionString);
    if (apiMatch != null) {
      // 정규식에서 추출한 숫자를 정수로 변환하여 반환
      return int.tryParse(apiMatch.group(1)!);
    }

    // 제조사에 따라 "SDK 33"과 같은 표현을 쓰기도 하므로 보조 정규식을 한 번 더 확인
    final sdkMatch = RegExp('SDK\\s*(\\d+)').firstMatch(versionString);
    if (sdkMatch != null) {
      return int.tryParse(sdkMatch.group(1)!);
    }

    return null; // 어떤 패턴에도 맞지 않으면 null 반환하여 상위 로직에서 안전하게 처리
  }
}

/// 조건부 임포트에서 사용할 헬퍼 생성 함수
PlatformHelper getPlatformHelper() => IoPlatformHelper();
