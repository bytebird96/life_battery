import 'platform_helper_base.dart';
import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';

/// 조건부 임포트를 통해 실제 플랫폼에 맞는 구현체를 선택한다.
///
/// 다른 파일에서는 `platformHelper`만 가져다 쓰면 플랫폼 분기 처리가 자동으로 된다.
final PlatformHelper platformHelper = getPlatformHelper();
