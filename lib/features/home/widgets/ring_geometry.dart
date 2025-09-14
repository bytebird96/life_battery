import 'dart:ui';

/// 링을 그릴 때 공통으로 사용하는 지오메트리를 계산하는 클래스
/// size(지름)와 thickness(두께)를 입력하면
/// 중앙 좌표와 반경, drawArc에 필요한 사각형(Rect)을 제공한다.
class RingGeometry {
  /// 링의 전체 지름
  final double size;

  /// 스트로크의 두께
  final double thickness;

  /// 원의 중심 좌표
  final Offset center;

  /// 스트로크 중심이 도는 반경
  final double radius;

  /// drawArc에 그대로 넘길 수 있는 사각형
  final Rect rect;

  /// [size]는 링의 전체 지름, [thickness]는 스트로크 두께를 의미한다.
  RingGeometry(this.size, this.thickness)
      : center = Offset(size / 2, size / 2),
        radius = (size - thickness) / 2,
        rect = Rect.fromCircle(
          center: Offset(size / 2, size / 2),
          radius: (size - thickness) / 2,
        );
}
