import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 지도 미리보기를 재사용하기 위한 위젯
///
/// - 위치 기반 일정 등록/수정 화면에서 지도 UI를 반복해서 작성하지 않도록 분리했다.
/// - 초보자도 이해할 수 있도록, 좌표가 없을 때와 있을 때의 처리를 명확하게 주석으로 설명한다.
class MapPreview extends StatelessWidget {
  const MapPreview({
    super.key,
    required this.lat,
    required this.lng,
    required this.radius,
  });

  /// 표시할 위도. null이면 아직 좌표가 준비되지 않은 상태로 본다.
  final double? lat;

  /// 표시할 경도. null이면 아직 좌표가 준비되지 않은 상태로 본다.
  final double? lng;

  /// 반경(미터). 지도 위에 그려지는 원의 크기를 결정한다.
  final double radius;

  @override
  Widget build(BuildContext context) {
    // 1) 좌표가 없는 경우: 사용자에게 안내 문구만 보여준다.
    if (lat == null || lng == null) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('좌표가 설정되면 지도가 표시됩니다.'),
      );
    }

    // 2) 좌표가 있는 경우: FlutterMap을 이용해 간단한 지도를 렌더링한다.
    final position = LatLng(lat!, lng!);
    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: position,
            initialZoom: 16,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            // OpenStreetMap 타일을 이용해 기본 지도 배경을 구성한다.
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.energy_battery',
            ),
            // 사용자가 지정한 반경을 시각적으로 확인할 수 있도록 반투명 원을 추가한다.
            CircleLayer(
              circles: [
                CircleMarker(
                  point: position,
                  color: Colors.blue.withOpacity(0.2),
                  borderStrokeWidth: 2,
                  borderColor: Colors.blue,
                  useRadiusInMeter: true,
                  radius: radius,
                ),
              ],
            ),
            // 중심 좌표에는 빨간 위치 아이콘을 표시해 시선을 집중시킨다.
            MarkerLayer(
              markers: [
                Marker(
                  point: position,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 36,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
