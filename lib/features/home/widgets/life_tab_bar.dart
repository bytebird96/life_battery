import 'package:flutter/material.dart';

/// 하단 탭바를 표현하는 위젯
///
/// 디자인 시안(CSS)에서 전달된 구조를 최대한 그대로 Flutter로 옮겼다.
/// 가운데 + 버튼을 누르면 [onAdd] 콜백이 실행된다.
/// 왼쪽 시계 아이콘을 누르면 [onClock] 콜백이 실행된다.
class LifeTabBar extends StatelessWidget {
  /// + 버튼을 눌렀을 때 실행할 함수
  final VoidCallback onAdd;

  /// 왼쪽 시계 아이콘을 눌렀을 때 실행할 함수
  final VoidCallback onClock;

  /// 오른쪽 파이차트 아이콘을 눌렀을 때 실행할 함수
  final VoidCallback onReport;

  const LifeTabBar({
    super.key,
    required this.onAdd,
    required this.onClock,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 295, // CSS에서 지정한 폭
      height: 76, // CSS에서 지정한 높이
      child: Stack(
        children: [
          // 왼쪽 하단 시계 아이콘 영역
          Positioned(
            left: 0,
            top: 8,
            child: Opacity(
              opacity: 0.4, // CSS에서 설정된 투명도
              child: IconButton(
                icon: const Icon(Icons.access_time_outlined, size: 28),
                // 아이콘을 누르면 전달받은 콜백 실행
                onPressed: onClock,
              ),
            ),
          ),
          // 오른쪽 하단 파이차트 아이콘 영역
          Positioned(
            right: 0,
            top: 8,
            child: Opacity(
              opacity: 0.4,
              child: IconButton(
                icon: const Icon(Icons.pie_chart_outline, size: 28),
                onPressed: onReport, // 우측 아이콘을 누르면 리포트 화면으로 이동
              ),
            ),
          ),
          // 가운데 + 버튼
          Positioned(
            left: (295 - 44) / 2, // 전체 폭에서 버튼 크기를 뺀 후 절반 이동
            top: 0,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ),
          ),
          // 하단의 홈 인디케이터 (회색 바)
          Positioned(
            left: 80,
            bottom: 0,
            child: Container(
              width: 135,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFF3C3C3C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
