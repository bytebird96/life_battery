// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $EventsTable extends Events with TableInfo<$EventsTable, Event> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startAtMeta =
      const VerificationMeta('startAt');
  @override
  late final GeneratedColumn<int> startAt = GeneratedColumn<int>(
      'start_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<int> endAt = GeneratedColumn<int>(
      'end_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
      'type', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _ratePerHourMeta =
      const VerificationMeta('ratePerHour');
  @override
  late final GeneratedColumn<double> ratePerHour = GeneratedColumn<double>(
      'rate_per_hour', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
      'priority', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        startAt,
        endAt,
        type,
        ratePerHour,
        priority,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(Insertable<Event> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('start_at')) {
      context.handle(_startAtMeta,
          startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta));
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
          _endAtMeta, endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta));
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('rate_per_hour')) {
      context.handle(
          _ratePerHourMeta,
          ratePerHour.isAcceptableOrUnknown(
              data['rate_per_hour']!, _ratePerHourMeta));
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Event map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Event(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      startAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_at'])!,
      endAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end_at'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!,
      ratePerHour: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}rate_per_hour']),
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}priority'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }
}

class Event extends DataClass implements Insertable<Event> {
  final String id;
  final String title;
  final int startAt;
  final int endAt;
  final int type;
  final double? ratePerHour;
  final int priority;
  final int createdAt;
  final int updatedAt;
  const Event(
      {required this.id,
      required this.title,
      required this.startAt,
      required this.endAt,
      required this.type,
      this.ratePerHour,
      required this.priority,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['start_at'] = Variable<int>(startAt);
    map['end_at'] = Variable<int>(endAt);
    map['type'] = Variable<int>(type);
    if (!nullToAbsent || ratePerHour != null) {
      map['rate_per_hour'] = Variable<double>(ratePerHour);
    }
    map['priority'] = Variable<int>(priority);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      title: Value(title),
      startAt: Value(startAt),
      endAt: Value(endAt),
      type: Value(type),
      ratePerHour: ratePerHour == null && nullToAbsent
          ? const Value.absent()
          : Value(ratePerHour),
      priority: Value(priority),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Event.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Event(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      startAt: serializer.fromJson<int>(json['startAt']),
      endAt: serializer.fromJson<int>(json['endAt']),
      type: serializer.fromJson<int>(json['type']),
      ratePerHour: serializer.fromJson<double?>(json['ratePerHour']),
      priority: serializer.fromJson<int>(json['priority']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'startAt': serializer.toJson<int>(startAt),
      'endAt': serializer.toJson<int>(endAt),
      'type': serializer.toJson<int>(type),
      'ratePerHour': serializer.toJson<double?>(ratePerHour),
      'priority': serializer.toJson<int>(priority),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Event copyWith(
          {String? id,
          String? title,
          int? startAt,
          int? endAt,
          int? type,
          Value<double?> ratePerHour = const Value.absent(),
          int? priority,
          int? createdAt,
          int? updatedAt}) =>
      Event(
        id: id ?? this.id,
        title: title ?? this.title,
        startAt: startAt ?? this.startAt,
        endAt: endAt ?? this.endAt,
        type: type ?? this.type,
        ratePerHour: ratePerHour.present ? ratePerHour.value : this.ratePerHour,
        priority: priority ?? this.priority,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Event copyWithCompanion(EventsCompanion data) {
    return Event(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      type: data.type.present ? data.type.value : this.type,
      ratePerHour:
          data.ratePerHour.present ? data.ratePerHour.value : this.ratePerHour,
      priority: data.priority.present ? data.priority.value : this.priority,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Event(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('type: $type, ')
          ..write('ratePerHour: $ratePerHour, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, startAt, endAt, type, ratePerHour,
      priority, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Event &&
          other.id == this.id &&
          other.title == this.title &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.type == this.type &&
          other.ratePerHour == this.ratePerHour &&
          other.priority == this.priority &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class EventsCompanion extends UpdateCompanion<Event> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> startAt;
  final Value<int> endAt;
  final Value<int> type;
  final Value<double?> ratePerHour;
  final Value<int> priority;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.type = const Value.absent(),
    this.ratePerHour = const Value.absent(),
    this.priority = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsCompanion.insert({
    required String id,
    required String title,
    required int startAt,
    required int endAt,
    required int type,
    this.ratePerHour = const Value.absent(),
    required int priority,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        startAt = Value(startAt),
        endAt = Value(endAt),
        type = Value(type),
        priority = Value(priority),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Event> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? startAt,
    Expression<int>? endAt,
    Expression<int>? type,
    Expression<double>? ratePerHour,
    Expression<int>? priority,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (type != null) 'type': type,
      if (ratePerHour != null) 'rate_per_hour': ratePerHour,
      if (priority != null) 'priority': priority,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<int>? startAt,
      Value<int>? endAt,
      Value<int>? type,
      Value<double?>? ratePerHour,
      Value<int>? priority,
      Value<int>? createdAt,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return EventsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      type: type ?? this.type,
      ratePerHour: ratePerHour ?? this.ratePerHour,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<int>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<int>(endAt.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (ratePerHour.present) {
      map['rate_per_hour'] = Variable<double>(ratePerHour.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('type: $type, ')
          ..write('ratePerHour: $ratePerHour, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _initialBatteryMeta =
      const VerificationMeta('initialBattery');
  @override
  late final GeneratedColumn<double> initialBattery = GeneratedColumn<double>(
      'initial_battery', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _defaultDrainRateMeta =
      const VerificationMeta('defaultDrainRate');
  @override
  late final GeneratedColumn<double> defaultDrainRate = GeneratedColumn<double>(
      'default_drain_rate', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _defaultRestRateMeta =
      const VerificationMeta('defaultRestRate');
  @override
  late final GeneratedColumn<double> defaultRestRate = GeneratedColumn<double>(
      'default_rest_rate', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _sleepFullChargeMeta =
      const VerificationMeta('sleepFullCharge');
  @override
  late final GeneratedColumn<bool> sleepFullCharge = GeneratedColumn<bool>(
      'sleep_full_charge', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("sleep_full_charge" IN (0, 1))'));
  static const VerificationMeta _sleepChargeRateMeta =
      const VerificationMeta('sleepChargeRate');
  @override
  late final GeneratedColumn<double> sleepChargeRate = GeneratedColumn<double>(
      'sleep_charge_rate', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _minBatteryForWorkMeta =
      const VerificationMeta('minBatteryForWork');
  @override
  late final GeneratedColumn<double> minBatteryForWork =
      GeneratedColumn<double>('min_battery_for_work', aliasedName, false,
          type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _dayStartMeta =
      const VerificationMeta('dayStart');
  @override
  late final GeneratedColumn<String> dayStart = GeneratedColumn<String>(
      'day_start', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _overcapAllowedMeta =
      const VerificationMeta('overcapAllowed');
  @override
  late final GeneratedColumn<bool> overcapAllowed = GeneratedColumn<bool>(
      'overcap_allowed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("overcap_allowed" IN (0, 1))'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        initialBattery,
        defaultDrainRate,
        defaultRestRate,
        sleepFullCharge,
        sleepChargeRate,
        minBatteryForWork,
        dayStart,
        overcapAllowed
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('initial_battery')) {
      context.handle(
          _initialBatteryMeta,
          initialBattery.isAcceptableOrUnknown(
              data['initial_battery']!, _initialBatteryMeta));
    } else if (isInserting) {
      context.missing(_initialBatteryMeta);
    }
    if (data.containsKey('default_drain_rate')) {
      context.handle(
          _defaultDrainRateMeta,
          defaultDrainRate.isAcceptableOrUnknown(
              data['default_drain_rate']!, _defaultDrainRateMeta));
    } else if (isInserting) {
      context.missing(_defaultDrainRateMeta);
    }
    if (data.containsKey('default_rest_rate')) {
      context.handle(
          _defaultRestRateMeta,
          defaultRestRate.isAcceptableOrUnknown(
              data['default_rest_rate']!, _defaultRestRateMeta));
    } else if (isInserting) {
      context.missing(_defaultRestRateMeta);
    }
    if (data.containsKey('sleep_full_charge')) {
      context.handle(
          _sleepFullChargeMeta,
          sleepFullCharge.isAcceptableOrUnknown(
              data['sleep_full_charge']!, _sleepFullChargeMeta));
    } else if (isInserting) {
      context.missing(_sleepFullChargeMeta);
    }
    if (data.containsKey('sleep_charge_rate')) {
      context.handle(
          _sleepChargeRateMeta,
          sleepChargeRate.isAcceptableOrUnknown(
              data['sleep_charge_rate']!, _sleepChargeRateMeta));
    } else if (isInserting) {
      context.missing(_sleepChargeRateMeta);
    }
    if (data.containsKey('min_battery_for_work')) {
      context.handle(
          _minBatteryForWorkMeta,
          minBatteryForWork.isAcceptableOrUnknown(
              data['min_battery_for_work']!, _minBatteryForWorkMeta));
    } else if (isInserting) {
      context.missing(_minBatteryForWorkMeta);
    }
    if (data.containsKey('day_start')) {
      context.handle(_dayStartMeta,
          dayStart.isAcceptableOrUnknown(data['day_start']!, _dayStartMeta));
    } else if (isInserting) {
      context.missing(_dayStartMeta);
    }
    if (data.containsKey('overcap_allowed')) {
      context.handle(
          _overcapAllowedMeta,
          overcapAllowed.isAcceptableOrUnknown(
              data['overcap_allowed']!, _overcapAllowedMeta));
    } else if (isInserting) {
      context.missing(_overcapAllowedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      initialBattery: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}initial_battery'])!,
      defaultDrainRate: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}default_drain_rate'])!,
      defaultRestRate: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}default_rest_rate'])!,
      sleepFullCharge: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}sleep_full_charge'])!,
      sleepChargeRate: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}sleep_charge_rate'])!,
      minBatteryForWork: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}min_battery_for_work'])!,
      dayStart: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}day_start'])!,
      overcapAllowed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}overcap_allowed'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final int id;
  final double initialBattery;
  final double defaultDrainRate;
  final double defaultRestRate;
  final bool sleepFullCharge;
  final double sleepChargeRate;
  final double minBatteryForWork;
  final String dayStart;
  final bool overcapAllowed;
  const Setting(
      {required this.id,
      required this.initialBattery,
      required this.defaultDrainRate,
      required this.defaultRestRate,
      required this.sleepFullCharge,
      required this.sleepChargeRate,
      required this.minBatteryForWork,
      required this.dayStart,
      required this.overcapAllowed});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['initial_battery'] = Variable<double>(initialBattery);
    map['default_drain_rate'] = Variable<double>(defaultDrainRate);
    map['default_rest_rate'] = Variable<double>(defaultRestRate);
    map['sleep_full_charge'] = Variable<bool>(sleepFullCharge);
    map['sleep_charge_rate'] = Variable<double>(sleepChargeRate);
    map['min_battery_for_work'] = Variable<double>(minBatteryForWork);
    map['day_start'] = Variable<String>(dayStart);
    map['overcap_allowed'] = Variable<bool>(overcapAllowed);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      initialBattery: Value(initialBattery),
      defaultDrainRate: Value(defaultDrainRate),
      defaultRestRate: Value(defaultRestRate),
      sleepFullCharge: Value(sleepFullCharge),
      sleepChargeRate: Value(sleepChargeRate),
      minBatteryForWork: Value(minBatteryForWork),
      dayStart: Value(dayStart),
      overcapAllowed: Value(overcapAllowed),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      id: serializer.fromJson<int>(json['id']),
      initialBattery: serializer.fromJson<double>(json['initialBattery']),
      defaultDrainRate: serializer.fromJson<double>(json['defaultDrainRate']),
      defaultRestRate: serializer.fromJson<double>(json['defaultRestRate']),
      sleepFullCharge: serializer.fromJson<bool>(json['sleepFullCharge']),
      sleepChargeRate: serializer.fromJson<double>(json['sleepChargeRate']),
      minBatteryForWork: serializer.fromJson<double>(json['minBatteryForWork']),
      dayStart: serializer.fromJson<String>(json['dayStart']),
      overcapAllowed: serializer.fromJson<bool>(json['overcapAllowed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'initialBattery': serializer.toJson<double>(initialBattery),
      'defaultDrainRate': serializer.toJson<double>(defaultDrainRate),
      'defaultRestRate': serializer.toJson<double>(defaultRestRate),
      'sleepFullCharge': serializer.toJson<bool>(sleepFullCharge),
      'sleepChargeRate': serializer.toJson<double>(sleepChargeRate),
      'minBatteryForWork': serializer.toJson<double>(minBatteryForWork),
      'dayStart': serializer.toJson<String>(dayStart),
      'overcapAllowed': serializer.toJson<bool>(overcapAllowed),
    };
  }

  Setting copyWith(
          {int? id,
          double? initialBattery,
          double? defaultDrainRate,
          double? defaultRestRate,
          bool? sleepFullCharge,
          double? sleepChargeRate,
          double? minBatteryForWork,
          String? dayStart,
          bool? overcapAllowed}) =>
      Setting(
        id: id ?? this.id,
        initialBattery: initialBattery ?? this.initialBattery,
        defaultDrainRate: defaultDrainRate ?? this.defaultDrainRate,
        defaultRestRate: defaultRestRate ?? this.defaultRestRate,
        sleepFullCharge: sleepFullCharge ?? this.sleepFullCharge,
        sleepChargeRate: sleepChargeRate ?? this.sleepChargeRate,
        minBatteryForWork: minBatteryForWork ?? this.minBatteryForWork,
        dayStart: dayStart ?? this.dayStart,
        overcapAllowed: overcapAllowed ?? this.overcapAllowed,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      id: data.id.present ? data.id.value : this.id,
      initialBattery: data.initialBattery.present
          ? data.initialBattery.value
          : this.initialBattery,
      defaultDrainRate: data.defaultDrainRate.present
          ? data.defaultDrainRate.value
          : this.defaultDrainRate,
      defaultRestRate: data.defaultRestRate.present
          ? data.defaultRestRate.value
          : this.defaultRestRate,
      sleepFullCharge: data.sleepFullCharge.present
          ? data.sleepFullCharge.value
          : this.sleepFullCharge,
      sleepChargeRate: data.sleepChargeRate.present
          ? data.sleepChargeRate.value
          : this.sleepChargeRate,
      minBatteryForWork: data.minBatteryForWork.present
          ? data.minBatteryForWork.value
          : this.minBatteryForWork,
      dayStart: data.dayStart.present ? data.dayStart.value : this.dayStart,
      overcapAllowed: data.overcapAllowed.present
          ? data.overcapAllowed.value
          : this.overcapAllowed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('id: $id, ')
          ..write('initialBattery: $initialBattery, ')
          ..write('defaultDrainRate: $defaultDrainRate, ')
          ..write('defaultRestRate: $defaultRestRate, ')
          ..write('sleepFullCharge: $sleepFullCharge, ')
          ..write('sleepChargeRate: $sleepChargeRate, ')
          ..write('minBatteryForWork: $minBatteryForWork, ')
          ..write('dayStart: $dayStart, ')
          ..write('overcapAllowed: $overcapAllowed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      initialBattery,
      defaultDrainRate,
      defaultRestRate,
      sleepFullCharge,
      sleepChargeRate,
      minBatteryForWork,
      dayStart,
      overcapAllowed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.id == this.id &&
          other.initialBattery == this.initialBattery &&
          other.defaultDrainRate == this.defaultDrainRate &&
          other.defaultRestRate == this.defaultRestRate &&
          other.sleepFullCharge == this.sleepFullCharge &&
          other.sleepChargeRate == this.sleepChargeRate &&
          other.minBatteryForWork == this.minBatteryForWork &&
          other.dayStart == this.dayStart &&
          other.overcapAllowed == this.overcapAllowed);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<int> id;
  final Value<double> initialBattery;
  final Value<double> defaultDrainRate;
  final Value<double> defaultRestRate;
  final Value<bool> sleepFullCharge;
  final Value<double> sleepChargeRate;
  final Value<double> minBatteryForWork;
  final Value<String> dayStart;
  final Value<bool> overcapAllowed;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.initialBattery = const Value.absent(),
    this.defaultDrainRate = const Value.absent(),
    this.defaultRestRate = const Value.absent(),
    this.sleepFullCharge = const Value.absent(),
    this.sleepChargeRate = const Value.absent(),
    this.minBatteryForWork = const Value.absent(),
    this.dayStart = const Value.absent(),
    this.overcapAllowed = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    required double initialBattery,
    required double defaultDrainRate,
    required double defaultRestRate,
    required bool sleepFullCharge,
    required double sleepChargeRate,
    required double minBatteryForWork,
    required String dayStart,
    required bool overcapAllowed,
  })  : initialBattery = Value(initialBattery),
        defaultDrainRate = Value(defaultDrainRate),
        defaultRestRate = Value(defaultRestRate),
        sleepFullCharge = Value(sleepFullCharge),
        sleepChargeRate = Value(sleepChargeRate),
        minBatteryForWork = Value(minBatteryForWork),
        dayStart = Value(dayStart),
        overcapAllowed = Value(overcapAllowed);
  static Insertable<Setting> custom({
    Expression<int>? id,
    Expression<double>? initialBattery,
    Expression<double>? defaultDrainRate,
    Expression<double>? defaultRestRate,
    Expression<bool>? sleepFullCharge,
    Expression<double>? sleepChargeRate,
    Expression<double>? minBatteryForWork,
    Expression<String>? dayStart,
    Expression<bool>? overcapAllowed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (initialBattery != null) 'initial_battery': initialBattery,
      if (defaultDrainRate != null) 'default_drain_rate': defaultDrainRate,
      if (defaultRestRate != null) 'default_rest_rate': defaultRestRate,
      if (sleepFullCharge != null) 'sleep_full_charge': sleepFullCharge,
      if (sleepChargeRate != null) 'sleep_charge_rate': sleepChargeRate,
      if (minBatteryForWork != null) 'min_battery_for_work': minBatteryForWork,
      if (dayStart != null) 'day_start': dayStart,
      if (overcapAllowed != null) 'overcap_allowed': overcapAllowed,
    });
  }

  SettingsCompanion copyWith(
      {Value<int>? id,
      Value<double>? initialBattery,
      Value<double>? defaultDrainRate,
      Value<double>? defaultRestRate,
      Value<bool>? sleepFullCharge,
      Value<double>? sleepChargeRate,
      Value<double>? minBatteryForWork,
      Value<String>? dayStart,
      Value<bool>? overcapAllowed}) {
    return SettingsCompanion(
      id: id ?? this.id,
      initialBattery: initialBattery ?? this.initialBattery,
      defaultDrainRate: defaultDrainRate ?? this.defaultDrainRate,
      defaultRestRate: defaultRestRate ?? this.defaultRestRate,
      sleepFullCharge: sleepFullCharge ?? this.sleepFullCharge,
      sleepChargeRate: sleepChargeRate ?? this.sleepChargeRate,
      minBatteryForWork: minBatteryForWork ?? this.minBatteryForWork,
      dayStart: dayStart ?? this.dayStart,
      overcapAllowed: overcapAllowed ?? this.overcapAllowed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (initialBattery.present) {
      map['initial_battery'] = Variable<double>(initialBattery.value);
    }
    if (defaultDrainRate.present) {
      map['default_drain_rate'] = Variable<double>(defaultDrainRate.value);
    }
    if (defaultRestRate.present) {
      map['default_rest_rate'] = Variable<double>(defaultRestRate.value);
    }
    if (sleepFullCharge.present) {
      map['sleep_full_charge'] = Variable<bool>(sleepFullCharge.value);
    }
    if (sleepChargeRate.present) {
      map['sleep_charge_rate'] = Variable<double>(sleepChargeRate.value);
    }
    if (minBatteryForWork.present) {
      map['min_battery_for_work'] = Variable<double>(minBatteryForWork.value);
    }
    if (dayStart.present) {
      map['day_start'] = Variable<String>(dayStart.value);
    }
    if (overcapAllowed.present) {
      map['overcap_allowed'] = Variable<bool>(overcapAllowed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('initialBattery: $initialBattery, ')
          ..write('defaultDrainRate: $defaultDrainRate, ')
          ..write('defaultRestRate: $defaultRestRate, ')
          ..write('sleepFullCharge: $sleepFullCharge, ')
          ..write('sleepChargeRate: $sleepChargeRate, ')
          ..write('minBatteryForWork: $minBatteryForWork, ')
          ..write('dayStart: $dayStart, ')
          ..write('overcapAllowed: $overcapAllowed')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $EventsTable events = $EventsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [events, settings];
}

typedef $$EventsTableCreateCompanionBuilder = EventsCompanion Function({
  required String id,
  required String title,
  required int startAt,
  required int endAt,
  required int type,
  Value<double?> ratePerHour,
  required int priority,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$EventsTableUpdateCompanionBuilder = EventsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<int> startAt,
  Value<int> endAt,
  Value<int> type,
  Value<double?> ratePerHour,
  Value<int> priority,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$EventsTableFilterComposer extends Composer<_$AppDb, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get ratePerHour => $composableBuilder(
      column: $table.ratePerHour, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$EventsTableOrderingComposer extends Composer<_$AppDb, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get ratePerHour => $composableBuilder(
      column: $table.ratePerHour, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$EventsTableAnnotationComposer extends Composer<_$AppDb, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<int> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get ratePerHour => $composableBuilder(
      column: $table.ratePerHour, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EventsTableTableManager extends RootTableManager<
    _$AppDb,
    $EventsTable,
    Event,
    $$EventsTableFilterComposer,
    $$EventsTableOrderingComposer,
    $$EventsTableAnnotationComposer,
    $$EventsTableCreateCompanionBuilder,
    $$EventsTableUpdateCompanionBuilder,
    (Event, BaseReferences<_$AppDb, $EventsTable, Event>),
    Event,
    PrefetchHooks Function()> {
  $$EventsTableTableManager(_$AppDb db, $EventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<int> startAt = const Value.absent(),
            Value<int> endAt = const Value.absent(),
            Value<int> type = const Value.absent(),
            Value<double?> ratePerHour = const Value.absent(),
            Value<int> priority = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EventsCompanion(
            id: id,
            title: title,
            startAt: startAt,
            endAt: endAt,
            type: type,
            ratePerHour: ratePerHour,
            priority: priority,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required int startAt,
            required int endAt,
            required int type,
            Value<double?> ratePerHour = const Value.absent(),
            required int priority,
            required int createdAt,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              EventsCompanion.insert(
            id: id,
            title: title,
            startAt: startAt,
            endAt: endAt,
            type: type,
            ratePerHour: ratePerHour,
            priority: priority,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$EventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $EventsTable,
    Event,
    $$EventsTableFilterComposer,
    $$EventsTableOrderingComposer,
    $$EventsTableAnnotationComposer,
    $$EventsTableCreateCompanionBuilder,
    $$EventsTableUpdateCompanionBuilder,
    (Event, BaseReferences<_$AppDb, $EventsTable, Event>),
    Event,
    PrefetchHooks Function()>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  Value<int> id,
  required double initialBattery,
  required double defaultDrainRate,
  required double defaultRestRate,
  required bool sleepFullCharge,
  required double sleepChargeRate,
  required double minBatteryForWork,
  required String dayStart,
  required bool overcapAllowed,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<int> id,
  Value<double> initialBattery,
  Value<double> defaultDrainRate,
  Value<double> defaultRestRate,
  Value<bool> sleepFullCharge,
  Value<double> sleepChargeRate,
  Value<double> minBatteryForWork,
  Value<String> dayStart,
  Value<bool> overcapAllowed,
});

class $$SettingsTableFilterComposer extends Composer<_$AppDb, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get initialBattery => $composableBuilder(
      column: $table.initialBattery,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get defaultDrainRate => $composableBuilder(
      column: $table.defaultDrainRate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get defaultRestRate => $composableBuilder(
      column: $table.defaultRestRate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get sleepFullCharge => $composableBuilder(
      column: $table.sleepFullCharge,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get sleepChargeRate => $composableBuilder(
      column: $table.sleepChargeRate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get minBatteryForWork => $composableBuilder(
      column: $table.minBatteryForWork,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dayStart => $composableBuilder(
      column: $table.dayStart, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get overcapAllowed => $composableBuilder(
      column: $table.overcapAllowed,
      builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDb, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get initialBattery => $composableBuilder(
      column: $table.initialBattery,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get defaultDrainRate => $composableBuilder(
      column: $table.defaultDrainRate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get defaultRestRate => $composableBuilder(
      column: $table.defaultRestRate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get sleepFullCharge => $composableBuilder(
      column: $table.sleepFullCharge,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get sleepChargeRate => $composableBuilder(
      column: $table.sleepChargeRate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get minBatteryForWork => $composableBuilder(
      column: $table.minBatteryForWork,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dayStart => $composableBuilder(
      column: $table.dayStart, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get overcapAllowed => $composableBuilder(
      column: $table.overcapAllowed,
      builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDb, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get initialBattery => $composableBuilder(
      column: $table.initialBattery, builder: (column) => column);

  GeneratedColumn<double> get defaultDrainRate => $composableBuilder(
      column: $table.defaultDrainRate, builder: (column) => column);

  GeneratedColumn<double> get defaultRestRate => $composableBuilder(
      column: $table.defaultRestRate, builder: (column) => column);

  GeneratedColumn<bool> get sleepFullCharge => $composableBuilder(
      column: $table.sleepFullCharge, builder: (column) => column);

  GeneratedColumn<double> get sleepChargeRate => $composableBuilder(
      column: $table.sleepChargeRate, builder: (column) => column);

  GeneratedColumn<double> get minBatteryForWork => $composableBuilder(
      column: $table.minBatteryForWork, builder: (column) => column);

  GeneratedColumn<String> get dayStart =>
      $composableBuilder(column: $table.dayStart, builder: (column) => column);

  GeneratedColumn<bool> get overcapAllowed => $composableBuilder(
      column: $table.overcapAllowed, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDb,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDb, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDb db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<double> initialBattery = const Value.absent(),
            Value<double> defaultDrainRate = const Value.absent(),
            Value<double> defaultRestRate = const Value.absent(),
            Value<bool> sleepFullCharge = const Value.absent(),
            Value<double> sleepChargeRate = const Value.absent(),
            Value<double> minBatteryForWork = const Value.absent(),
            Value<String> dayStart = const Value.absent(),
            Value<bool> overcapAllowed = const Value.absent(),
          }) =>
              SettingsCompanion(
            id: id,
            initialBattery: initialBattery,
            defaultDrainRate: defaultDrainRate,
            defaultRestRate: defaultRestRate,
            sleepFullCharge: sleepFullCharge,
            sleepChargeRate: sleepChargeRate,
            minBatteryForWork: minBatteryForWork,
            dayStart: dayStart,
            overcapAllowed: overcapAllowed,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required double initialBattery,
            required double defaultDrainRate,
            required double defaultRestRate,
            required bool sleepFullCharge,
            required double sleepChargeRate,
            required double minBatteryForWork,
            required String dayStart,
            required bool overcapAllowed,
          }) =>
              SettingsCompanion.insert(
            id: id,
            initialBattery: initialBattery,
            defaultDrainRate: defaultDrainRate,
            defaultRestRate: defaultRestRate,
            sleepFullCharge: sleepFullCharge,
            sleepChargeRate: sleepChargeRate,
            minBatteryForWork: minBatteryForWork,
            dayStart: dayStart,
            overcapAllowed: overcapAllowed,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDb, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
