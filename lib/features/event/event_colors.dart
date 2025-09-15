import 'package:flutter/material.dart';

import '../../data/models.dart';

/// 일정 등록/수정 화면에서 사용할 색상 선택 옵션을 정의하는 클래스
///
/// - [name]은 저장 및 복원을 위한 문자열 키 (SharedPreferences 등에 저장)
/// - [color]는 실제로 사용할 머티리얼 [Color] 객체
/// - [label]은 사용자에게 보여줄 짧은 설명 텍스트
class EventColorOption {
  final String name; // 고유 식별자 (문자열)
  final Color color; // 실제로 적용할 색상 값
  final String label; // 색상 이름을 사용자에게 보여줄 때 사용

  const EventColorOption({
    required this.name,
    required this.color,
    required this.label,
  });
}

/// 사용자에게 제공할 색상 후보 목록
///
/// - 첫 번째 항목은 [defaultEventColorName]과 동일한 'purple'이다.
/// - 색상을 추가하고 싶다면 리스트 끝에 새로운 옵션을 추가하면 된다.
const List<EventColorOption> eventColorOptions = [
  EventColorOption(
    name: 'purple',
    color: Color(0xFF9B51E0),
    label: '보라색',
  ),
  EventColorOption(
    name: 'blue',
    color: Color(0xFF2D9CDB),
    label: '파란색',
  ),
  EventColorOption(
    name: 'green',
    color: Color(0xFF27AE60),
    label: '초록색',
  ),
  EventColorOption(
    name: 'orange',
    color: Color(0xFFF2994A),
    label: '주황색',
  ),
  EventColorOption(
    name: 'pink',
    color: Color(0xFFEB5757),
    label: '핑크색',
  ),
  EventColorOption(
    name: 'gray',
    color: Color(0xFF4F4F4F),
    label: '회색',
  ),
];

/// 문자열 키에 대응되는 색상을 반환하는 헬퍼 함수
///
/// - 목록에 없는 키가 들어오면 기본 색상([defaultEventColorName])을 반환한다.
Color colorFromName(String name) {
  final fallback = eventColorOptions.firstWhere(
    (option) => option.name == defaultEventColorName,
    orElse: () => eventColorOptions.first,
  );
  return eventColorOptions
      .firstWhere(
        (option) => option.name == name,
        orElse: () => fallback,
      )
      .color;
}

/// 문자열 키에 대응되는 라벨 텍스트를 반환하는 헬퍼 함수
String labelFromColorName(String name) {
  final fallback = eventColorOptions.firstWhere(
    (option) => option.name == defaultEventColorName,
    orElse: () => eventColorOptions.first,
  );
  return eventColorOptions
      .firstWhere(
        (option) => option.name == name,
        orElse: () => fallback,
      )
      .label;
}
