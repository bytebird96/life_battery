// ignore_for_file: type=lint
part of 'app_db.dart';

/// Drift가 생성하는 최소한의 스텁 클래스
abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  late final Events events = Events();
  late final Settings settings = Settings();
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => [events, settings];
}
