import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 배터리 퍼센트를 관리하는 컨트롤러
/// - 실시간으로 퍼센트 값을 변경하기 위해 [Timer]를 사용
class BatteryController extends StateNotifier<double> {
  Timer? _timer; // 주기적으로 배터리를 갱신하는 타이머
  BatteryController(double initial) : super(initial);

  /// 작업을 시작하여 일정 시간 동안 배터리를 증감
  /// [ratePerHour] 시간당 퍼센트 변화량(음수 가능)
  /// [duration] 작업 총 소요 시간
  void startTask({required double ratePerHour, required Duration duration}) {
    _timer?.cancel();
    var seconds = duration.inSeconds; // 남은 초
    final perSecond = ratePerHour / 3600; // 초당 퍼센트 변화량

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // 배터리 업데이트
      state += perSecond;
      if (state > 100) state = 100; // 최대 100%로 제한
      if (state < 0) state = 0; // 최소 0%

      seconds--;
      if (seconds <= 0) {
        timer.cancel(); // 시간이 끝나면 타이머 종료
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
