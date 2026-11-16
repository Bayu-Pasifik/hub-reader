// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_db.dart';

// ignore_for_file: type=lint
class $FavoriteRowsTable extends FavoriteRows
    with TableInfo<$FavoriteRowsTable, FavoriteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, json, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_rows';
  @override
  VerificationContext validateIntegrity(Insertable<FavoriteRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  FavoriteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteRow(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $FavoriteRowsTable createAlias(String alias) {
    return $FavoriteRowsTable(attachedDatabase, alias);
  }
}

class FavoriteRow extends DataClass implements Insertable<FavoriteRow> {
  final String key;
  final String json;
  final DateTime addedAt;
  const FavoriteRow(
      {required this.key, required this.json, required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoriteRowsCompanion toCompanion(bool nullToAbsent) {
    return FavoriteRowsCompanion(
      key: Value(key),
      json: Value(json),
      addedAt: Value(addedAt),
    );
  }

  factory FavoriteRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteRow(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  FavoriteRow copyWith({String? key, String? json, DateTime? addedAt}) =>
      FavoriteRow(
        key: key ?? this.key,
        json: json ?? this.json,
        addedAt: addedAt ?? this.addedAt,
      );
  FavoriteRow copyWithCompanion(FavoriteRowsCompanion data) {
    return FavoriteRow(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteRow(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteRow &&
          other.key == this.key &&
          other.json == this.json &&
          other.addedAt == this.addedAt);
}

class FavoriteRowsCompanion extends UpdateCompanion<FavoriteRow> {
  final Value<String> key;
  final Value<String> json;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const FavoriteRowsCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteRowsCompanion.insert({
    required String key,
    required String json,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        json = Value(json),
        addedAt = Value(addedAt);
  static Insertable<FavoriteRow> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteRowsCompanion copyWith(
      {Value<String>? key,
      Value<String>? json,
      Value<DateTime>? addedAt,
      Value<int>? rowid}) {
    return FavoriteRowsCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteRowsCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HistoryRowsTable extends HistoryRows
    with TableInfo<$HistoryRowsTable, HistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
      'read_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, json, readAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_rows';
  @override
  VerificationContext validateIntegrity(Insertable<HistoryRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(_readAtMeta,
          readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta));
    } else if (isInserting) {
      context.missing(_readAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  HistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryRow(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      readAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}read_at'])!,
    );
  }

  @override
  $HistoryRowsTable createAlias(String alias) {
    return $HistoryRowsTable(attachedDatabase, alias);
  }
}

class HistoryRow extends DataClass implements Insertable<HistoryRow> {
  final String key;
  final String json;
  final DateTime readAt;
  const HistoryRow(
      {required this.key, required this.json, required this.readAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    map['read_at'] = Variable<DateTime>(readAt);
    return map;
  }

  HistoryRowsCompanion toCompanion(bool nullToAbsent) {
    return HistoryRowsCompanion(
      key: Value(key),
      json: Value(json),
      readAt: Value(readAt),
    );
  }

  factory HistoryRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryRow(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
      readAt: serializer.fromJson<DateTime>(json['readAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
      'readAt': serializer.toJson<DateTime>(readAt),
    };
  }

  HistoryRow copyWith({String? key, String? json, DateTime? readAt}) =>
      HistoryRow(
        key: key ?? this.key,
        json: json ?? this.json,
        readAt: readAt ?? this.readAt,
      );
  HistoryRow copyWithCompanion(HistoryRowsCompanion data) {
    return HistoryRow(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRow(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('readAt: $readAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json, readAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryRow &&
          other.key == this.key &&
          other.json == this.json &&
          other.readAt == this.readAt);
}

class HistoryRowsCompanion extends UpdateCompanion<HistoryRow> {
  final Value<String> key;
  final Value<String> json;
  final Value<DateTime> readAt;
  final Value<int> rowid;
  const HistoryRowsCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.readAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HistoryRowsCompanion.insert({
    required String key,
    required String json,
    required DateTime readAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        json = Value(json),
        readAt = Value(readAt);
  static Insertable<HistoryRow> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<DateTime>? readAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (readAt != null) 'read_at': readAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HistoryRowsCompanion copyWith(
      {Value<String>? key,
      Value<String>? json,
      Value<DateTime>? readAt,
      Value<int>? rowid}) {
    return HistoryRowsCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      readAt: readAt ?? this.readAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRowsCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('readAt: $readAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgressRowsTable extends ProgressRows
    with TableInfo<$ProgressRowsTable, ProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seriesKeyMeta =
      const VerificationMeta('seriesKey');
  @override
  late final GeneratedColumn<String> seriesKey = GeneratedColumn<String>(
      'series_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chapterUrlMeta =
      const VerificationMeta('chapterUrl');
  @override
  late final GeneratedColumn<String> chapterUrl = GeneratedColumn<String>(
      'chapter_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [seriesKey, chapterUrl, json, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progress_rows';
  @override
  VerificationContext validateIntegrity(Insertable<ProgressRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('series_key')) {
      context.handle(_seriesKeyMeta,
          seriesKey.isAcceptableOrUnknown(data['series_key']!, _seriesKeyMeta));
    } else if (isInserting) {
      context.missing(_seriesKeyMeta);
    }
    if (data.containsKey('chapter_url')) {
      context.handle(
          _chapterUrlMeta,
          chapterUrl.isAcceptableOrUnknown(
              data['chapter_url']!, _chapterUrlMeta));
    } else if (isInserting) {
      context.missing(_chapterUrlMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {seriesKey, chapterUrl};
  @override
  ProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressRow(
      seriesKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}series_key'])!,
      chapterUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chapter_url'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ProgressRowsTable createAlias(String alias) {
    return $ProgressRowsTable(attachedDatabase, alias);
  }
}

class ProgressRow extends DataClass implements Insertable<ProgressRow> {
  final String seriesKey;
  final String chapterUrl;
  final String json;
  final DateTime updatedAt;
  const ProgressRow(
      {required this.seriesKey,
      required this.chapterUrl,
      required this.json,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['series_key'] = Variable<String>(seriesKey);
    map['chapter_url'] = Variable<String>(chapterUrl);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProgressRowsCompanion toCompanion(bool nullToAbsent) {
    return ProgressRowsCompanion(
      seriesKey: Value(seriesKey),
      chapterUrl: Value(chapterUrl),
      json: Value(json),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProgressRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressRow(
      seriesKey: serializer.fromJson<String>(json['seriesKey']),
      chapterUrl: serializer.fromJson<String>(json['chapterUrl']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seriesKey': serializer.toJson<String>(seriesKey),
      'chapterUrl': serializer.toJson<String>(chapterUrl),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProgressRow copyWith(
          {String? seriesKey,
          String? chapterUrl,
          String? json,
          DateTime? updatedAt}) =>
      ProgressRow(
        seriesKey: seriesKey ?? this.seriesKey,
        chapterUrl: chapterUrl ?? this.chapterUrl,
        json: json ?? this.json,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ProgressRow copyWithCompanion(ProgressRowsCompanion data) {
    return ProgressRow(
      seriesKey: data.seriesKey.present ? data.seriesKey.value : this.seriesKey,
      chapterUrl:
          data.chapterUrl.present ? data.chapterUrl.value : this.chapterUrl,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressRow(')
          ..write('seriesKey: $seriesKey, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seriesKey, chapterUrl, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressRow &&
          other.seriesKey == this.seriesKey &&
          other.chapterUrl == this.chapterUrl &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class ProgressRowsCompanion extends UpdateCompanion<ProgressRow> {
  final Value<String> seriesKey;
  final Value<String> chapterUrl;
  final Value<String> json;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProgressRowsCompanion({
    this.seriesKey = const Value.absent(),
    this.chapterUrl = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgressRowsCompanion.insert({
    required String seriesKey,
    required String chapterUrl,
    required String json,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : seriesKey = Value(seriesKey),
        chapterUrl = Value(chapterUrl),
        json = Value(json),
        updatedAt = Value(updatedAt);
  static Insertable<ProgressRow> custom({
    Expression<String>? seriesKey,
    Expression<String>? chapterUrl,
    Expression<String>? json,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (seriesKey != null) 'series_key': seriesKey,
      if (chapterUrl != null) 'chapter_url': chapterUrl,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgressRowsCompanion copyWith(
      {Value<String>? seriesKey,
      Value<String>? chapterUrl,
      Value<String>? json,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ProgressRowsCompanion(
      seriesKey: seriesKey ?? this.seriesKey,
      chapterUrl: chapterUrl ?? this.chapterUrl,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seriesKey.present) {
      map['series_key'] = Variable<String>(seriesKey.value);
    }
    if (chapterUrl.present) {
      map['chapter_url'] = Variable<String>(chapterUrl.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressRowsCompanion(')
          ..write('seriesKey: $seriesKey, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemovedRowsTable extends RemovedRows
    with TableInfo<$RemovedRowsTable, RemovedRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemovedRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _removedAtMeta =
      const VerificationMeta('removedAt');
  @override
  late final GeneratedColumn<DateTime> removedAt = GeneratedColumn<DateTime>(
      'removed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, removedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'removed_rows';
  @override
  VerificationContext validateIntegrity(Insertable<RemovedRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('removed_at')) {
      context.handle(_removedAtMeta,
          removedAt.isAcceptableOrUnknown(data['removed_at']!, _removedAtMeta));
    } else if (isInserting) {
      context.missing(_removedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  RemovedRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RemovedRow(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      removedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}removed_at'])!,
    );
  }

  @override
  $RemovedRowsTable createAlias(String alias) {
    return $RemovedRowsTable(attachedDatabase, alias);
  }
}

class RemovedRow extends DataClass implements Insertable<RemovedRow> {
  final String key;
  final DateTime removedAt;
  const RemovedRow({required this.key, required this.removedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['removed_at'] = Variable<DateTime>(removedAt);
    return map;
  }

  RemovedRowsCompanion toCompanion(bool nullToAbsent) {
    return RemovedRowsCompanion(
      key: Value(key),
      removedAt: Value(removedAt),
    );
  }

  factory RemovedRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RemovedRow(
      key: serializer.fromJson<String>(json['key']),
      removedAt: serializer.fromJson<DateTime>(json['removedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'removedAt': serializer.toJson<DateTime>(removedAt),
    };
  }

  RemovedRow copyWith({String? key, DateTime? removedAt}) => RemovedRow(
        key: key ?? this.key,
        removedAt: removedAt ?? this.removedAt,
      );
  RemovedRow copyWithCompanion(RemovedRowsCompanion data) {
    return RemovedRow(
      key: data.key.present ? data.key.value : this.key,
      removedAt: data.removedAt.present ? data.removedAt.value : this.removedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RemovedRow(')
          ..write('key: $key, ')
          ..write('removedAt: $removedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, removedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemovedRow &&
          other.key == this.key &&
          other.removedAt == this.removedAt);
}

class RemovedRowsCompanion extends UpdateCompanion<RemovedRow> {
  final Value<String> key;
  final Value<DateTime> removedAt;
  final Value<int> rowid;
  const RemovedRowsCompanion({
    this.key = const Value.absent(),
    this.removedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemovedRowsCompanion.insert({
    required String key,
    required DateTime removedAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        removedAt = Value(removedAt);
  static Insertable<RemovedRow> custom({
    Expression<String>? key,
    Expression<DateTime>? removedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (removedAt != null) 'removed_at': removedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemovedRowsCompanion copyWith(
      {Value<String>? key, Value<DateTime>? removedAt, Value<int>? rowid}) {
    return RemovedRowsCompanion(
      key: key ?? this.key,
      removedAt: removedAt ?? this.removedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (removedAt.present) {
      map['removed_at'] = Variable<DateTime>(removedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemovedRowsCompanion(')
          ..write('key: $key, ')
          ..write('removedAt: $removedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaRowsTable extends MetaRows with TableInfo<$MetaRowsTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [name, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta_rows';
  @override
  VerificationContext validateIntegrity(Insertable<MetaRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $MetaRowsTable createAlias(String alias) {
    return $MetaRowsTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String name;
  final String value;
  const MetaRow({required this.name, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaRowsCompanion toCompanion(bool nullToAbsent) {
    return MetaRowsCompanion(
      name: Value(name),
      value: Value(value),
    );
  }

  factory MetaRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      name: serializer.fromJson<String>(json['name']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaRow copyWith({String? name, String? value}) => MetaRow(
        name: name ?? this.name,
        value: value ?? this.value,
      );
  MetaRow copyWithCompanion(MetaRowsCompanion data) {
    return MetaRow(
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('name: $name, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow &&
          other.name == this.name &&
          other.value == this.value);
}

class MetaRowsCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> name;
  final Value<String> value;
  final Value<int> rowid;
  const MetaRowsCompanion({
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaRowsCompanion.insert({
    required String name,
    required String value,
    this.rowid = const Value.absent(),
  })  : name = Value(name),
        value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? name,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaRowsCompanion copyWith(
      {Value<String>? name, Value<String>? value, Value<int>? rowid}) {
    return MetaRowsCompanion(
      name: name ?? this.name,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaRowsCompanion(')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LibraryDb extends GeneratedDatabase {
  _$LibraryDb(QueryExecutor e) : super(e);
  $LibraryDbManager get managers => $LibraryDbManager(this);
  late final $FavoriteRowsTable favoriteRows = $FavoriteRowsTable(this);
  late final $HistoryRowsTable historyRows = $HistoryRowsTable(this);
  late final $ProgressRowsTable progressRows = $ProgressRowsTable(this);
  late final $RemovedRowsTable removedRows = $RemovedRowsTable(this);
  late final $MetaRowsTable metaRows = $MetaRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [favoriteRows, historyRows, progressRows, removedRows, metaRows];
}

typedef $$FavoriteRowsTableCreateCompanionBuilder = FavoriteRowsCompanion
    Function({
  required String key,
  required String json,
  required DateTime addedAt,
  Value<int> rowid,
});
typedef $$FavoriteRowsTableUpdateCompanionBuilder = FavoriteRowsCompanion
    Function({
  Value<String> key,
  Value<String> json,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

class $$FavoriteRowsTableFilterComposer
    extends Composer<_$LibraryDb, $FavoriteRowsTable> {
  $$FavoriteRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));
}

class $$FavoriteRowsTableOrderingComposer
    extends Composer<_$LibraryDb, $FavoriteRowsTable> {
  $$FavoriteRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));
}

class $$FavoriteRowsTableAnnotationComposer
    extends Composer<_$LibraryDb, $FavoriteRowsTable> {
  $$FavoriteRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$FavoriteRowsTableTableManager extends RootTableManager<
    _$LibraryDb,
    $FavoriteRowsTable,
    FavoriteRow,
    $$FavoriteRowsTableFilterComposer,
    $$FavoriteRowsTableOrderingComposer,
    $$FavoriteRowsTableAnnotationComposer,
    $$FavoriteRowsTableCreateCompanionBuilder,
    $$FavoriteRowsTableUpdateCompanionBuilder,
    (FavoriteRow, BaseReferences<_$LibraryDb, $FavoriteRowsTable, FavoriteRow>),
    FavoriteRow,
    PrefetchHooks Function()> {
  $$FavoriteRowsTableTableManager(_$LibraryDb db, $FavoriteRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoriteRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FavoriteRowsCompanion(
            key: key,
            json: json,
            addedAt: addedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String json,
            required DateTime addedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              FavoriteRowsCompanion.insert(
            key: key,
            json: json,
            addedAt: addedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$FavoriteRowsTable, FavoriteRow>(table),
                    BaseReferences<_$LibraryDb, $FavoriteRowsTable,
                        FavoriteRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FavoriteRowsTableProcessedTableManager = ProcessedTableManager<
    _$LibraryDb,
    $FavoriteRowsTable,
    FavoriteRow,
    $$FavoriteRowsTableFilterComposer,
    $$FavoriteRowsTableOrderingComposer,
    $$FavoriteRowsTableAnnotationComposer,
    $$FavoriteRowsTableCreateCompanionBuilder,
    $$FavoriteRowsTableUpdateCompanionBuilder,
    (FavoriteRow, BaseReferences<_$LibraryDb, $FavoriteRowsTable, FavoriteRow>),
    FavoriteRow,
    PrefetchHooks Function()>;
typedef $$HistoryRowsTableCreateCompanionBuilder = HistoryRowsCompanion
    Function({
  required String key,
  required String json,
  required DateTime readAt,
  Value<int> rowid,
});
typedef $$HistoryRowsTableUpdateCompanionBuilder = HistoryRowsCompanion
    Function({
  Value<String> key,
  Value<String> json,
  Value<DateTime> readAt,
  Value<int> rowid,
});

class $$HistoryRowsTableFilterComposer
    extends Composer<_$LibraryDb, $HistoryRowsTable> {
  $$HistoryRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnFilters(column));
}

class $$HistoryRowsTableOrderingComposer
    extends Composer<_$LibraryDb, $HistoryRowsTable> {
  $$HistoryRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnOrderings(column));
}

class $$HistoryRowsTableAnnotationComposer
    extends Composer<_$LibraryDb, $HistoryRowsTable> {
  $$HistoryRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);
}

class $$HistoryRowsTableTableManager extends RootTableManager<
    _$LibraryDb,
    $HistoryRowsTable,
    HistoryRow,
    $$HistoryRowsTableFilterComposer,
    $$HistoryRowsTableOrderingComposer,
    $$HistoryRowsTableAnnotationComposer,
    $$HistoryRowsTableCreateCompanionBuilder,
    $$HistoryRowsTableUpdateCompanionBuilder,
    (HistoryRow, BaseReferences<_$LibraryDb, $HistoryRowsTable, HistoryRow>),
    HistoryRow,
    PrefetchHooks Function()> {
  $$HistoryRowsTableTableManager(_$LibraryDb db, $HistoryRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<DateTime> readAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HistoryRowsCompanion(
            key: key,
            json: json,
            readAt: readAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String json,
            required DateTime readAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              HistoryRowsCompanion.insert(
            key: key,
            json: json,
            readAt: readAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$HistoryRowsTable, HistoryRow>(table),
                    BaseReferences<_$LibraryDb, $HistoryRowsTable, HistoryRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HistoryRowsTableProcessedTableManager = ProcessedTableManager<
    _$LibraryDb,
    $HistoryRowsTable,
    HistoryRow,
    $$HistoryRowsTableFilterComposer,
    $$HistoryRowsTableOrderingComposer,
    $$HistoryRowsTableAnnotationComposer,
    $$HistoryRowsTableCreateCompanionBuilder,
    $$HistoryRowsTableUpdateCompanionBuilder,
    (HistoryRow, BaseReferences<_$LibraryDb, $HistoryRowsTable, HistoryRow>),
    HistoryRow,
    PrefetchHooks Function()>;
typedef $$ProgressRowsTableCreateCompanionBuilder = ProgressRowsCompanion
    Function({
  required String seriesKey,
  required String chapterUrl,
  required String json,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ProgressRowsTableUpdateCompanionBuilder = ProgressRowsCompanion
    Function({
  Value<String> seriesKey,
  Value<String> chapterUrl,
  Value<String> json,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ProgressRowsTableFilterComposer
    extends Composer<_$LibraryDb, $ProgressRowsTable> {
  $$ProgressRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get seriesKey => $composableBuilder(
      column: $table.seriesKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chapterUrl => $composableBuilder(
      column: $table.chapterUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ProgressRowsTableOrderingComposer
    extends Composer<_$LibraryDb, $ProgressRowsTable> {
  $$ProgressRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get seriesKey => $composableBuilder(
      column: $table.seriesKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chapterUrl => $composableBuilder(
      column: $table.chapterUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ProgressRowsTableAnnotationComposer
    extends Composer<_$LibraryDb, $ProgressRowsTable> {
  $$ProgressRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get seriesKey =>
      $composableBuilder(column: $table.seriesKey, builder: (column) => column);

  GeneratedColumn<String> get chapterUrl => $composableBuilder(
      column: $table.chapterUrl, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProgressRowsTableTableManager extends RootTableManager<
    _$LibraryDb,
    $ProgressRowsTable,
    ProgressRow,
    $$ProgressRowsTableFilterComposer,
    $$ProgressRowsTableOrderingComposer,
    $$ProgressRowsTableAnnotationComposer,
    $$ProgressRowsTableCreateCompanionBuilder,
    $$ProgressRowsTableUpdateCompanionBuilder,
    (ProgressRow, BaseReferences<_$LibraryDb, $ProgressRowsTable, ProgressRow>),
    ProgressRow,
    PrefetchHooks Function()> {
  $$ProgressRowsTableTableManager(_$LibraryDb db, $ProgressRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgressRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgressRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgressRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> seriesKey = const Value.absent(),
            Value<String> chapterUrl = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProgressRowsCompanion(
            seriesKey: seriesKey,
            chapterUrl: chapterUrl,
            json: json,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String seriesKey,
            required String chapterUrl,
            required String json,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ProgressRowsCompanion.insert(
            seriesKey: seriesKey,
            chapterUrl: chapterUrl,
            json: json,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ProgressRowsTable, ProgressRow>(table),
                    BaseReferences<_$LibraryDb, $ProgressRowsTable,
                        ProgressRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProgressRowsTableProcessedTableManager = ProcessedTableManager<
    _$LibraryDb,
    $ProgressRowsTable,
    ProgressRow,
    $$ProgressRowsTableFilterComposer,
    $$ProgressRowsTableOrderingComposer,
    $$ProgressRowsTableAnnotationComposer,
    $$ProgressRowsTableCreateCompanionBuilder,
    $$ProgressRowsTableUpdateCompanionBuilder,
    (ProgressRow, BaseReferences<_$LibraryDb, $ProgressRowsTable, ProgressRow>),
    ProgressRow,
    PrefetchHooks Function()>;
typedef $$RemovedRowsTableCreateCompanionBuilder = RemovedRowsCompanion
    Function({
  required String key,
  required DateTime removedAt,
  Value<int> rowid,
});
typedef $$RemovedRowsTableUpdateCompanionBuilder = RemovedRowsCompanion
    Function({
  Value<String> key,
  Value<DateTime> removedAt,
  Value<int> rowid,
});

class $$RemovedRowsTableFilterComposer
    extends Composer<_$LibraryDb, $RemovedRowsTable> {
  $$RemovedRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get removedAt => $composableBuilder(
      column: $table.removedAt, builder: (column) => ColumnFilters(column));
}

class $$RemovedRowsTableOrderingComposer
    extends Composer<_$LibraryDb, $RemovedRowsTable> {
  $$RemovedRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get removedAt => $composableBuilder(
      column: $table.removedAt, builder: (column) => ColumnOrderings(column));
}

class $$RemovedRowsTableAnnotationComposer
    extends Composer<_$LibraryDb, $RemovedRowsTable> {
  $$RemovedRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<DateTime> get removedAt =>
      $composableBuilder(column: $table.removedAt, builder: (column) => column);
}

class $$RemovedRowsTableTableManager extends RootTableManager<
    _$LibraryDb,
    $RemovedRowsTable,
    RemovedRow,
    $$RemovedRowsTableFilterComposer,
    $$RemovedRowsTableOrderingComposer,
    $$RemovedRowsTableAnnotationComposer,
    $$RemovedRowsTableCreateCompanionBuilder,
    $$RemovedRowsTableUpdateCompanionBuilder,
    (RemovedRow, BaseReferences<_$LibraryDb, $RemovedRowsTable, RemovedRow>),
    RemovedRow,
    PrefetchHooks Function()> {
  $$RemovedRowsTableTableManager(_$LibraryDb db, $RemovedRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemovedRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemovedRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemovedRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<DateTime> removedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RemovedRowsCompanion(
            key: key,
            removedAt: removedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required DateTime removedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              RemovedRowsCompanion.insert(
            key: key,
            removedAt: removedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RemovedRowsTable, RemovedRow>(table),
                    BaseReferences<_$LibraryDb, $RemovedRowsTable, RemovedRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RemovedRowsTableProcessedTableManager = ProcessedTableManager<
    _$LibraryDb,
    $RemovedRowsTable,
    RemovedRow,
    $$RemovedRowsTableFilterComposer,
    $$RemovedRowsTableOrderingComposer,
    $$RemovedRowsTableAnnotationComposer,
    $$RemovedRowsTableCreateCompanionBuilder,
    $$RemovedRowsTableUpdateCompanionBuilder,
    (RemovedRow, BaseReferences<_$LibraryDb, $RemovedRowsTable, RemovedRow>),
    RemovedRow,
    PrefetchHooks Function()>;
typedef $$MetaRowsTableCreateCompanionBuilder = MetaRowsCompanion Function({
  required String name,
  required String value,
  Value<int> rowid,
});
typedef $$MetaRowsTableUpdateCompanionBuilder = MetaRowsCompanion Function({
  Value<String> name,
  Value<String> value,
  Value<int> rowid,
});

class $$MetaRowsTableFilterComposer
    extends Composer<_$LibraryDb, $MetaRowsTable> {
  $$MetaRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$MetaRowsTableOrderingComposer
    extends Composer<_$LibraryDb, $MetaRowsTable> {
  $$MetaRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$MetaRowsTableAnnotationComposer
    extends Composer<_$LibraryDb, $MetaRowsTable> {
  $$MetaRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaRowsTableTableManager extends RootTableManager<
    _$LibraryDb,
    $MetaRowsTable,
    MetaRow,
    $$MetaRowsTableFilterComposer,
    $$MetaRowsTableOrderingComposer,
    $$MetaRowsTableAnnotationComposer,
    $$MetaRowsTableCreateCompanionBuilder,
    $$MetaRowsTableUpdateCompanionBuilder,
    (MetaRow, BaseReferences<_$LibraryDb, $MetaRowsTable, MetaRow>),
    MetaRow,
    PrefetchHooks Function()> {
  $$MetaRowsTableTableManager(_$LibraryDb db, $MetaRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> name = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MetaRowsCompanion(
            name: name,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String name,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              MetaRowsCompanion.insert(
            name: name,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MetaRowsTable, MetaRow>(table),
                    BaseReferences<_$LibraryDb, $MetaRowsTable, MetaRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MetaRowsTableProcessedTableManager = ProcessedTableManager<
    _$LibraryDb,
    $MetaRowsTable,
    MetaRow,
    $$MetaRowsTableFilterComposer,
    $$MetaRowsTableOrderingComposer,
    $$MetaRowsTableAnnotationComposer,
    $$MetaRowsTableCreateCompanionBuilder,
    $$MetaRowsTableUpdateCompanionBuilder,
    (MetaRow, BaseReferences<_$LibraryDb, $MetaRowsTable, MetaRow>),
    MetaRow,
    PrefetchHooks Function()>;

class $LibraryDbManager {
  final _$LibraryDb _db;
  $LibraryDbManager(this._db);
  $$FavoriteRowsTableTableManager get favoriteRows =>
      $$FavoriteRowsTableTableManager(_db, _db.favoriteRows);
  $$HistoryRowsTableTableManager get historyRows =>
      $$HistoryRowsTableTableManager(_db, _db.historyRows);
  $$ProgressRowsTableTableManager get progressRows =>
      $$ProgressRowsTableTableManager(_db, _db.progressRows);
  $$RemovedRowsTableTableManager get removedRows =>
      $$RemovedRowsTableTableManager(_db, _db.removedRows);
  $$MetaRowsTableTableManager get metaRows =>
      $$MetaRowsTableTableManager(_db, _db.metaRows);
}
