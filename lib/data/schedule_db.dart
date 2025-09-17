import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// 지오펜스 일정/로그를 SQLite에 저장하는 경량 래퍼 클래스
class ScheduleDb {
  static const _dbName = 'geo_schedule.db';
  static const _dbVersion = 2;
  static const scheduleTable = 'schedules';
  static const logTable = 'schedule_logs';

  Database? _db;

  /// DB 초기화(없으면 생성)
  Future<void> init() async {
    if (_db != null) {
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $scheduleTable (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            start_at INTEGER NOT NULL,
            end_at INTEGER NOT NULL,
            use_location INTEGER NOT NULL,
            place_name TEXT,
            lat REAL,
            lng REAL,
            radius_meters REAL,
            trigger_type TEXT NOT NULL,
            day_condition TEXT NOT NULL,
            preset_type TEXT NOT NULL,
            remind_if_not_executed INTEGER NOT NULL,
            executed INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            auto_action TEXT NOT NULL DEFAULT 'NONE'
          )
        ''');
        await db.execute('''
          CREATE TABLE $logTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            schedule_id TEXT,
            message TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2: 자동 실행 동작(auto_action) 컬럼 추가
        if (oldVersion < 2) {
          await db.execute('''
            ALTER TABLE $scheduleTable
            ADD COLUMN auto_action TEXT NOT NULL DEFAULT 'NONE'
          ''');
        }
      },
    );
  }

  Database get _ensureDb {
    final db = _db;
    if (db == null) {
      throw StateError('DB가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return db;
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  /// 저장된 모든 지오펜스 일정을 읽어온다.
  Future<List<Map<String, Object?>>> fetchSchedules() async {
    final db = _ensureDb;
    return db.query(scheduleTable, orderBy: 'start_at ASC');
  }

  /// 일정 데이터를 INSERT OR REPLACE로 저장
  Future<void> upsertSchedule(Map<String, Object?> data) async {
    final db = _ensureDb;
    await db.insert(
      scheduleTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// ID로 일정 삭제
  Future<void> deleteSchedule(String id) async {
    final db = _ensureDb;
    await db.delete(scheduleTable, where: 'id = ?', whereArgs: [id]);
  }

  /// 실행 완료 여부만 빠르게 갱신하는 쿼리
  Future<void> updateExecuted(String id, bool executed) async {
    final db = _ensureDb;
    await db.update(
      scheduleTable,
      {
        'executed': executed ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 단일 일정 조회
  Future<Map<String, Object?>?> fetchScheduleById(String id) async {
    final db = _ensureDb;
    final rows = await db.query(scheduleTable, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  /// 로그 삽입 (생성된 rowId 반환)
  Future<int> insertLog(Map<String, Object?> data) async {
    final db = _ensureDb;
    return db.insert(logTable, data);
  }

  /// 최근 로그 조회 (기본 50개)
  Future<List<Map<String, Object?>>> fetchLogs({int limit = 50}) async {
    final db = _ensureDb;
    return db.query(
      logTable,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  /// 오래된 로그를 삭제하여 저장 공간을 제한한다.
  Future<void> trimLogs(int max) async {
    final db = _ensureDb;
    await db.rawDelete('''
      DELETE FROM $logTable
      WHERE id NOT IN (
        SELECT id FROM $logTable ORDER BY created_at DESC LIMIT ?
      )
    ''', [max]);
  }
}
