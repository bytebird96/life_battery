import 'package:drift/drift.dart';
import 'package:drift/native.dart'; // NativeDatabase 사용
import 'package:path_provider/path_provider.dart';
import 'dart:io';

part 'app_db.g.dart';

/// 이벤트 테이블 정의
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get startAt => integer()();
  IntColumn get endAt => integer()();
  IntColumn get type => integer()();
  RealColumn get ratePerHour => real().nullable()();
  IntColumn get priority => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 설정 테이블
class Settings extends Table {
  IntColumn get id => integer()();
  RealColumn get initialBattery => real()();
  RealColumn get defaultDrainRate => real()();
  RealColumn get defaultRestRate => real()();
  BoolColumn get sleepFullCharge => boolean()();
  RealColumn get sleepChargeRate => real()();
  RealColumn get minBatteryForWork => real()();
  TextColumn get dayStart => text()();
  BoolColumn get overcapAllowed => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Events, Settings])
class AppDb extends _$AppDb {
  AppDb() : super(_open()); // 로컬 DB 연결 생성

  @override
  int get schemaVersion => 1; // 스키마 버전 관리
}

/// 실제 DB 파일을 열어 NativeDatabase 인스턴스를 반환
LazyDatabase _open() {
  return LazyDatabase(() async {
    // 앱 전용 디렉토리 확보
    final dir = await getApplicationDocumentsDirectory();
    // energy.sqlite 파일 경로 지정
    final file = File('${dir.path}/energy.sqlite');
    // 백그라운드에서 데이터베이스 초기화
    return NativeDatabase.createInBackground(file);
  });
}
