import 'package:flutter/material.dart';

import '../../data/models.dart';

/// 일정 등록/수정 화면에서 사용할 아이콘 선택 옵션
///
/// - [name]은 저장용 문자열 키 (SharedPreferences 등에 저장)
/// - [icon]은 실제 머티리얼 아이콘 데이터
/// - [label]은 사용자에게 보여줄 짧은 설명 텍스트
class EventIconOption {
  final String name;
  final IconData icon;
  final String label;

  const EventIconOption({
    required this.name,
    required this.icon,
    required this.label,
  });
}

/// 사용자에게 제공할 아이콘 후보 목록
///
/// - 기본값은 [defaultEventIconName]과 동일한 'work'
/// - 필요에 따라 새로운 아이콘을 뒤에 추가하면 된다.
const List<EventIconOption> eventIconOptions = [
  EventIconOption(
    name: 'work',
    icon: Icons.computer,
    label: '작업',
  ),
  EventIconOption(
    name: 'meeting',
    icon: Icons.groups,
    label: '회의',
  ),
  EventIconOption(
    name: 'study',
    icon: Icons.menu_book,
    label: '공부',
  ),
  EventIconOption(
    name: 'exercise',
    icon: Icons.fitness_center,
    label: '운동',
  ),
  EventIconOption(
    name: 'rest',
    icon: Icons.self_improvement,
    label: '휴식',
  ),
  EventIconOption(
    name: 'sleep',
    icon: Icons.nightlight_round,
    label: '수면',
  ),
];

/// 문자열 키에 대응되는 아이콘을 찾아 반환하는 헬퍼
///
/// - 저장된 값이 없거나 목록에 없는 경우 기본 아이콘을 돌려준다.
IconData iconDataFromName(String name) {
  final fallback = eventIconOptions.firstWhere(
    (option) => option.name == defaultEventIconName,
    orElse: () => eventIconOptions.first,
  );
  return eventIconOptions
          .firstWhere(
            (option) => option.name == name,
            orElse: () => fallback,
          )
          .icon;
}

/// 문자열 키에 대응되는 라벨(텍스트)을 반환하는 헬퍼
String labelFromIconName(String name) {
  final fallback = eventIconOptions.firstWhere(
    (option) => option.name == defaultEventIconName,
    orElse: () => eventIconOptions.first,
  );
  return eventIconOptions
      .firstWhere(
        (option) => option.name == name,
        orElse: () => fallback,
      )
      .label;
}
