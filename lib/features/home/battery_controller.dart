import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories.dart';

/// 배터리 퍼센트를 관리하는 컨트롤러
/// - 실시간으로 퍼센트 값을 변경하기 위해 [Timer]를 사용
class BatteryController extends StateNotifier<double> {
  Timer? _timer; // 주기적으로 배터리를 갱신하는 타이머

  BatteryController(double initial) : super(initial);

  /// 작업을 시작하여 일정 시간 동안 배터리를 증감
  /// [ratePerHour] 시간당 퍼센트 변화량(음수 가능)
  /// [duration] 남은 작업 시간
  /// - 중지 후 다시 호출하면 남은 시간을 전달해 이어서 진행할 수 있음
  void startTask({required double ratePerHour, required Duration duration}) {
    stop(); // 기존 타이머가 있으면 정지
    var seconds = duration.inSeconds; // 남은 초
    final perSecond = ratePerHour / 3600; // 초당 퍼센트 변화량

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // 배터리 업데이트
      state += perSecond;
      if (state > 100) state = 100; // 최대 100%로 제한
      if (state < 0) state = 0; // 최소 0%

      seconds--;
      if (seconds <= 0) {
        stop(); // 시간이 끝나면 타이머 종료
      }
    });
  }

  /// 진행 중인 작업을 중지하고 타이머 해제
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 현재 작업이 실행 중인지 여부
  bool get isRunning => _timer != null;

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// 배터리 컨트롤러 프로바이더
/// - 리포지토리의 초기 배터리를 사용하여 생성
final batteryControllerProvider =
    StateNotifierProvider<BatteryController, double>((ref) {
  final repo = ref.read(repositoryProvider);
  return BatteryController(repo.settings.initialBattery);
});
