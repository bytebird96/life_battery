import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
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
  AppDb() : super(_open());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/energy.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
