// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $OrgSettingsTable extends OrgSettings
    with TableInfo<$OrgSettingsTable, OrgSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrgSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shortNameMeta = const VerificationMeta(
    'shortName',
  );
  @override
  late final GeneratedColumn<String> shortName = GeneratedColumn<String>(
    'short_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberIdPrefixMeta = const VerificationMeta(
    'memberIdPrefix',
  );
  @override
  late final GeneratedColumn<String> memberIdPrefix = GeneratedColumn<String>(
    'member_id_prefix',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextMemberNoMeta = const VerificationMeta(
    'nextMemberNo',
  );
  @override
  late final GeneratedColumn<int> nextMemberNo = GeneratedColumn<int>(
    'next_member_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('GHS'),
  );
  static const VerificationMeta _poweredByMeta = const VerificationMeta(
    'poweredBy',
  );
  @override
  late final GeneratedColumn<String> poweredBy = GeneratedColumn<String>(
    'powered_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logoPathMeta = const VerificationMeta(
    'logoPath',
  );
  @override
  late final GeneratedColumn<String> logoPath = GeneratedColumn<String>(
    'logo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    shortName,
    memberIdPrefix,
    nextMemberNo,
    currency,
    poweredBy,
    logoPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'org_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<OrgSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('short_name')) {
      context.handle(
        _shortNameMeta,
        shortName.isAcceptableOrUnknown(data['short_name']!, _shortNameMeta),
      );
    } else if (isInserting) {
      context.missing(_shortNameMeta);
    }
    if (data.containsKey('member_id_prefix')) {
      context.handle(
        _memberIdPrefixMeta,
        memberIdPrefix.isAcceptableOrUnknown(
          data['member_id_prefix']!,
          _memberIdPrefixMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_memberIdPrefixMeta);
    }
    if (data.containsKey('next_member_no')) {
      context.handle(
        _nextMemberNoMeta,
        nextMemberNo.isAcceptableOrUnknown(
          data['next_member_no']!,
          _nextMemberNoMeta,
        ),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('powered_by')) {
      context.handle(
        _poweredByMeta,
        poweredBy.isAcceptableOrUnknown(data['powered_by']!, _poweredByMeta),
      );
    }
    if (data.containsKey('logo_path')) {
      context.handle(
        _logoPathMeta,
        logoPath.isAcceptableOrUnknown(data['logo_path']!, _logoPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrgSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrgSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      shortName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}short_name'],
      )!,
      memberIdPrefix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id_prefix'],
      )!,
      nextMemberNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_member_no'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      poweredBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}powered_by'],
      ),
      logoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_path'],
      ),
    );
  }

  @override
  $OrgSettingsTable createAlias(String alias) {
    return $OrgSettingsTable(attachedDatabase, alias);
  }
}

class OrgSetting extends DataClass implements Insertable<OrgSetting> {
  final int id;
  final String name;
  final String shortName;
  final String memberIdPrefix;
  final int nextMemberNo;
  final String currency;
  final String? poweredBy;
  final String? logoPath;
  const OrgSetting({
    required this.id,
    required this.name,
    required this.shortName,
    required this.memberIdPrefix,
    required this.nextMemberNo,
    required this.currency,
    this.poweredBy,
    this.logoPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['short_name'] = Variable<String>(shortName);
    map['member_id_prefix'] = Variable<String>(memberIdPrefix);
    map['next_member_no'] = Variable<int>(nextMemberNo);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || poweredBy != null) {
      map['powered_by'] = Variable<String>(poweredBy);
    }
    if (!nullToAbsent || logoPath != null) {
      map['logo_path'] = Variable<String>(logoPath);
    }
    return map;
  }

  OrgSettingsCompanion toCompanion(bool nullToAbsent) {
    return OrgSettingsCompanion(
      id: Value(id),
      name: Value(name),
      shortName: Value(shortName),
      memberIdPrefix: Value(memberIdPrefix),
      nextMemberNo: Value(nextMemberNo),
      currency: Value(currency),
      poweredBy: poweredBy == null && nullToAbsent
          ? const Value.absent()
          : Value(poweredBy),
      logoPath: logoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(logoPath),
    );
  }

  factory OrgSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrgSetting(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      shortName: serializer.fromJson<String>(json['shortName']),
      memberIdPrefix: serializer.fromJson<String>(json['memberIdPrefix']),
      nextMemberNo: serializer.fromJson<int>(json['nextMemberNo']),
      currency: serializer.fromJson<String>(json['currency']),
      poweredBy: serializer.fromJson<String?>(json['poweredBy']),
      logoPath: serializer.fromJson<String?>(json['logoPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'shortName': serializer.toJson<String>(shortName),
      'memberIdPrefix': serializer.toJson<String>(memberIdPrefix),
      'nextMemberNo': serializer.toJson<int>(nextMemberNo),
      'currency': serializer.toJson<String>(currency),
      'poweredBy': serializer.toJson<String?>(poweredBy),
      'logoPath': serializer.toJson<String?>(logoPath),
    };
  }

  OrgSetting copyWith({
    int? id,
    String? name,
    String? shortName,
    String? memberIdPrefix,
    int? nextMemberNo,
    String? currency,
    Value<String?> poweredBy = const Value.absent(),
    Value<String?> logoPath = const Value.absent(),
  }) => OrgSetting(
    id: id ?? this.id,
    name: name ?? this.name,
    shortName: shortName ?? this.shortName,
    memberIdPrefix: memberIdPrefix ?? this.memberIdPrefix,
    nextMemberNo: nextMemberNo ?? this.nextMemberNo,
    currency: currency ?? this.currency,
    poweredBy: poweredBy.present ? poweredBy.value : this.poweredBy,
    logoPath: logoPath.present ? logoPath.value : this.logoPath,
  );
  OrgSetting copyWithCompanion(OrgSettingsCompanion data) {
    return OrgSetting(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      shortName: data.shortName.present ? data.shortName.value : this.shortName,
      memberIdPrefix: data.memberIdPrefix.present
          ? data.memberIdPrefix.value
          : this.memberIdPrefix,
      nextMemberNo: data.nextMemberNo.present
          ? data.nextMemberNo.value
          : this.nextMemberNo,
      currency: data.currency.present ? data.currency.value : this.currency,
      poweredBy: data.poweredBy.present ? data.poweredBy.value : this.poweredBy,
      logoPath: data.logoPath.present ? data.logoPath.value : this.logoPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrgSetting(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('shortName: $shortName, ')
          ..write('memberIdPrefix: $memberIdPrefix, ')
          ..write('nextMemberNo: $nextMemberNo, ')
          ..write('currency: $currency, ')
          ..write('poweredBy: $poweredBy, ')
          ..write('logoPath: $logoPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    shortName,
    memberIdPrefix,
    nextMemberNo,
    currency,
    poweredBy,
    logoPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrgSetting &&
          other.id == this.id &&
          other.name == this.name &&
          other.shortName == this.shortName &&
          other.memberIdPrefix == this.memberIdPrefix &&
          other.nextMemberNo == this.nextMemberNo &&
          other.currency == this.currency &&
          other.poweredBy == this.poweredBy &&
          other.logoPath == this.logoPath);
}

class OrgSettingsCompanion extends UpdateCompanion<OrgSetting> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> shortName;
  final Value<String> memberIdPrefix;
  final Value<int> nextMemberNo;
  final Value<String> currency;
  final Value<String?> poweredBy;
  final Value<String?> logoPath;
  const OrgSettingsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.shortName = const Value.absent(),
    this.memberIdPrefix = const Value.absent(),
    this.nextMemberNo = const Value.absent(),
    this.currency = const Value.absent(),
    this.poweredBy = const Value.absent(),
    this.logoPath = const Value.absent(),
  });
  OrgSettingsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String shortName,
    required String memberIdPrefix,
    this.nextMemberNo = const Value.absent(),
    this.currency = const Value.absent(),
    this.poweredBy = const Value.absent(),
    this.logoPath = const Value.absent(),
  }) : name = Value(name),
       shortName = Value(shortName),
       memberIdPrefix = Value(memberIdPrefix);
  static Insertable<OrgSetting> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? shortName,
    Expression<String>? memberIdPrefix,
    Expression<int>? nextMemberNo,
    Expression<String>? currency,
    Expression<String>? poweredBy,
    Expression<String>? logoPath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (shortName != null) 'short_name': shortName,
      if (memberIdPrefix != null) 'member_id_prefix': memberIdPrefix,
      if (nextMemberNo != null) 'next_member_no': nextMemberNo,
      if (currency != null) 'currency': currency,
      if (poweredBy != null) 'powered_by': poweredBy,
      if (logoPath != null) 'logo_path': logoPath,
    });
  }

  OrgSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? shortName,
    Value<String>? memberIdPrefix,
    Value<int>? nextMemberNo,
    Value<String>? currency,
    Value<String?>? poweredBy,
    Value<String?>? logoPath,
  }) {
    return OrgSettingsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      memberIdPrefix: memberIdPrefix ?? this.memberIdPrefix,
      nextMemberNo: nextMemberNo ?? this.nextMemberNo,
      currency: currency ?? this.currency,
      poweredBy: poweredBy ?? this.poweredBy,
      logoPath: logoPath ?? this.logoPath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (shortName.present) {
      map['short_name'] = Variable<String>(shortName.value);
    }
    if (memberIdPrefix.present) {
      map['member_id_prefix'] = Variable<String>(memberIdPrefix.value);
    }
    if (nextMemberNo.present) {
      map['next_member_no'] = Variable<int>(nextMemberNo.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (poweredBy.present) {
      map['powered_by'] = Variable<String>(poweredBy.value);
    }
    if (logoPath.present) {
      map['logo_path'] = Variable<String>(logoPath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrgSettingsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('shortName: $shortName, ')
          ..write('memberIdPrefix: $memberIdPrefix, ')
          ..write('nextMemberNo: $nextMemberNo, ')
          ..write('currency: $currency, ')
          ..write('poweredBy: $poweredBy, ')
          ..write('logoPath: $logoPath')
          ..write(')'))
        .toString();
  }
}

class $ZonesTable extends Zones with TableInfo<$ZonesTable, Zone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ZonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<int> code = GeneratedColumn<int>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    createdBy,
    deviceId,
    deletedAt,
    code,
    name,
    nickname,
    isActive,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'zones';
  @override
  VerificationContext validateIntegrity(
    Insertable<Zone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Zone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Zone(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ZonesTable createAlias(String alias) {
    return $ZonesTable(attachedDatabase, alias);
  }
}

class Zone extends DataClass implements Insertable<Zone> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? deviceId;
  final DateTime? deletedAt;
  final int code;
  final String name;
  final String? nickname;
  final bool isActive;
  final int sortOrder;
  const Zone({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.deletedAt,
    required this.code,
    required this.name,
    this.nickname,
    required this.isActive,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['code'] = Variable<int>(code);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || nickname != null) {
      map['nickname'] = Variable<String>(nickname);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ZonesCompanion toCompanion(bool nullToAbsent) {
    return ZonesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      code: Value(code),
      name: Value(name),
      nickname: nickname == null && nullToAbsent
          ? const Value.absent()
          : Value(nickname),
      isActive: Value(isActive),
      sortOrder: Value(sortOrder),
    );
  }

  factory Zone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Zone(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      code: serializer.fromJson<int>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      nickname: serializer.fromJson<String?>(json['nickname']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdBy': serializer.toJson<String?>(createdBy),
      'deviceId': serializer.toJson<String?>(deviceId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'code': serializer.toJson<int>(code),
      'name': serializer.toJson<String>(name),
      'nickname': serializer.toJson<String?>(nickname),
      'isActive': serializer.toJson<bool>(isActive),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Zone copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> createdBy = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    int? code,
    String? name,
    Value<String?> nickname = const Value.absent(),
    bool? isActive,
    int? sortOrder,
  }) => Zone(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    code: code ?? this.code,
    name: name ?? this.name,
    nickname: nickname.present ? nickname.value : this.nickname,
    isActive: isActive ?? this.isActive,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Zone copyWithCompanion(ZonesCompanion data) {
    return Zone(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Zone(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('nickname: $nickname, ')
          ..write('isActive: $isActive, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    createdBy,
    deviceId,
    deletedAt,
    code,
    name,
    nickname,
    isActive,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Zone &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.createdBy == this.createdBy &&
          other.deviceId == this.deviceId &&
          other.deletedAt == this.deletedAt &&
          other.code == this.code &&
          other.name == this.name &&
          other.nickname == this.nickname &&
          other.isActive == this.isActive &&
          other.sortOrder == this.sortOrder);
}

class ZonesCompanion extends UpdateCompanion<Zone> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> createdBy;
  final Value<String?> deviceId;
  final Value<DateTime?> deletedAt;
  final Value<int> code;
  final Value<String> name;
  final Value<String?> nickname;
  final Value<bool> isActive;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ZonesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.nickname = const Value.absent(),
    this.isActive = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ZonesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required int code,
    required String name,
    this.nickname = const Value.absent(),
    this.isActive = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : code = Value(code),
       name = Value(name);
  static Insertable<Zone> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? createdBy,
    Expression<String>? deviceId,
    Expression<DateTime>? deletedAt,
    Expression<int>? code,
    Expression<String>? name,
    Expression<String>? nickname,
    Expression<bool>? isActive,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdBy != null) 'created_by': createdBy,
      if (deviceId != null) 'device_id': deviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (nickname != null) 'nickname': nickname,
      if (isActive != null) 'is_active': isActive,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ZonesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? createdBy,
    Value<String?>? deviceId,
    Value<DateTime?>? deletedAt,
    Value<int>? code,
    Value<String>? name,
    Value<String?>? nickname,
    Value<bool>? isActive,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return ZonesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      code: code ?? this.code,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (code.present) {
      map['code'] = Variable<int>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ZonesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('nickname: $nickname, ')
          ..write('isActive: $isActive, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MembersTable extends Members with TableInfo<$MembersTable, Member> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memberNoMeta = const VerificationMeta(
    'memberNo',
  );
  @override
  late final GeneratedColumn<String> memberNo = GeneratedColumn<String>(
    'member_no',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateOfBirthMeta = const VerificationMeta(
    'dateOfBirth',
  );
  @override
  late final GeneratedColumn<DateTime> dateOfBirth = GeneratedColumn<DateTime>(
    'date_of_birth',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nationalityMeta = const VerificationMeta(
    'nationality',
  );
  @override
  late final GeneratedColumn<String> nationality = GeneratedColumn<String>(
    'nationality',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occupationMeta = const VerificationMeta(
    'occupation',
  );
  @override
  late final GeneratedColumn<String> occupation = GeneratedColumn<String>(
    'occupation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maritalStatusMeta = const VerificationMeta(
    'maritalStatus',
  );
  @override
  late final GeneratedColumn<String> maritalStatus = GeneratedColumn<String>(
    'marital_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _whatsappMeta = const VerificationMeta(
    'whatsapp',
  );
  @override
  late final GeneratedColumn<String> whatsapp = GeneratedColumn<String>(
    'whatsapp',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gpsAddressMeta = const VerificationMeta(
    'gpsAddress',
  );
  @override
  late final GeneratedColumn<String> gpsAddress = GeneratedColumn<String>(
    'gps_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emergencyNameMeta = const VerificationMeta(
    'emergencyName',
  );
  @override
  late final GeneratedColumn<String> emergencyName = GeneratedColumn<String>(
    'emergency_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emergencyPhoneMeta = const VerificationMeta(
    'emergencyPhone',
  );
  @override
  late final GeneratedColumn<String> emergencyPhone = GeneratedColumn<String>(
    'emergency_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateJoinedMeta = const VerificationMeta(
    'dateJoined',
  );
  @override
  late final GeneratedColumn<DateTime> dateJoined = GeneratedColumn<DateTime>(
    'date_joined',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MemberStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(MemberStatus.active.name),
      ).withConverter<MemberStatus>($MembersTable.$converterstatus);
  static const VerificationMeta _statusDateMeta = const VerificationMeta(
    'statusDate',
  );
  @override
  late final GeneratedColumn<DateTime> statusDate = GeneratedColumn<DateTime>(
    'status_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    createdBy,
    deviceId,
    deletedAt,
    memberNo,
    fullName,
    gender,
    dateOfBirth,
    nationality,
    occupation,
    maritalStatus,
    location,
    phone,
    whatsapp,
    email,
    address,
    gpsAddress,
    emergencyName,
    emergencyPhone,
    dateJoined,
    status,
    statusDate,
    photoPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'members';
  @override
  VerificationContext validateIntegrity(
    Insertable<Member> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('member_no')) {
      context.handle(
        _memberNoMeta,
        memberNo.isAcceptableOrUnknown(data['member_no']!, _memberNoMeta),
      );
    } else if (isInserting) {
      context.missing(_memberNoMeta);
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fullNameMeta);
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('date_of_birth')) {
      context.handle(
        _dateOfBirthMeta,
        dateOfBirth.isAcceptableOrUnknown(
          data['date_of_birth']!,
          _dateOfBirthMeta,
        ),
      );
    }
    if (data.containsKey('nationality')) {
      context.handle(
        _nationalityMeta,
        nationality.isAcceptableOrUnknown(
          data['nationality']!,
          _nationalityMeta,
        ),
      );
    }
    if (data.containsKey('occupation')) {
      context.handle(
        _occupationMeta,
        occupation.isAcceptableOrUnknown(data['occupation']!, _occupationMeta),
      );
    }
    if (data.containsKey('marital_status')) {
      context.handle(
        _maritalStatusMeta,
        maritalStatus.isAcceptableOrUnknown(
          data['marital_status']!,
          _maritalStatusMeta,
        ),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('whatsapp')) {
      context.handle(
        _whatsappMeta,
        whatsapp.isAcceptableOrUnknown(data['whatsapp']!, _whatsappMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('gps_address')) {
      context.handle(
        _gpsAddressMeta,
        gpsAddress.isAcceptableOrUnknown(data['gps_address']!, _gpsAddressMeta),
      );
    }
    if (data.containsKey('emergency_name')) {
      context.handle(
        _emergencyNameMeta,
        emergencyName.isAcceptableOrUnknown(
          data['emergency_name']!,
          _emergencyNameMeta,
        ),
      );
    }
    if (data.containsKey('emergency_phone')) {
      context.handle(
        _emergencyPhoneMeta,
        emergencyPhone.isAcceptableOrUnknown(
          data['emergency_phone']!,
          _emergencyPhoneMeta,
        ),
      );
    }
    if (data.containsKey('date_joined')) {
      context.handle(
        _dateJoinedMeta,
        dateJoined.isAcceptableOrUnknown(data['date_joined']!, _dateJoinedMeta),
      );
    } else if (isInserting) {
      context.missing(_dateJoinedMeta);
    }
    if (data.containsKey('status_date')) {
      context.handle(
        _statusDateMeta,
        statusDate.isAcceptableOrUnknown(data['status_date']!, _statusDateMeta),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Member map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Member(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      memberNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_no'],
      )!,
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      )!,
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      ),
      dateOfBirth: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_of_birth'],
      ),
      nationality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nationality'],
      ),
      occupation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occupation'],
      ),
      maritalStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}marital_status'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      whatsapp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}whatsapp'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      gpsAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gps_address'],
      ),
      emergencyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emergency_name'],
      ),
      emergencyPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emergency_phone'],
      ),
      dateJoined: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_joined'],
      )!,
      status: $MembersTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      statusDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}status_date'],
      ),
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
    );
  }

  @override
  $MembersTable createAlias(String alias) {
    return $MembersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MemberStatus, String, String> $converterstatus =
      const EnumNameConverter<MemberStatus>(MemberStatus.values);
}

class Member extends DataClass implements Insertable<Member> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? deviceId;
  final DateTime? deletedAt;
  final String memberNo;
  final String fullName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? nationality;
  final String? occupation;
  final String? maritalStatus;
  final String? location;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? address;
  final String? gpsAddress;
  final String? emergencyName;
  final String? emergencyPhone;
  final DateTime dateJoined;
  final MemberStatus status;
  final DateTime? statusDate;
  final String? photoPath;
  const Member({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.deletedAt,
    required this.memberNo,
    required this.fullName,
    this.gender,
    this.dateOfBirth,
    this.nationality,
    this.occupation,
    this.maritalStatus,
    this.location,
    this.phone,
    this.whatsapp,
    this.email,
    this.address,
    this.gpsAddress,
    this.emergencyName,
    this.emergencyPhone,
    required this.dateJoined,
    required this.status,
    this.statusDate,
    this.photoPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['member_no'] = Variable<String>(memberNo);
    map['full_name'] = Variable<String>(fullName);
    if (!nullToAbsent || gender != null) {
      map['gender'] = Variable<String>(gender);
    }
    if (!nullToAbsent || dateOfBirth != null) {
      map['date_of_birth'] = Variable<DateTime>(dateOfBirth);
    }
    if (!nullToAbsent || nationality != null) {
      map['nationality'] = Variable<String>(nationality);
    }
    if (!nullToAbsent || occupation != null) {
      map['occupation'] = Variable<String>(occupation);
    }
    if (!nullToAbsent || maritalStatus != null) {
      map['marital_status'] = Variable<String>(maritalStatus);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || whatsapp != null) {
      map['whatsapp'] = Variable<String>(whatsapp);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || gpsAddress != null) {
      map['gps_address'] = Variable<String>(gpsAddress);
    }
    if (!nullToAbsent || emergencyName != null) {
      map['emergency_name'] = Variable<String>(emergencyName);
    }
    if (!nullToAbsent || emergencyPhone != null) {
      map['emergency_phone'] = Variable<String>(emergencyPhone);
    }
    map['date_joined'] = Variable<DateTime>(dateJoined);
    {
      map['status'] = Variable<String>(
        $MembersTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || statusDate != null) {
      map['status_date'] = Variable<DateTime>(statusDate);
    }
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    return map;
  }

  MembersCompanion toCompanion(bool nullToAbsent) {
    return MembersCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      memberNo: Value(memberNo),
      fullName: Value(fullName),
      gender: gender == null && nullToAbsent
          ? const Value.absent()
          : Value(gender),
      dateOfBirth: dateOfBirth == null && nullToAbsent
          ? const Value.absent()
          : Value(dateOfBirth),
      nationality: nationality == null && nullToAbsent
          ? const Value.absent()
          : Value(nationality),
      occupation: occupation == null && nullToAbsent
          ? const Value.absent()
          : Value(occupation),
      maritalStatus: maritalStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(maritalStatus),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      whatsapp: whatsapp == null && nullToAbsent
          ? const Value.absent()
          : Value(whatsapp),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      gpsAddress: gpsAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(gpsAddress),
      emergencyName: emergencyName == null && nullToAbsent
          ? const Value.absent()
          : Value(emergencyName),
      emergencyPhone: emergencyPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(emergencyPhone),
      dateJoined: Value(dateJoined),
      status: Value(status),
      statusDate: statusDate == null && nullToAbsent
          ? const Value.absent()
          : Value(statusDate),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
    );
  }

  factory Member.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Member(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      memberNo: serializer.fromJson<String>(json['memberNo']),
      fullName: serializer.fromJson<String>(json['fullName']),
      gender: serializer.fromJson<String?>(json['gender']),
      dateOfBirth: serializer.fromJson<DateTime?>(json['dateOfBirth']),
      nationality: serializer.fromJson<String?>(json['nationality']),
      occupation: serializer.fromJson<String?>(json['occupation']),
      maritalStatus: serializer.fromJson<String?>(json['maritalStatus']),
      location: serializer.fromJson<String?>(json['location']),
      phone: serializer.fromJson<String?>(json['phone']),
      whatsapp: serializer.fromJson<String?>(json['whatsapp']),
      email: serializer.fromJson<String?>(json['email']),
      address: serializer.fromJson<String?>(json['address']),
      gpsAddress: serializer.fromJson<String?>(json['gpsAddress']),
      emergencyName: serializer.fromJson<String?>(json['emergencyName']),
      emergencyPhone: serializer.fromJson<String?>(json['emergencyPhone']),
      dateJoined: serializer.fromJson<DateTime>(json['dateJoined']),
      status: $MembersTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      statusDate: serializer.fromJson<DateTime?>(json['statusDate']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdBy': serializer.toJson<String?>(createdBy),
      'deviceId': serializer.toJson<String?>(deviceId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'memberNo': serializer.toJson<String>(memberNo),
      'fullName': serializer.toJson<String>(fullName),
      'gender': serializer.toJson<String?>(gender),
      'dateOfBirth': serializer.toJson<DateTime?>(dateOfBirth),
      'nationality': serializer.toJson<String?>(nationality),
      'occupation': serializer.toJson<String?>(occupation),
      'maritalStatus': serializer.toJson<String?>(maritalStatus),
      'location': serializer.toJson<String?>(location),
      'phone': serializer.toJson<String?>(phone),
      'whatsapp': serializer.toJson<String?>(whatsapp),
      'email': serializer.toJson<String?>(email),
      'address': serializer.toJson<String?>(address),
      'gpsAddress': serializer.toJson<String?>(gpsAddress),
      'emergencyName': serializer.toJson<String?>(emergencyName),
      'emergencyPhone': serializer.toJson<String?>(emergencyPhone),
      'dateJoined': serializer.toJson<DateTime>(dateJoined),
      'status': serializer.toJson<String>(
        $MembersTable.$converterstatus.toJson(status),
      ),
      'statusDate': serializer.toJson<DateTime?>(statusDate),
      'photoPath': serializer.toJson<String?>(photoPath),
    };
  }

  Member copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> createdBy = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    String? memberNo,
    String? fullName,
    Value<String?> gender = const Value.absent(),
    Value<DateTime?> dateOfBirth = const Value.absent(),
    Value<String?> nationality = const Value.absent(),
    Value<String?> occupation = const Value.absent(),
    Value<String?> maritalStatus = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> whatsapp = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> gpsAddress = const Value.absent(),
    Value<String?> emergencyName = const Value.absent(),
    Value<String?> emergencyPhone = const Value.absent(),
    DateTime? dateJoined,
    MemberStatus? status,
    Value<DateTime?> statusDate = const Value.absent(),
    Value<String?> photoPath = const Value.absent(),
  }) => Member(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    memberNo: memberNo ?? this.memberNo,
    fullName: fullName ?? this.fullName,
    gender: gender.present ? gender.value : this.gender,
    dateOfBirth: dateOfBirth.present ? dateOfBirth.value : this.dateOfBirth,
    nationality: nationality.present ? nationality.value : this.nationality,
    occupation: occupation.present ? occupation.value : this.occupation,
    maritalStatus: maritalStatus.present
        ? maritalStatus.value
        : this.maritalStatus,
    location: location.present ? location.value : this.location,
    phone: phone.present ? phone.value : this.phone,
    whatsapp: whatsapp.present ? whatsapp.value : this.whatsapp,
    email: email.present ? email.value : this.email,
    address: address.present ? address.value : this.address,
    gpsAddress: gpsAddress.present ? gpsAddress.value : this.gpsAddress,
    emergencyName: emergencyName.present
        ? emergencyName.value
        : this.emergencyName,
    emergencyPhone: emergencyPhone.present
        ? emergencyPhone.value
        : this.emergencyPhone,
    dateJoined: dateJoined ?? this.dateJoined,
    status: status ?? this.status,
    statusDate: statusDate.present ? statusDate.value : this.statusDate,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
  );
  Member copyWithCompanion(MembersCompanion data) {
    return Member(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      memberNo: data.memberNo.present ? data.memberNo.value : this.memberNo,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      gender: data.gender.present ? data.gender.value : this.gender,
      dateOfBirth: data.dateOfBirth.present
          ? data.dateOfBirth.value
          : this.dateOfBirth,
      nationality: data.nationality.present
          ? data.nationality.value
          : this.nationality,
      occupation: data.occupation.present
          ? data.occupation.value
          : this.occupation,
      maritalStatus: data.maritalStatus.present
          ? data.maritalStatus.value
          : this.maritalStatus,
      location: data.location.present ? data.location.value : this.location,
      phone: data.phone.present ? data.phone.value : this.phone,
      whatsapp: data.whatsapp.present ? data.whatsapp.value : this.whatsapp,
      email: data.email.present ? data.email.value : this.email,
      address: data.address.present ? data.address.value : this.address,
      gpsAddress: data.gpsAddress.present
          ? data.gpsAddress.value
          : this.gpsAddress,
      emergencyName: data.emergencyName.present
          ? data.emergencyName.value
          : this.emergencyName,
      emergencyPhone: data.emergencyPhone.present
          ? data.emergencyPhone.value
          : this.emergencyPhone,
      dateJoined: data.dateJoined.present
          ? data.dateJoined.value
          : this.dateJoined,
      status: data.status.present ? data.status.value : this.status,
      statusDate: data.statusDate.present
          ? data.statusDate.value
          : this.statusDate,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Member(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('memberNo: $memberNo, ')
          ..write('fullName: $fullName, ')
          ..write('gender: $gender, ')
          ..write('dateOfBirth: $dateOfBirth, ')
          ..write('nationality: $nationality, ')
          ..write('occupation: $occupation, ')
          ..write('maritalStatus: $maritalStatus, ')
          ..write('location: $location, ')
          ..write('phone: $phone, ')
          ..write('whatsapp: $whatsapp, ')
          ..write('email: $email, ')
          ..write('address: $address, ')
          ..write('gpsAddress: $gpsAddress, ')
          ..write('emergencyName: $emergencyName, ')
          ..write('emergencyPhone: $emergencyPhone, ')
          ..write('dateJoined: $dateJoined, ')
          ..write('status: $status, ')
          ..write('statusDate: $statusDate, ')
          ..write('photoPath: $photoPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    updatedAt,
    createdBy,
    deviceId,
    deletedAt,
    memberNo,
    fullName,
    gender,
    dateOfBirth,
    nationality,
    occupation,
    maritalStatus,
    location,
    phone,
    whatsapp,
    email,
    address,
    gpsAddress,
    emergencyName,
    emergencyPhone,
    dateJoined,
    status,
    statusDate,
    photoPath,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Member &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.createdBy == this.createdBy &&
          other.deviceId == this.deviceId &&
          other.deletedAt == this.deletedAt &&
          other.memberNo == this.memberNo &&
          other.fullName == this.fullName &&
          other.gender == this.gender &&
          other.dateOfBirth == this.dateOfBirth &&
          other.nationality == this.nationality &&
          other.occupation == this.occupation &&
          other.maritalStatus == this.maritalStatus &&
          other.location == this.location &&
          other.phone == this.phone &&
          other.whatsapp == this.whatsapp &&
          other.email == this.email &&
          other.address == this.address &&
          other.gpsAddress == this.gpsAddress &&
          other.emergencyName == this.emergencyName &&
          other.emergencyPhone == this.emergencyPhone &&
          other.dateJoined == this.dateJoined &&
          other.status == this.status &&
          other.statusDate == this.statusDate &&
          other.photoPath == this.photoPath);
}

class MembersCompanion extends UpdateCompanion<Member> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> createdBy;
  final Value<String?> deviceId;
  final Value<DateTime?> deletedAt;
  final Value<String> memberNo;
  final Value<String> fullName;
  final Value<String?> gender;
  final Value<DateTime?> dateOfBirth;
  final Value<String?> nationality;
  final Value<String?> occupation;
  final Value<String?> maritalStatus;
  final Value<String?> location;
  final Value<String?> phone;
  final Value<String?> whatsapp;
  final Value<String?> email;
  final Value<String?> address;
  final Value<String?> gpsAddress;
  final Value<String?> emergencyName;
  final Value<String?> emergencyPhone;
  final Value<DateTime> dateJoined;
  final Value<MemberStatus> status;
  final Value<DateTime?> statusDate;
  final Value<String?> photoPath;
  final Value<int> rowid;
  const MembersCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.memberNo = const Value.absent(),
    this.fullName = const Value.absent(),
    this.gender = const Value.absent(),
    this.dateOfBirth = const Value.absent(),
    this.nationality = const Value.absent(),
    this.occupation = const Value.absent(),
    this.maritalStatus = const Value.absent(),
    this.location = const Value.absent(),
    this.phone = const Value.absent(),
    this.whatsapp = const Value.absent(),
    this.email = const Value.absent(),
    this.address = const Value.absent(),
    this.gpsAddress = const Value.absent(),
    this.emergencyName = const Value.absent(),
    this.emergencyPhone = const Value.absent(),
    this.dateJoined = const Value.absent(),
    this.status = const Value.absent(),
    this.statusDate = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MembersCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String memberNo,
    required String fullName,
    this.gender = const Value.absent(),
    this.dateOfBirth = const Value.absent(),
    this.nationality = const Value.absent(),
    this.occupation = const Value.absent(),
    this.maritalStatus = const Value.absent(),
    this.location = const Value.absent(),
    this.phone = const Value.absent(),
    this.whatsapp = const Value.absent(),
    this.email = const Value.absent(),
    this.address = const Value.absent(),
    this.gpsAddress = const Value.absent(),
    this.emergencyName = const Value.absent(),
    this.emergencyPhone = const Value.absent(),
    required DateTime dateJoined,
    this.status = const Value.absent(),
    this.statusDate = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : memberNo = Value(memberNo),
       fullName = Value(fullName),
       dateJoined = Value(dateJoined);
  static Insertable<Member> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? createdBy,
    Expression<String>? deviceId,
    Expression<DateTime>? deletedAt,
    Expression<String>? memberNo,
    Expression<String>? fullName,
    Expression<String>? gender,
    Expression<DateTime>? dateOfBirth,
    Expression<String>? nationality,
    Expression<String>? occupation,
    Expression<String>? maritalStatus,
    Expression<String>? location,
    Expression<String>? phone,
    Expression<String>? whatsapp,
    Expression<String>? email,
    Expression<String>? address,
    Expression<String>? gpsAddress,
    Expression<String>? emergencyName,
    Expression<String>? emergencyPhone,
    Expression<DateTime>? dateJoined,
    Expression<String>? status,
    Expression<DateTime>? statusDate,
    Expression<String>? photoPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdBy != null) 'created_by': createdBy,
      if (deviceId != null) 'device_id': deviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (memberNo != null) 'member_no': memberNo,
      if (fullName != null) 'full_name': fullName,
      if (gender != null) 'gender': gender,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (nationality != null) 'nationality': nationality,
      if (occupation != null) 'occupation': occupation,
      if (maritalStatus != null) 'marital_status': maritalStatus,
      if (location != null) 'location': location,
      if (phone != null) 'phone': phone,
      if (whatsapp != null) 'whatsapp': whatsapp,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (gpsAddress != null) 'gps_address': gpsAddress,
      if (emergencyName != null) 'emergency_name': emergencyName,
      if (emergencyPhone != null) 'emergency_phone': emergencyPhone,
      if (dateJoined != null) 'date_joined': dateJoined,
      if (status != null) 'status': status,
      if (statusDate != null) 'status_date': statusDate,
      if (photoPath != null) 'photo_path': photoPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MembersCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? createdBy,
    Value<String?>? deviceId,
    Value<DateTime?>? deletedAt,
    Value<String>? memberNo,
    Value<String>? fullName,
    Value<String?>? gender,
    Value<DateTime?>? dateOfBirth,
    Value<String?>? nationality,
    Value<String?>? occupation,
    Value<String?>? maritalStatus,
    Value<String?>? location,
    Value<String?>? phone,
    Value<String?>? whatsapp,
    Value<String?>? email,
    Value<String?>? address,
    Value<String?>? gpsAddress,
    Value<String?>? emergencyName,
    Value<String?>? emergencyPhone,
    Value<DateTime>? dateJoined,
    Value<MemberStatus>? status,
    Value<DateTime?>? statusDate,
    Value<String?>? photoPath,
    Value<int>? rowid,
  }) {
    return MembersCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      memberNo: memberNo ?? this.memberNo,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      nationality: nationality ?? this.nationality,
      occupation: occupation ?? this.occupation,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      location: location ?? this.location,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      address: address ?? this.address,
      gpsAddress: gpsAddress ?? this.gpsAddress,
      emergencyName: emergencyName ?? this.emergencyName,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      dateJoined: dateJoined ?? this.dateJoined,
      status: status ?? this.status,
      statusDate: statusDate ?? this.statusDate,
      photoPath: photoPath ?? this.photoPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (memberNo.present) {
      map['member_no'] = Variable<String>(memberNo.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (dateOfBirth.present) {
      map['date_of_birth'] = Variable<DateTime>(dateOfBirth.value);
    }
    if (nationality.present) {
      map['nationality'] = Variable<String>(nationality.value);
    }
    if (occupation.present) {
      map['occupation'] = Variable<String>(occupation.value);
    }
    if (maritalStatus.present) {
      map['marital_status'] = Variable<String>(maritalStatus.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (whatsapp.present) {
      map['whatsapp'] = Variable<String>(whatsapp.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (gpsAddress.present) {
      map['gps_address'] = Variable<String>(gpsAddress.value);
    }
    if (emergencyName.present) {
      map['emergency_name'] = Variable<String>(emergencyName.value);
    }
    if (emergencyPhone.present) {
      map['emergency_phone'] = Variable<String>(emergencyPhone.value);
    }
    if (dateJoined.present) {
      map['date_joined'] = Variable<DateTime>(dateJoined.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $MembersTable.$converterstatus.toSql(status.value),
      );
    }
    if (statusDate.present) {
      map['status_date'] = Variable<DateTime>(statusDate.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MembersCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('memberNo: $memberNo, ')
          ..write('fullName: $fullName, ')
          ..write('gender: $gender, ')
          ..write('dateOfBirth: $dateOfBirth, ')
          ..write('nationality: $nationality, ')
          ..write('occupation: $occupation, ')
          ..write('maritalStatus: $maritalStatus, ')
          ..write('location: $location, ')
          ..write('phone: $phone, ')
          ..write('whatsapp: $whatsapp, ')
          ..write('email: $email, ')
          ..write('address: $address, ')
          ..write('gpsAddress: $gpsAddress, ')
          ..write('emergencyName: $emergencyName, ')
          ..write('emergencyPhone: $emergencyPhone, ')
          ..write('dateJoined: $dateJoined, ')
          ..write('status: $status, ')
          ..write('statusDate: $statusDate, ')
          ..write('photoPath: $photoPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemberZonesTable extends MemberZones
    with TableInfo<$MemberZonesTable, MemberZone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemberZonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  @override
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES members (id)',
    ),
  );
  static const VerificationMeta _zoneIdMeta = const VerificationMeta('zoneId');
  @override
  late final GeneratedColumn<String> zoneId = GeneratedColumn<String>(
    'zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES zones (id)',
    ),
  );
  static const VerificationMeta _isPrimaryMeta = const VerificationMeta(
    'isPrimary',
  );
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
    'is_primary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_primary" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _assignedOnMeta = const VerificationMeta(
    'assignedOn',
  );
  @override
  late final GeneratedColumn<DateTime> assignedOn = GeneratedColumn<DateTime>(
    'assigned_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    createdBy,
    deviceId,
    deletedAt,
    memberId,
    zoneId,
    isPrimary,
    assignedOn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'member_zones';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemberZone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memberIdMeta);
    }
    if (data.containsKey('zone_id')) {
      context.handle(
        _zoneIdMeta,
        zoneId.isAcceptableOrUnknown(data['zone_id']!, _zoneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_zoneIdMeta);
    }
    if (data.containsKey('is_primary')) {
      context.handle(
        _isPrimaryMeta,
        isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta),
      );
    }
    if (data.containsKey('assigned_on')) {
      context.handle(
        _assignedOnMeta,
        assignedOn.isAcceptableOrUnknown(data['assigned_on']!, _assignedOnMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {memberId, zoneId},
  ];
  @override
  MemberZone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemberZone(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      )!,
      zoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zone_id'],
      )!,
      isPrimary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_primary'],
      )!,
      assignedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}assigned_on'],
      )!,
    );
  }

  @override
  $MemberZonesTable createAlias(String alias) {
    return $MemberZonesTable(attachedDatabase, alias);
  }
}

class MemberZone extends DataClass implements Insertable<MemberZone> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? deviceId;
  final DateTime? deletedAt;
  final String memberId;
  final String zoneId;
  final bool isPrimary;
  final DateTime assignedOn;
  const MemberZone({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.deletedAt,
    required this.memberId,
    required this.zoneId,
    required this.isPrimary,
    required this.assignedOn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['member_id'] = Variable<String>(memberId);
    map['zone_id'] = Variable<String>(zoneId);
    map['is_primary'] = Variable<bool>(isPrimary);
    map['assigned_on'] = Variable<DateTime>(assignedOn);
    return map;
  }

  MemberZonesCompanion toCompanion(bool nullToAbsent) {
    return MemberZonesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      memberId: Value(memberId),
      zoneId: Value(zoneId),
      isPrimary: Value(isPrimary),
      assignedOn: Value(assignedOn),
    );
  }

  factory MemberZone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemberZone(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      memberId: serializer.fromJson<String>(json['memberId']),
      zoneId: serializer.fromJson<String>(json['zoneId']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      assignedOn: serializer.fromJson<DateTime>(json['assignedOn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdBy': serializer.toJson<String?>(createdBy),
      'deviceId': serializer.toJson<String?>(deviceId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'memberId': serializer.toJson<String>(memberId),
      'zoneId': serializer.toJson<String>(zoneId),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'assignedOn': serializer.toJson<DateTime>(assignedOn),
    };
  }

  MemberZone copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> createdBy = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    String? memberId,
    String? zoneId,
    bool? isPrimary,
    DateTime? assignedOn,
  }) => MemberZone(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    memberId: memberId ?? this.memberId,
    zoneId: zoneId ?? this.zoneId,
    isPrimary: isPrimary ?? this.isPrimary,
    assignedOn: assignedOn ?? this.assignedOn,
  );
  MemberZone copyWithCompanion(MemberZonesCompanion data) {
    return MemberZone(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      zoneId: data.zoneId.present ? data.zoneId.value : this.zoneId,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      assignedOn: data.assignedOn.present
          ? data.assignedOn.value
          : this.assignedOn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemberZone(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('memberId: $memberId, ')
          ..write('zoneId: $zoneId, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('assignedOn: $assignedOn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    createdBy,
    deviceId,
    deletedAt,
    memberId,
    zoneId,
    isPrimary,
    assignedOn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemberZone &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.createdBy == this.createdBy &&
          other.deviceId == this.deviceId &&
          other.deletedAt == this.deletedAt &&
          other.memberId == this.memberId &&
          other.zoneId == this.zoneId &&
          other.isPrimary == this.isPrimary &&
          other.assignedOn == this.assignedOn);
}

class MemberZonesCompanion extends UpdateCompanion<MemberZone> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> createdBy;
  final Value<String?> deviceId;
  final Value<DateTime?> deletedAt;
  final Value<String> memberId;
  final Value<String> zoneId;
  final Value<bool> isPrimary;
  final Value<DateTime> assignedOn;
  final Value<int> rowid;
  const MemberZonesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.memberId = const Value.absent(),
    this.zoneId = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.assignedOn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemberZonesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String memberId,
    required String zoneId,
    this.isPrimary = const Value.absent(),
    this.assignedOn = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : memberId = Value(memberId),
       zoneId = Value(zoneId);
  static Insertable<MemberZone> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? createdBy,
    Expression<String>? deviceId,
    Expression<DateTime>? deletedAt,
    Expression<String>? memberId,
    Expression<String>? zoneId,
    Expression<bool>? isPrimary,
    Expression<DateTime>? assignedOn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdBy != null) 'created_by': createdBy,
      if (deviceId != null) 'device_id': deviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (memberId != null) 'member_id': memberId,
      if (zoneId != null) 'zone_id': zoneId,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (assignedOn != null) 'assigned_on': assignedOn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemberZonesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? createdBy,
    Value<String?>? deviceId,
    Value<DateTime?>? deletedAt,
    Value<String>? memberId,
    Value<String>? zoneId,
    Value<bool>? isPrimary,
    Value<DateTime>? assignedOn,
    Value<int>? rowid,
  }) {
    return MemberZonesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      memberId: memberId ?? this.memberId,
      zoneId: zoneId ?? this.zoneId,
      isPrimary: isPrimary ?? this.isPrimary,
      assignedOn: assignedOn ?? this.assignedOn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (zoneId.present) {
      map['zone_id'] = Variable<String>(zoneId.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (assignedOn.present) {
      map['assigned_on'] = Variable<DateTime>(assignedOn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemberZonesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('memberId: $memberId, ')
          ..write('zoneId: $zoneId, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('assignedOn: $assignedOn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RolesTable extends Roles with TableInfo<$RolesTable, Role> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RolesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta(
    'isSystem',
  );
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    createdBy,
    deviceId,
    deletedAt,
    key,
    name,
    level,
    isSystem,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'roles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Role> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Role map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Role(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
    );
  }

  @override
  $RolesTable createAlias(String alias) {
    return $RolesTable(attachedDatabase, alias);
  }
}

class Role extends DataClass implements Insertable<Role> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? deviceId;
  final DateTime? deletedAt;
  final String key;
  final String name;
  final String level;
  final bool isSystem;
  const Role({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.deletedAt,
    required this.key,
    required this.name,
    required this.level,
    required this.isSystem,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['key'] = Variable<String>(key);
    map['name'] = Variable<String>(name);
    map['level'] = Variable<String>(level);
    map['is_system'] = Variable<bool>(isSystem);
    return map;
  }

  RolesCompanion toCompanion(bool nullToAbsent) {
    return RolesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      key: Value(key),
      name: Value(name),
      level: Value(level),
      isSystem: Value(isSystem),
    );
  }

  factory Role.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Role(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      key: serializer.fromJson<String>(json['key']),
      name: serializer.fromJson<String>(json['name']),
      level: serializer.fromJson<String>(json['level']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdBy': serializer.toJson<String?>(createdBy),
      'deviceId': serializer.toJson<String?>(deviceId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'key': serializer.toJson<String>(key),
      'name': serializer.toJson<String>(name),
      'level': serializer.toJson<String>(level),
      'isSystem': serializer.toJson<bool>(isSystem),
    };
  }

  Role copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> createdBy = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    String? key,
    String? name,
    String? level,
    bool? isSystem,
  }) => Role(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    key: key ?? this.key,
    name: name ?? this.name,
    level: level ?? this.level,
    isSystem: isSystem ?? this.isSystem,
  );
  Role copyWithCompanion(RolesCompanion data) {
    return Role(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      key: data.key.present ? data.key.value : this.key,
      name: data.name.present ? data.name.value : this.name,
      level: data.level.present ? data.level.value : this.level,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Role(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('level: $level, ')
          ..write('isSystem: $isSystem')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    createdBy,
    deviceId,
    deletedAt,
    key,
    name,
    level,
    isSystem,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Role &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.createdBy == this.createdBy &&
          other.deviceId == this.deviceId &&
          other.deletedAt == this.deletedAt &&
          other.key == this.key &&
          other.name == this.name &&
          other.level == this.level &&
          other.isSystem == this.isSystem);
}

class RolesCompanion extends UpdateCompanion<Role> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> createdBy;
  final Value<String?> deviceId;
  final Value<DateTime?> deletedAt;
  final Value<String> key;
  final Value<String> name;
  final Value<String> level;
  final Value<bool> isSystem;
  final Value<int> rowid;
  const RolesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.key = const Value.absent(),
    this.name = const Value.absent(),
    this.level = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RolesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String key,
    required String name,
    required String level,
    this.isSystem = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       name = Value(name),
       level = Value(level);
  static Insertable<Role> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? createdBy,
    Expression<String>? deviceId,
    Expression<DateTime>? deletedAt,
    Expression<String>? key,
    Expression<String>? name,
    Expression<String>? level,
    Expression<bool>? isSystem,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdBy != null) 'created_by': createdBy,
      if (deviceId != null) 'device_id': deviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (key != null) 'key': key,
      if (name != null) 'name': name,
      if (level != null) 'level': level,
      if (isSystem != null) 'is_system': isSystem,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RolesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? createdBy,
    Value<String?>? deviceId,
    Value<DateTime?>? deletedAt,
    Value<String>? key,
    Value<String>? name,
    Value<String>? level,
    Value<bool>? isSystem,
    Value<int>? rowid,
  }) {
    return RolesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      key: key ?? this.key,
      name: name ?? this.name,
      level: level ?? this.level,
      isSystem: isSystem ?? this.isSystem,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RolesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('level: $level, ')
          ..write('isSystem: $isSystem, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RolePermissionsTable extends RolePermissions
    with TableInfo<$RolePermissionsTable, RolePermission> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RolePermissionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _roleIdMeta = const VerificationMeta('roleId');
  @override
  late final GeneratedColumn<String> roleId = GeneratedColumn<String>(
    'role_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES roles (id)',
    ),
  );
  static const VerificationMeta _permissionMeta = const VerificationMeta(
    'permission',
  );
  @override
  late final GeneratedColumn<String> permission = GeneratedColumn<String>(
    'permission',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [roleId, permission];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'role_permissions';
  @override
  VerificationContext validateIntegrity(
    Insertable<RolePermission> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('role_id')) {
      context.handle(
        _roleIdMeta,
        roleId.isAcceptableOrUnknown(data['role_id']!, _roleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roleIdMeta);
    }
    if (data.containsKey('permission')) {
      context.handle(
        _permissionMeta,
        permission.isAcceptableOrUnknown(data['permission']!, _permissionMeta),
      );
    } else if (isInserting) {
      context.missing(_permissionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {roleId, permission};
  @override
  RolePermission map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RolePermission(
      roleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_id'],
      )!,
      permission: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permission'],
      )!,
    );
  }

  @override
  $RolePermissionsTable createAlias(String alias) {
    return $RolePermissionsTable(attachedDatabase, alias);
  }
}

class RolePermission extends DataClass implements Insertable<RolePermission> {
  final String roleId;
  final String permission;
  const RolePermission({required this.roleId, required this.permission});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['role_id'] = Variable<String>(roleId);
    map['permission'] = Variable<String>(permission);
    return map;
  }

  RolePermissionsCompanion toCompanion(bool nullToAbsent) {
    return RolePermissionsCompanion(
      roleId: Value(roleId),
      permission: Value(permission),
    );
  }

  factory RolePermission.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RolePermission(
      roleId: serializer.fromJson<String>(json['roleId']),
      permission: serializer.fromJson<String>(json['permission']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'roleId': serializer.toJson<String>(roleId),
      'permission': serializer.toJson<String>(permission),
    };
  }

  RolePermission copyWith({String? roleId, String? permission}) =>
      RolePermission(
        roleId: roleId ?? this.roleId,
        permission: permission ?? this.permission,
      );
  RolePermission copyWithCompanion(RolePermissionsCompanion data) {
    return RolePermission(
      roleId: data.roleId.present ? data.roleId.value : this.roleId,
      permission: data.permission.present
          ? data.permission.value
          : this.permission,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RolePermission(')
          ..write('roleId: $roleId, ')
          ..write('permission: $permission')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(roleId, permission);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RolePermission &&
          other.roleId == this.roleId &&
          other.permission == this.permission);
}

class RolePermissionsCompanion extends UpdateCompanion<RolePermission> {
  final Value<String> roleId;
  final Value<String> permission;
  final Value<int> rowid;
  const RolePermissionsCompanion({
    this.roleId = const Value.absent(),
    this.permission = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RolePermissionsCompanion.insert({
    required String roleId,
    required String permission,
    this.rowid = const Value.absent(),
  }) : roleId = Value(roleId),
       permission = Value(permission);
  static Insertable<RolePermission> custom({
    Expression<String>? roleId,
    Expression<String>? permission,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (roleId != null) 'role_id': roleId,
      if (permission != null) 'permission': permission,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RolePermissionsCompanion copyWith({
    Value<String>? roleId,
    Value<String>? permission,
    Value<int>? rowid,
  }) {
    return RolePermissionsCompanion(
      roleId: roleId ?? this.roleId,
      permission: permission ?? this.permission,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (roleId.present) {
      map['role_id'] = Variable<String>(roleId.value);
    }
    if (permission.present) {
      map['permission'] = Variable<String>(permission.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RolePermissionsCompanion(')
          ..write('roleId: $roleId, ')
          ..write('permission: $permission, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  @override
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES members (id)',
    ),
  );
  static const VerificationMeta _roleIdMeta = const VerificationMeta('roleId');
  @override
  late final GeneratedColumn<String> roleId = GeneratedColumn<String>(
    'role_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES roles (id)',
    ),
  );
  static const VerificationMeta _passwordHashMeta = const VerificationMeta(
    'passwordHash',
  );
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
    'password_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinHashMeta = const VerificationMeta(
    'pinHash',
  );
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
    'pin_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _biometricEnabledMeta = const VerificationMeta(
    'biometricEnabled',
  );
  @override
  late final GeneratedColumn<bool> biometricEnabled = GeneratedColumn<bool>(
    'biometric_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("biometric_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _failedAttemptsMeta = const VerificationMeta(
    'failedAttempts',
  );
  @override
  late final GeneratedColumn<int> failedAttempts = GeneratedColumn<int>(
    'failed_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lockedUntilMeta = const VerificationMeta(
    'lockedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> lockedUntil = GeneratedColumn<DateTime>(
    'locked_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastLoginAtMeta = const VerificationMeta(
    'lastLoginAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastLoginAt = GeneratedColumn<DateTime>(
    'last_login_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    createdBy,
    deviceId,
    deletedAt,
    username,
    displayName,
    memberId,
    roleId,
    passwordHash,
    pinHash,
    biometricEnabled,
    isActive,
    failedAttempts,
    lockedUntil,
    lastLoginAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<User> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    }
    if (data.containsKey('role_id')) {
      context.handle(
        _roleIdMeta,
        roleId.isAcceptableOrUnknown(data['role_id']!, _roleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roleIdMeta);
    }
    if (data.containsKey('password_hash')) {
      context.handle(
        _passwordHashMeta,
        passwordHash.isAcceptableOrUnknown(
          data['password_hash']!,
          _passwordHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordHashMeta);
    }
    if (data.containsKey('pin_hash')) {
      context.handle(
        _pinHashMeta,
        pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta),
      );
    }
    if (data.containsKey('biometric_enabled')) {
      context.handle(
        _biometricEnabledMeta,
        biometricEnabled.isAcceptableOrUnknown(
          data['biometric_enabled']!,
          _biometricEnabledMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('failed_attempts')) {
      context.handle(
        _failedAttemptsMeta,
        failedAttempts.isAcceptableOrUnknown(
          data['failed_attempts']!,
          _failedAttemptsMeta,
        ),
      );
    }
    if (data.containsKey('locked_until')) {
      context.handle(
        _lockedUntilMeta,
        lockedUntil.isAcceptableOrUnknown(
          data['locked_until']!,
          _lockedUntilMeta,
        ),
      );
    }
    if (data.containsKey('last_login_at')) {
      context.handle(
        _lastLoginAtMeta,
        lastLoginAt.isAcceptableOrUnknown(
          data['last_login_at']!,
          _lastLoginAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      ),
      roleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_id'],
      )!,
      passwordHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_hash'],
      )!,
      pinHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_hash'],
      ),
      biometricEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}biometric_enabled'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      failedAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed_attempts'],
      )!,
      lockedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}locked_until'],
      ),
      lastLoginAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_login_at'],
      ),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? deviceId;
  final DateTime? deletedAt;
  final String username;
  final String displayName;
  final String? memberId;
  final String roleId;
  final String passwordHash;
  final String? pinHash;
  final bool biometricEnabled;
  final bool isActive;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final DateTime? lastLoginAt;
  const User({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.deletedAt,
    required this.username,
    required this.displayName,
    this.memberId,
    required this.roleId,
    required this.passwordHash,
    this.pinHash,
    required this.biometricEnabled,
    required this.isActive,
    required this.failedAttempts,
    this.lockedUntil,
    this.lastLoginAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['username'] = Variable<String>(username);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || memberId != null) {
      map['member_id'] = Variable<String>(memberId);
    }
    map['role_id'] = Variable<String>(roleId);
    map['password_hash'] = Variable<String>(passwordHash);
    if (!nullToAbsent || pinHash != null) {
      map['pin_hash'] = Variable<String>(pinHash);
    }
    map['biometric_enabled'] = Variable<bool>(biometricEnabled);
    map['is_active'] = Variable<bool>(isActive);
    map['failed_attempts'] = Variable<int>(failedAttempts);
    if (!nullToAbsent || lockedUntil != null) {
      map['locked_until'] = Variable<DateTime>(lockedUntil);
    }
    if (!nullToAbsent || lastLoginAt != null) {
      map['last_login_at'] = Variable<DateTime>(lastLoginAt);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      username: Value(username),
      displayName: Value(displayName),
      memberId: memberId == null && nullToAbsent
          ? const Value.absent()
          : Value(memberId),
      roleId: Value(roleId),
      passwordHash: Value(passwordHash),
      pinHash: pinHash == null && nullToAbsent
          ? const Value.absent()
          : Value(pinHash),
      biometricEnabled: Value(biometricEnabled),
      isActive: Value(isActive),
      failedAttempts: Value(failedAttempts),
      lockedUntil: lockedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(lockedUntil),
      lastLoginAt: lastLoginAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLoginAt),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      username: serializer.fromJson<String>(json['username']),
      displayName: serializer.fromJson<String>(json['displayName']),
      memberId: serializer.fromJson<String?>(json['memberId']),
      roleId: serializer.fromJson<String>(json['roleId']),
      passwordHash: serializer.fromJson<String>(json['passwordHash']),
      pinHash: serializer.fromJson<String?>(json['pinHash']),
      biometricEnabled: serializer.fromJson<bool>(json['biometricEnabled']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      failedAttempts: serializer.fromJson<int>(json['failedAttempts']),
      lockedUntil: serializer.fromJson<DateTime?>(json['lockedUntil']),
      lastLoginAt: serializer.fromJson<DateTime?>(json['lastLoginAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdBy': serializer.toJson<String?>(createdBy),
      'deviceId': serializer.toJson<String?>(deviceId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'username': serializer.toJson<String>(username),
      'displayName': serializer.toJson<String>(displayName),
      'memberId': serializer.toJson<String?>(memberId),
      'roleId': serializer.toJson<String>(roleId),
      'passwordHash': serializer.toJson<String>(passwordHash),
      'pinHash': serializer.toJson<String?>(pinHash),
      'biometricEnabled': serializer.toJson<bool>(biometricEnabled),
      'isActive': serializer.toJson<bool>(isActive),
      'failedAttempts': serializer.toJson<int>(failedAttempts),
      'lockedUntil': serializer.toJson<DateTime?>(lockedUntil),
      'lastLoginAt': serializer.toJson<DateTime?>(lastLoginAt),
    };
  }

  User copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> createdBy = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    String? username,
    String? displayName,
    Value<String?> memberId = const Value.absent(),
    String? roleId,
    String? passwordHash,
    Value<String?> pinHash = const Value.absent(),
    bool? biometricEnabled,
    bool? isActive,
    int? failedAttempts,
    Value<DateTime?> lockedUntil = const Value.absent(),
    Value<DateTime?> lastLoginAt = const Value.absent(),
  }) => User(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    memberId: memberId.present ? memberId.value : this.memberId,
    roleId: roleId ?? this.roleId,
    passwordHash: passwordHash ?? this.passwordHash,
    pinHash: pinHash.present ? pinHash.value : this.pinHash,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    isActive: isActive ?? this.isActive,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntil: lockedUntil.present ? lockedUntil.value : this.lockedUntil,
    lastLoginAt: lastLoginAt.present ? lastLoginAt.value : this.lastLoginAt,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      username: data.username.present ? data.username.value : this.username,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      roleId: data.roleId.present ? data.roleId.value : this.roleId,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      biometricEnabled: data.biometricEnabled.present
          ? data.biometricEnabled.value
          : this.biometricEnabled,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      failedAttempts: data.failedAttempts.present
          ? data.failedAttempts.value
          : this.failedAttempts,
      lockedUntil: data.lockedUntil.present
          ? data.lockedUntil.value
          : this.lockedUntil,
      lastLoginAt: data.lastLoginAt.present
          ? data.lastLoginAt.value
          : this.lastLoginAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('username: $username, ')
          ..write('displayName: $displayName, ')
          ..write('memberId: $memberId, ')
          ..write('roleId: $roleId, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('pinHash: $pinHash, ')
          ..write('biometricEnabled: $biometricEnabled, ')
          ..write('isActive: $isActive, ')
          ..write('failedAttempts: $failedAttempts, ')
          ..write('lockedUntil: $lockedUntil, ')
          ..write('lastLoginAt: $lastLoginAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    createdBy,
    deviceId,
    deletedAt,
    username,
    displayName,
    memberId,
    roleId,
    passwordHash,
    pinHash,
    biometricEnabled,
    isActive,
    failedAttempts,
    lockedUntil,
    lastLoginAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.createdBy == this.createdBy &&
          other.deviceId == this.deviceId &&
          other.deletedAt == this.deletedAt &&
          other.username == this.username &&
          other.displayName == this.displayName &&
          other.memberId == this.memberId &&
          other.roleId == this.roleId &&
          other.passwordHash == this.passwordHash &&
          other.pinHash == this.pinHash &&
          other.biometricEnabled == this.biometricEnabled &&
          other.isActive == this.isActive &&
          other.failedAttempts == this.failedAttempts &&
          other.lockedUntil == this.lockedUntil &&
          other.lastLoginAt == this.lastLoginAt);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> createdBy;
  final Value<String?> deviceId;
  final Value<DateTime?> deletedAt;
  final Value<String> username;
  final Value<String> displayName;
  final Value<String?> memberId;
  final Value<String> roleId;
  final Value<String> passwordHash;
  final Value<String?> pinHash;
  final Value<bool> biometricEnabled;
  final Value<bool> isActive;
  final Value<int> failedAttempts;
  final Value<DateTime?> lockedUntil;
  final Value<DateTime?> lastLoginAt;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.username = const Value.absent(),
    this.displayName = const Value.absent(),
    this.memberId = const Value.absent(),
    this.roleId = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.biometricEnabled = const Value.absent(),
    this.isActive = const Value.absent(),
    this.failedAttempts = const Value.absent(),
    this.lockedUntil = const Value.absent(),
    this.lastLoginAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String username,
    required String displayName,
    this.memberId = const Value.absent(),
    required String roleId,
    required String passwordHash,
    this.pinHash = const Value.absent(),
    this.biometricEnabled = const Value.absent(),
    this.isActive = const Value.absent(),
    this.failedAttempts = const Value.absent(),
    this.lockedUntil = const Value.absent(),
    this.lastLoginAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : username = Value(username),
       displayName = Value(displayName),
       roleId = Value(roleId),
       passwordHash = Value(passwordHash);
  static Insertable<User> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? createdBy,
    Expression<String>? deviceId,
    Expression<DateTime>? deletedAt,
    Expression<String>? username,
    Expression<String>? displayName,
    Expression<String>? memberId,
    Expression<String>? roleId,
    Expression<String>? passwordHash,
    Expression<String>? pinHash,
    Expression<bool>? biometricEnabled,
    Expression<bool>? isActive,
    Expression<int>? failedAttempts,
    Expression<DateTime>? lockedUntil,
    Expression<DateTime>? lastLoginAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdBy != null) 'created_by': createdBy,
      if (deviceId != null) 'device_id': deviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (username != null) 'username': username,
      if (displayName != null) 'display_name': displayName,
      if (memberId != null) 'member_id': memberId,
      if (roleId != null) 'role_id': roleId,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (pinHash != null) 'pin_hash': pinHash,
      if (biometricEnabled != null) 'biometric_enabled': biometricEnabled,
      if (isActive != null) 'is_active': isActive,
      if (failedAttempts != null) 'failed_attempts': failedAttempts,
      if (lockedUntil != null) 'locked_until': lockedUntil,
      if (lastLoginAt != null) 'last_login_at': lastLoginAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? createdBy,
    Value<String?>? deviceId,
    Value<DateTime?>? deletedAt,
    Value<String>? username,
    Value<String>? displayName,
    Value<String?>? memberId,
    Value<String>? roleId,
    Value<String>? passwordHash,
    Value<String?>? pinHash,
    Value<bool>? biometricEnabled,
    Value<bool>? isActive,
    Value<int>? failedAttempts,
    Value<DateTime?>? lockedUntil,
    Value<DateTime?>? lastLoginAt,
    Value<int>? rowid,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      memberId: memberId ?? this.memberId,
      roleId: roleId ?? this.roleId,
      passwordHash: passwordHash ?? this.passwordHash,
      pinHash: pinHash ?? this.pinHash,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      isActive: isActive ?? this.isActive,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (roleId.present) {
      map['role_id'] = Variable<String>(roleId.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (biometricEnabled.present) {
      map['biometric_enabled'] = Variable<bool>(biometricEnabled.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (failedAttempts.present) {
      map['failed_attempts'] = Variable<int>(failedAttempts.value);
    }
    if (lockedUntil.present) {
      map['locked_until'] = Variable<DateTime>(lockedUntil.value);
    }
    if (lastLoginAt.present) {
      map['last_login_at'] = Variable<DateTime>(lastLoginAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('username: $username, ')
          ..write('displayName: $displayName, ')
          ..write('memberId: $memberId, ')
          ..write('roleId: $roleId, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('pinHash: $pinHash, ')
          ..write('biometricEnabled: $biometricEnabled, ')
          ..write('isActive: $isActive, ')
          ..write('failedAttempts: $failedAttempts, ')
          ..write('lockedUntil: $lockedUntil, ')
          ..write('lastLoginAt: $lastLoginAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditLogsTable extends AuditLogs
    with TableInfo<$AuditLogsTable, AuditLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _oldValueMeta = const VerificationMeta(
    'oldValue',
  );
  @override
  late final GeneratedColumn<String> oldValue = GeneratedColumn<String>(
    'old_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _newValueMeta = const VerificationMeta(
    'newValue',
  );
  @override
  late final GeneratedColumn<String> newValue = GeneratedColumn<String>(
    'new_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    username,
    action,
    entity,
    entityId,
    oldValue,
    newValue,
    at,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    }
    if (data.containsKey('old_value')) {
      context.handle(
        _oldValueMeta,
        oldValue.isAcceptableOrUnknown(data['old_value']!, _oldValueMeta),
      );
    }
    if (data.containsKey('new_value')) {
      context.handle(
        _newValueMeta,
        newValue.isAcceptableOrUnknown(data['new_value']!, _newValueMeta),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      ),
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      ),
      oldValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_value'],
      ),
      newValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_value'],
      ),
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
    );
  }

  @override
  $AuditLogsTable createAlias(String alias) {
    return $AuditLogsTable(attachedDatabase, alias);
  }
}

class AuditLog extends DataClass implements Insertable<AuditLog> {
  final String id;
  final String? userId;
  final String? username;
  final String action;
  final String? entity;
  final String? entityId;
  final String? oldValue;
  final String? newValue;
  final DateTime at;
  final String? deviceId;
  const AuditLog({
    required this.id,
    this.userId,
    this.username,
    required this.action,
    this.entity,
    this.entityId,
    this.oldValue,
    this.newValue,
    required this.at,
    this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || entity != null) {
      map['entity'] = Variable<String>(entity);
    }
    if (!nullToAbsent || entityId != null) {
      map['entity_id'] = Variable<String>(entityId);
    }
    if (!nullToAbsent || oldValue != null) {
      map['old_value'] = Variable<String>(oldValue);
    }
    if (!nullToAbsent || newValue != null) {
      map['new_value'] = Variable<String>(newValue);
    }
    map['at'] = Variable<DateTime>(at);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    return map;
  }

  AuditLogsCompanion toCompanion(bool nullToAbsent) {
    return AuditLogsCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      action: Value(action),
      entity: entity == null && nullToAbsent
          ? const Value.absent()
          : Value(entity),
      entityId: entityId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityId),
      oldValue: oldValue == null && nullToAbsent
          ? const Value.absent()
          : Value(oldValue),
      newValue: newValue == null && nullToAbsent
          ? const Value.absent()
          : Value(newValue),
      at: Value(at),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
    );
  }

  factory AuditLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLog(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      username: serializer.fromJson<String?>(json['username']),
      action: serializer.fromJson<String>(json['action']),
      entity: serializer.fromJson<String?>(json['entity']),
      entityId: serializer.fromJson<String?>(json['entityId']),
      oldValue: serializer.fromJson<String?>(json['oldValue']),
      newValue: serializer.fromJson<String?>(json['newValue']),
      at: serializer.fromJson<DateTime>(json['at']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'username': serializer.toJson<String?>(username),
      'action': serializer.toJson<String>(action),
      'entity': serializer.toJson<String?>(entity),
      'entityId': serializer.toJson<String?>(entityId),
      'oldValue': serializer.toJson<String?>(oldValue),
      'newValue': serializer.toJson<String?>(newValue),
      'at': serializer.toJson<DateTime>(at),
      'deviceId': serializer.toJson<String?>(deviceId),
    };
  }

  AuditLog copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<String?> username = const Value.absent(),
    String? action,
    Value<String?> entity = const Value.absent(),
    Value<String?> entityId = const Value.absent(),
    Value<String?> oldValue = const Value.absent(),
    Value<String?> newValue = const Value.absent(),
    DateTime? at,
    Value<String?> deviceId = const Value.absent(),
  }) => AuditLog(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    username: username.present ? username.value : this.username,
    action: action ?? this.action,
    entity: entity.present ? entity.value : this.entity,
    entityId: entityId.present ? entityId.value : this.entityId,
    oldValue: oldValue.present ? oldValue.value : this.oldValue,
    newValue: newValue.present ? newValue.value : this.newValue,
    at: at ?? this.at,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
  );
  AuditLog copyWithCompanion(AuditLogsCompanion data) {
    return AuditLog(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      username: data.username.present ? data.username.value : this.username,
      action: data.action.present ? data.action.value : this.action,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      oldValue: data.oldValue.present ? data.oldValue.value : this.oldValue,
      newValue: data.newValue.present ? data.newValue.value : this.newValue,
      at: data.at.present ? data.at.value : this.at,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLog(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('username: $username, ')
          ..write('action: $action, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue, ')
          ..write('at: $at, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    username,
    action,
    entity,
    entityId,
    oldValue,
    newValue,
    at,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLog &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.username == this.username &&
          other.action == this.action &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.oldValue == this.oldValue &&
          other.newValue == this.newValue &&
          other.at == this.at &&
          other.deviceId == this.deviceId);
}

class AuditLogsCompanion extends UpdateCompanion<AuditLog> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String?> username;
  final Value<String> action;
  final Value<String?> entity;
  final Value<String?> entityId;
  final Value<String?> oldValue;
  final Value<String?> newValue;
  final Value<DateTime> at;
  final Value<String?> deviceId;
  final Value<int> rowid;
  const AuditLogsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.username = const Value.absent(),
    this.action = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
    this.at = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditLogsCompanion.insert({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.username = const Value.absent(),
    required String action,
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
    this.at = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : action = Value(action);
  static Insertable<AuditLog> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? username,
    Expression<String>? action,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? oldValue,
    Expression<String>? newValue,
    Expression<DateTime>? at,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (username != null) 'username': username,
      if (action != null) 'action': action,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (oldValue != null) 'old_value': oldValue,
      if (newValue != null) 'new_value': newValue,
      if (at != null) 'at': at,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditLogsCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String?>? username,
    Value<String>? action,
    Value<String?>? entity,
    Value<String?>? entityId,
    Value<String?>? oldValue,
    Value<String?>? newValue,
    Value<DateTime>? at,
    Value<String?>? deviceId,
    Value<int>? rowid,
  }) {
    return AuditLogsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      action: action ?? this.action,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
      at: at ?? this.at,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (oldValue.present) {
      map['old_value'] = Variable<String>(oldValue.value);
    }
    if (newValue.present) {
      map['new_value'] = Variable<String>(newValue.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('username: $username, ')
          ..write('action: $action, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue, ')
          ..write('at: $at, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OrgSettingsTable orgSettings = $OrgSettingsTable(this);
  late final $ZonesTable zones = $ZonesTable(this);
  late final $MembersTable members = $MembersTable(this);
  late final $MemberZonesTable memberZones = $MemberZonesTable(this);
  late final $RolesTable roles = $RolesTable(this);
  late final $RolePermissionsTable rolePermissions = $RolePermissionsTable(
    this,
  );
  late final $UsersTable users = $UsersTable(this);
  late final $AuditLogsTable auditLogs = $AuditLogsTable(this);
  late final Index membersFullName = Index(
    'members_full_name',
    'CREATE INDEX members_full_name ON members (full_name)',
  );
  late final Index membersPhone = Index(
    'members_phone',
    'CREATE INDEX members_phone ON members (phone)',
  );
  late final Index memberZonesMember = Index(
    'member_zones_member',
    'CREATE INDEX member_zones_member ON member_zones (member_id)',
  );
  late final Index auditLogsAt = Index(
    'audit_logs_at',
    'CREATE INDEX audit_logs_at ON audit_logs (at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    orgSettings,
    zones,
    members,
    memberZones,
    roles,
    rolePermissions,
    users,
    auditLogs,
    membersFullName,
    membersPhone,
    memberZonesMember,
    auditLogsAt,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$OrgSettingsTableCreateCompanionBuilder =
    OrgSettingsCompanion Function({
      Value<int> id,
      required String name,
      required String shortName,
      required String memberIdPrefix,
      Value<int> nextMemberNo,
      Value<String> currency,
      Value<String?> poweredBy,
      Value<String?> logoPath,
    });
typedef $$OrgSettingsTableUpdateCompanionBuilder =
    OrgSettingsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> shortName,
      Value<String> memberIdPrefix,
      Value<int> nextMemberNo,
      Value<String> currency,
      Value<String?> poweredBy,
      Value<String?> logoPath,
    });

class $$OrgSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $OrgSettingsTable> {
  $$OrgSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shortName => $composableBuilder(
    column: $table.shortName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberIdPrefix => $composableBuilder(
    column: $table.memberIdPrefix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextMemberNo => $composableBuilder(
    column: $table.nextMemberNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get poweredBy => $composableBuilder(
    column: $table.poweredBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoPath => $composableBuilder(
    column: $table.logoPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OrgSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $OrgSettingsTable> {
  $$OrgSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shortName => $composableBuilder(
    column: $table.shortName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberIdPrefix => $composableBuilder(
    column: $table.memberIdPrefix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextMemberNo => $composableBuilder(
    column: $table.nextMemberNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get poweredBy => $composableBuilder(
    column: $table.poweredBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoPath => $composableBuilder(
    column: $table.logoPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrgSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrgSettingsTable> {
  $$OrgSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get shortName =>
      $composableBuilder(column: $table.shortName, builder: (column) => column);

  GeneratedColumn<String> get memberIdPrefix => $composableBuilder(
    column: $table.memberIdPrefix,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextMemberNo => $composableBuilder(
    column: $table.nextMemberNo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get poweredBy =>
      $composableBuilder(column: $table.poweredBy, builder: (column) => column);

  GeneratedColumn<String> get logoPath =>
      $composableBuilder(column: $table.logoPath, builder: (column) => column);
}

class $$OrgSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrgSettingsTable,
          OrgSetting,
          $$OrgSettingsTableFilterComposer,
          $$OrgSettingsTableOrderingComposer,
          $$OrgSettingsTableAnnotationComposer,
          $$OrgSettingsTableCreateCompanionBuilder,
          $$OrgSettingsTableUpdateCompanionBuilder,
          (
            OrgSetting,
            BaseReferences<_$AppDatabase, $OrgSettingsTable, OrgSetting>,
          ),
          OrgSetting,
          PrefetchHooks Function()
        > {
  $$OrgSettingsTableTableManager(_$AppDatabase db, $OrgSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrgSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrgSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrgSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> shortName = const Value.absent(),
                Value<String> memberIdPrefix = const Value.absent(),
                Value<int> nextMemberNo = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> poweredBy = const Value.absent(),
                Value<String?> logoPath = const Value.absent(),
              }) => OrgSettingsCompanion(
                id: id,
                name: name,
                shortName: shortName,
                memberIdPrefix: memberIdPrefix,
                nextMemberNo: nextMemberNo,
                currency: currency,
                poweredBy: poweredBy,
                logoPath: logoPath,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String shortName,
                required String memberIdPrefix,
                Value<int> nextMemberNo = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> poweredBy = const Value.absent(),
                Value<String?> logoPath = const Value.absent(),
              }) => OrgSettingsCompanion.insert(
                id: id,
                name: name,
                shortName: shortName,
                memberIdPrefix: memberIdPrefix,
                nextMemberNo: nextMemberNo,
                currency: currency,
                poweredBy: poweredBy,
                logoPath: logoPath,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OrgSettingsTable, OrgSetting>(table),
                  BaseReferences<_$AppDatabase, $OrgSettingsTable, OrgSetting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OrgSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrgSettingsTable,
      OrgSetting,
      $$OrgSettingsTableFilterComposer,
      $$OrgSettingsTableOrderingComposer,
      $$OrgSettingsTableAnnotationComposer,
      $$OrgSettingsTableCreateCompanionBuilder,
      $$OrgSettingsTableUpdateCompanionBuilder,
      (
        OrgSetting,
        BaseReferences<_$AppDatabase, $OrgSettingsTable, OrgSetting>,
      ),
      OrgSetting,
      PrefetchHooks Function()
    >;
typedef $$ZonesTableCreateCompanionBuilder =
    ZonesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> createdBy,
      Value<String?> deviceId,
      Value<DateTime?> deletedAt,
      required int code,
      required String name,
      Value<String?> nickname,
      Value<bool> isActive,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$ZonesTableUpdateCompanionBuilder =
    ZonesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> createdBy,
      Value<String?> deviceId,
      Value<DateTime?> deletedAt,
      Value<int> code,
      Value<String> name,
      Value<String?> nickname,
      Value<bool> isActive,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$ZonesTableReferences
    extends BaseReferences<_$AppDatabase, $ZonesTable, Zone> {
  $$ZonesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MemberZonesTable, List<MemberZone>>
  _memberZonesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memberZones,
    aliasName: 'zones__id__member_zones__zone_id',
  );

  $$MemberZonesTableProcessedTableManager get memberZonesRefs {
    final manager = $$MemberZonesTableTableManager(
      $_db,
      $_db.memberZones,
    ).filter((f) => f.zoneId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memberZonesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ZonesTableFilterComposer extends Composer<_$AppDatabase, $ZonesTable> {
  $$ZonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> memberZonesRefs(
    Expression<bool> Function($$MemberZonesTableFilterComposer f) f,
  ) {
    final $$MemberZonesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memberZones,
      getReferencedColumn: (t) => t.zoneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemberZonesTableFilterComposer(
            $db: $db,
            $table: $db.memberZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ZonesTableOrderingComposer
    extends Composer<_$AppDatabase, $ZonesTable> {
  $$ZonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ZonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ZonesTable> {
  $$ZonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> memberZonesRefs<T extends Object>(
    Expression<T> Function($$MemberZonesTableAnnotationComposer a) f,
  ) {
    final $$MemberZonesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memberZones,
      getReferencedColumn: (t) => t.zoneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemberZonesTableAnnotationComposer(
            $db: $db,
            $table: $db.memberZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ZonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ZonesTable,
          Zone,
          $$ZonesTableFilterComposer,
          $$ZonesTableOrderingComposer,
          $$ZonesTableAnnotationComposer,
          $$ZonesTableCreateCompanionBuilder,
          $$ZonesTableUpdateCompanionBuilder,
          (Zone, $$ZonesTableReferences),
          Zone,
          PrefetchHooks Function({bool memberZonesRefs})
        > {
  $$ZonesTableTableManager(_$AppDatabase db, $ZonesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ZonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ZonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ZonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ZonesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                deviceId: deviceId,
                deletedAt: deletedAt,
                code: code,
                name: name,
                nickname: nickname,
                isActive: isActive,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required int code,
                required String name,
                Value<String?> nickname = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ZonesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                deviceId: deviceId,
                deletedAt: deletedAt,
                code: code,
                name: name,
                nickname: nickname,
                isActive: isActive,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ZonesTable, Zone>(table),
                  $$ZonesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memberZonesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (memberZonesRefs) db.memberZones],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (memberZonesRefs)
                    await $_getPrefetchedData<Zone, $ZonesTable, MemberZone>(
                      currentTable: table,
                      referencedTable: $$ZonesTableReferences
                          ._memberZonesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ZonesTableReferences(db, table, p0).memberZonesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.zoneId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ZonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ZonesTable,
      Zone,
      $$ZonesTableFilterComposer,
      $$ZonesTableOrderingComposer,
      $$ZonesTableAnnotationComposer,
      $$ZonesTableCreateCompanionBuilder,
      $$ZonesTableUpdateCompanionBuilder,
      (Zone, $$ZonesTableReferences),
      Zone,
      PrefetchHooks Function({bool memberZonesRefs})
    >;
typedef $$MembersTableCreateCompanionBuilder =
    MembersCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> createdBy,
      Value<String?> deviceId,
      Value<DateTime?> deletedAt,
      required String memberNo,
      required String fullName,
      Value<String?> gender,
      Value<DateTime?> dateOfBirth,
      Value<String?> nationality,
      Value<String?> occupation,
      Value<String?> maritalStatus,
      Value<String?> location,
      Value<String?> phone,
      Value<String?> whatsapp,
      Value<String?> email,
      Value<String?> address,
      Value<String?> gpsAddress,
      Value<String?> emergencyName,
      Value<String?> emergencyPhone,
      required DateTime dateJoined,
      Value<MemberStatus> status,
      Value<DateTime?> statusDate,
      Value<String?> photoPath,
      Value<int> rowid,
    });
typedef $$MembersTableUpdateCompanionBuilder =
    MembersCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> createdBy,
      Value<String?> deviceId,
      Value<DateTime?> deletedAt,
      Value<String> memberNo,
      Value<String> fullName,
      Value<String?> gender,
      Value<DateTime?> dateOfBirth,
      Value<String?> nationality,
      Value<String?> occupation,
      Value<String?> maritalStatus,
      Value<String?> location,
      Value<String?> phone,
      Value<String?> whatsapp,
      Value<String?> email,
      Value<String?> address,
      Value<String?> gpsAddress,
      Value<String?> emergencyName,
      Value<String?> emergencyPhone,
      Value<DateTime> dateJoined,
      Value<MemberStatus> status,
      Value<DateTime?> statusDate,
      Value<String?> photoPath,
      Value<int> rowid,
    });

final class $$MembersTableReferences
    extends BaseReferences<_$AppDatabase, $MembersTable, Member> {
  $$MembersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MemberZonesTable, List<MemberZone>>
  _memberZonesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memberZones,
    aliasName: 'members__id__member_zones__member_id',
  );

  $$MemberZonesTableProcessedTableManager get memberZonesRefs {
    final manager = $$MemberZonesTableTableManager(
      $_db,
      $_db.memberZones,
    ).filter((f) => f.memberId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memberZonesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UsersTable, List<User>> _usersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.users,
    aliasName: 'members__id__users__member_id',
  );

  $$UsersTableProcessedTableManager get usersRefs {
    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.memberId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_usersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MembersTableFilterComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberNo => $composableBuilder(
    column: $table.memberNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateOfBirth => $composableBuilder(
    column: $table.dateOfBirth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nationality => $composableBuilder(
    column: $table.nationality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occupation => $composableBuilder(
    column: $table.occupation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get maritalStatus => $composableBuilder(
    column: $table.maritalStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get whatsapp => $composableBuilder(
    column: $table.whatsapp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gpsAddress => $composableBuilder(
    column: $table.gpsAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emergencyName => $composableBuilder(
    column: $table.emergencyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emergencyPhone => $composableBuilder(
    column: $table.emergencyPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateJoined => $composableBuilder(
    column: $table.dateJoined,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MemberStatus, MemberStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get statusDate => $composableBuilder(
    column: $table.statusDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> memberZonesRefs(
    Expression<bool> Function($$MemberZonesTableFilterComposer f) f,
  ) {
    final $$MemberZonesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memberZones,
      getReferencedColumn: (t) => t.memberId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemberZonesTableFilterComposer(
            $db: $db,
            $table: $db.memberZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> usersRefs(
    Expression<bool> Function($$UsersTableFilterComposer f) f,
  ) {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.memberId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MembersTableOrderingComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberNo => $composableBuilder(
    column: $table.memberNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateOfBirth => $composableBuilder(
    column: $table.dateOfBirth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nationality => $composableBuilder(
    column: $table.nationality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occupation => $composableBuilder(
    column: $table.occupation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get maritalStatus => $composableBuilder(
    column: $table.maritalStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get whatsapp => $composableBuilder(
    column: $table.whatsapp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gpsAddress => $composableBuilder(
    column: $table.gpsAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emergencyName => $composableBuilder(
    column: $table.emergencyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emergencyPhone => $composableBuilder(
    column: $table.emergencyPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateJoined => $composableBuilder(
    column: $table.dateJoined,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get statusDate => $composableBuilder(
    column: $table.statusDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get memberNo =>
      $composableBuilder(column: $table.memberNo, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<DateTime> get dateOfBirth => $composableBuilder(
    column: $table.dateOfBirth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nationality => $composableBuilder(
    column: $table.nationality,
    builder: (column) => column,
  );

  GeneratedColumn<String> get occupation => $composableBuilder(
    column: $table.occupation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get maritalStatus => $composableBuilder(
    column: $table.maritalStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get whatsapp =>
      $composableBuilder(column: $table.whatsapp, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get gpsAddress => $composableBuilder(
    column: $table.gpsAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get emergencyName => $composableBuilder(
    column: $table.emergencyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get emergencyPhone => $composableBuilder(
    column: $table.emergencyPhone,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dateJoined => $composableBuilder(
    column: $table.dateJoined,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MemberStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get statusDate => $composableBuilder(
    column: $table.statusDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  Expression<T> memberZonesRefs<T extends Object>(
    Expression<T> Function($$MemberZonesTableAnnotationComposer a) f,
  ) {
    final $$MemberZonesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memberZones,
      getReferencedColumn: (t) => t.memberId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemberZonesTableAnnotationComposer(
            $db: $db,
            $table: $db.memberZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> usersRefs<T extends Object>(
    Expression<T> Function($$UsersTableAnnotationComposer a) f,
  ) {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.memberId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MembersTable,
          Member,
          $$MembersTableFilterComposer,
          $$MembersTableOrderingComposer,
          $$MembersTableAnnotationComposer,
          $$MembersTableCreateCompanionBuilder,
          $$MembersTableUpdateCompanionBuilder,
          (Member, $$MembersTableReferences),
          Member,
          PrefetchHooks Function({bool memberZonesRefs, bool usersRefs})
        > {
  $$MembersTableTableManager(_$AppDatabase db, $MembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> memberNo = const Value.absent(),
                Value<String> fullName = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<DateTime?> dateOfBirth = const Value.absent(),
                Value<String?> nationality = const Value.absent(),
                Value<String?> occupation = const Value.absent(),
                Value<String?> maritalStatus = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> whatsapp = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> gpsAddress = const Value.absent(),
                Value<String?> emergencyName = const Value.absent(),
                Value<String?> emergencyPhone = const Value.absent(),
                Value<DateTime> dateJoined = const Value.absent(),
                Value<MemberStatus> status = const Value.absent(),
                Value<DateTime?> statusDate = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MembersCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                deviceId: deviceId,
                deletedAt: deletedAt,
                memberNo: memberNo,
                fullName: fullName,
                gender: gender,
                dateOfBirth: dateOfBirth,
                nationality: nationality,
                occupation: occupation,
                maritalStatus: maritalStatus,
                location: location,
                phone: phone,
                whatsapp: whatsapp,
                email: email,
                address: address,
                gpsAddress: gpsAddress,
                emergencyName: emergencyName,
                emergencyPhone: emergencyPhone,
                dateJoined: dateJoined,
                status: status,
                statusDate: statusDate,
                photoPath: photoPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required String memberNo,
                required String fullName,
                Value<String?> gender = const Value.absent(),
                Value<DateTime?> dateOfBirth = const Value.absent(),
                Value<String?> nationality = const Value.absent(),
                Value<String?> occupation = const Value.absent(),
                Value<String?> maritalStatus = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> whatsapp = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> gpsAddress = const Value.absent(),
                Value<String?> emergencyName = const Value.absent(),
                Value<String?> emergencyPhone = const Value.absent(),
                required DateTime dateJoined,
                Value<MemberStatus> status = const Value.absent(),
                Value<DateTime?> statusDate = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MembersCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                deviceId: deviceId,
                deletedAt: deletedAt,
                memberNo: memberNo,
                fullName: fullName,
                gender: gender,
                dateOfBirth: dateOfBirth,
                nationality: nationality,
                occupation: occupation,
                maritalStatus: maritalStatus,
                location: location,
                phone: phone,
                whatsapp: whatsapp,
                email: email,
                address: address,
                gpsAddress: gpsAddress,
                emergencyName: emergencyName,
                emergencyPhone: emergencyPhone,
                dateJoined: dateJoined,
                status: status,
                statusDate: statusDate,
                photoPath: photoPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MembersTable, Member>(table),
                  $$MembersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({memberZonesRefs = false, usersRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (memberZonesRefs) db.memberZones,
                    if (usersRefs) db.users,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (memberZonesRefs)
                        await $_getPrefetchedData<
                          Member,
                          $MembersTable,
                          MemberZone
                        >(
                          currentTable: table,
                          referencedTable: $$MembersTableReferences
                              ._memberZonesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MembersTableReferences(
                                db,
                                table,
                                p0,
                              ).memberZonesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.memberId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (usersRefs)
                        await $_getPrefetchedData<Member, $MembersTable, User>(
                          currentTable: table,
                          referencedTable: $$MembersTableReferences
                              ._usersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MembersTableReferences(db, table, p0).usersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.memberId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MembersTable,
      Member,
      $$MembersTableFilterComposer,
      $$MembersTableOrderingComposer,
      $$MembersTableAnnotationComposer,
      $$MembersTableCreateCompanionBuilder,
      $$MembersTableUpdateCompanionBuilder,
      (Member, $$MembersTableReferences),
      Member,
      PrefetchHooks Function({bool memberZonesRefs, bool usersRefs})
    >;
typedef $$MemberZonesTableCreateCompanionBuilder =
    MemberZonesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> createdBy,
      Value<String?> deviceId,
      Value<DateTime?> deletedAt,
      required String memberId,
      required String zoneId,
      Value<bool> isPrimary,
      Value<DateTime> assignedOn,
      Value<int> rowid,
    });
typedef $$MemberZonesTableUpdateCompanionBuilder =
    MemberZonesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> createdBy,
      Value<String?> deviceId,
      Value<DateTime?> deletedAt,
      Value<String> memberId,
      Value<String> zoneId,
      Value<bool> isPrimary,
      Value<DateTime> assignedOn,
      Value<int> rowid,
    });

final class $$MemberZonesTableReferences
    extends BaseReferences<_$AppDatabase, $MemberZonesTable, MemberZone> {
  $$MemberZonesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MembersTable _memberIdTable(_$AppDatabase db) =>
      db.members.createAlias('member_zones__member_id__members__id');

  $$MembersTableProcessedTableManager get memberId {
    final $_column = $_itemColumn<String>('member_id')!;

    final manager = $$MembersTableTableManager(
      $_db,
      $_db.members,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memberIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ZonesTable _zoneIdTable(_$AppDatabase db) =>
      db.zones.createAlias('member_zones__zone_id__zones__id');

  $$ZonesTableProcessedTableManager get zoneId {
    final $_column = $_itemColumn<String>('zone_id')!;

    final manager = $$ZonesTableTableManager(
      $_db,
      $_db.zones,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_zoneIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemberZonesTableFilterComposer
    extends Composer<_$AppDatabase, $MemberZonesTable> {
  $$MemberZonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get assignedOn => $composableBuilder(
    column: $table.assignedOn,
    builder: (column) => ColumnFilters(column),
  );

  $$MembersTableFilterComposer get memberId {
    final $$MembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memberId,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableFilterComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ZonesTableFilterComposer get zoneId {
    final $$ZonesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.zoneId,
      referencedTable: $db.zones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZonesTableFilterComposer(
            $db: $db,
            $table: $db.zones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemberZonesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemberZonesTable> {
  $$MemberZonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get assignedOn => $composableBuilder(
    column: $table.assignedOn,
    builder: (column) => ColumnOrderings(column),
  );

  $$MembersTableOrderingComposer get memberId {
    final $$MembersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memberId,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableOrderingComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ZonesTableOrderingComposer get zoneId {
    final $$ZonesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.zoneId,
      referencedTable: $db.zones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZonesTableOrderingComposer(
            $db: $db,
            $table: $db.zones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemberZonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemberZonesTable> {
  $$MemberZonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<DateTime> get assignedOn => $composableBuilder(
    column: $table.assignedOn,
    builder: (column) => column,
  );

  $$MembersTableAnnotationComposer get memberId {
    final $$MembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memberId,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableAnnotationComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ZonesTableAnnotationComposer get zoneId {
    final $$ZonesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.zoneId,
      referencedTable: $db.zones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZonesTableAnnotationComposer(
            $db: $db,
            $table: $db.zones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemberZonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemberZonesTable,
          MemberZone,
          $$MemberZonesTableFilterComposer,
          $$MemberZonesTableOrderingComposer,
          $$MemberZonesTableAnnotationComposer,
          $$MemberZonesTableCreateCompanionBuilder,
          $$MemberZonesTableUpdateCompanionBuilder,
          (MemberZone, $$MemberZonesTableReferences),
          MemberZone,
          PrefetchHooks Function({bool memberId, bool zoneId})
        > {
  $$MemberZonesTableTableManager(_$AppDatabase db, $MemberZonesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemberZonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemberZonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemberZonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> memberId = const Value.absent(),
                Value<String> zoneId = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<DateTime> assignedOn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemberZonesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                deviceId: deviceId,
                deletedAt: deletedAt,
                memberId: memberId,
                zoneId: zoneId,
                isPrimary: isPrimary,
                assignedOn: assignedOn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required String memberId,
                required String zoneId,
                Value<bool> isPrimary = const Value.absent(),
                Value<DateTime> assignedOn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemberZonesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                deviceId: deviceId,
                deletedAt: deletedAt,
                memberId: memberId,
                zoneId: zoneId,
                isPrimary: isPrimary,
                assignedOn: assignedOn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MemberZonesTable, MemberZone>(table),
                  $$MemberZonesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memberId = false, zoneId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (memberId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memberId,
                                referencedTable: $$MemberZonesTableReferences
                                    ._memberIdTable(db),
                                referencedColumn: $$MemberZonesTableReferences
                                    ._memberIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (zoneId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.zoneId,
                                referencedTable: $$MemberZonesTableReferences
                                    ._zoneIdTable(db),
                                referencedColumn: $$MemberZonesTableReferences
                                    ._zoneIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MemberZonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemberZonesTable,
      MemberZone,
      $$MemberZonesTableFilterComposer,
      $$MemberZonesTableOrderingComposer,
      $$MemberZonesTableAnnotationComposer,
      $$MemberZonesTableCreateCompanionBuilder,
      $$MemberZonesTableUpdateCompanionBuilder,
      (MemberZone, $$MemberZonesTableReferences),
      MemberZone,
      PrefetchHooks Function({bool memberId, bool zoneId})
    >;
typedef $$RolesTableCreateCompanionBuilder =
    RolesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> createdBy,
      Value<String?> deviceId,
      Value<DateTime?> deletedAt,
      required String key,
      required String name,
      required String level,
      Value<bool> isSystem,
      Value<int> rowid,
    });
typedef $$RolesTableUpdateCompanionBuilder =
    RolesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> createdBy,
      Value<String?> deviceId,
      Value<DateTime?> deletedAt,
      Value<String> key,
      Value<String> name,
      Value<String> level,
      Value<bool> isSystem,
      Value<int> rowid,
    });

final class $$RolesTableReferences
    extends BaseReferences<_$AppDatabase, $RolesTable, Role> {
  $$RolesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RolePermissionsTable, List<RolePermission>>
  _rolePermissionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.rolePermissions,
    aliasName: 'roles__id__role_permissions__role_id',
  );

  $$RolePermissionsTableProcessedTableManager get rolePermissionsRefs {
    final manager = $$RolePermissionsTableTableManager(
      $_db,
      $_db.rolePermissions,
    ).filter((f) => f.roleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _rolePermissionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UsersTable, List<User>> _usersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.users,
    aliasName: 'roles__id__users__role_id',
  );

  $$UsersTableProcessedTableManager get usersRefs {
    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.roleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_usersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RolesTableFilterComposer extends Composer<_$AppDatabase, $RolesTable> {
  $$RolesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> rolePermissionsRefs(
    Expression<bool> Function($$RolePermissionsTableFilterComposer f) f,
  ) {
    final $$RolePermissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rolePermissions,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolePermissionsTableFilterComposer(
            $db: $db,
            $table: $db.rolePermissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> usersRefs(
    Expression<bool> Function($$UsersTableFilterComposer f) f,
  ) {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RolesTableOrderingComposer
    extends Composer<_$AppDatabase, $RolesTable> {
  $$RolesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RolesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RolesTable> {
  $$RolesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  Expression<T> rolePermissionsRefs<T extends Object>(
    Expression<T> Function($$RolePermissionsTableAnnotationComposer a) f,
  ) {
    final $$RolePermissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rolePermissions,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolePermissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.rolePermissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> usersRefs<T extends Object>(
    Expression<T> Function($$UsersTableAnnotationComposer a) f,
  ) {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RolesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RolesTable,
          Role,
          $$RolesTableFilterComposer,
          $$RolesTableOrderingComposer,
          $$RolesTableAnnotationComposer,
          $$RolesTableCreateCompanionBuilder,
          $$RolesTableUpdateCompanionBuilder,
          (Role, $$RolesTableReferences),
          Role,
          PrefetchHooks Function({bool rolePermissionsRefs, bool usersRefs})
        > {
  $$RolesTableTableManager(_$AppDatabase db, $RolesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RolesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RolesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RolesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RolesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                deviceId: deviceId,
                deletedAt: deletedAt,
                key: key,
                name: name,
                level: level,
                isSystem: isSystem,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required String key,
                required String name,
                required String level,
                Value<bool> isSystem = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RolesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                deviceId: deviceId,
                deletedAt: deletedAt,
                key: key,
                name: name,
                level: level,
                isSystem: isSystem,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RolesTable, Role>(table),
                  $$RolesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({rolePermissionsRefs = false, usersRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (rolePermissionsRefs) db.rolePermissions,
                    if (usersRefs) db.users,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (rolePermissionsRefs)
                        await $_getPrefetchedData<
                          Role,
                          $RolesTable,
                          RolePermission
                        >(
                          currentTable: table,
                          referencedTable: $$RolesTableReferences
                              ._rolePermissionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RolesTableReferences(
                                db,
                                table,
                                p0,
                              ).rolePermissionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.roleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (usersRefs)
                        await $_getPrefetchedData<Role, $RolesTable, User>(
                          currentTable: table,
                          referencedTable: $$RolesTableReferences
                              ._usersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RolesTableReferences(db, table, p0).usersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.roleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RolesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RolesTable,
      Role,
      $$RolesTableFilterComposer,
      $$RolesTableOrderingComposer,
      $$RolesTableAnnotationComposer,
      $$RolesTableCreateCompanionBuilder,
      $$RolesTableUpdateCompanionBuilder,
      (Role, $$RolesTableReferences),
      Role,
      PrefetchHooks Function({bool rolePermissionsRefs, bool usersRefs})
    >;
typedef $$RolePermissionsTableCreateCompanionBuilder =
    RolePermissionsCompanion Function({
      required String roleId,
      required String permission,
      Value<int> rowid,
    });
typedef $$RolePermissionsTableUpdateCompanionBuilder =
    RolePermissionsCompanion Function({
      Value<String> roleId,
      Value<String> permission,
      Value<int> rowid,
    });

final class $$RolePermissionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $RolePermissionsTable, RolePermission> {
  $$RolePermissionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RolesTable _roleIdTable(_$AppDatabase db) =>
      db.roles.createAlias('role_permissions__role_id__roles__id');

  $$RolesTableProcessedTableManager get roleId {
    final $_column = $_itemColumn<String>('role_id')!;

    final manager = $$RolesTableTableManager(
      $_db,
      $_db.roles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_roleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RolePermissionsTableFilterComposer
    extends Composer<_$AppDatabase, $RolePermissionsTable> {
  $$RolePermissionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnFilters(column),
  );

  $$RolesTableFilterComposer get roleId {
    final $$RolesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableFilterComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RolePermissionsTableOrderingComposer
    extends Composer<_$AppDatabase, $RolePermissionsTable> {
  $$RolePermissionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnOrderings(column),
  );

  $$RolesTableOrderingComposer get roleId {
    final $$RolesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableOrderingComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RolePermissionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RolePermissionsTable> {
  $$RolePermissionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => column,
  );

  $$RolesTableAnnotationComposer get roleId {
    final $$RolesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableAnnotationComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RolePermissionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RolePermissionsTable,
          RolePermission,
          $$RolePermissionsTableFilterComposer,
          $$RolePermissionsTableOrderingComposer,
          $$RolePermissionsTableAnnotationComposer,
          $$RolePermissionsTableCreateCompanionBuilder,
          $$RolePermissionsTableUpdateCompanionBuilder,
          (RolePermission, $$RolePermissionsTableReferences),
          RolePermission,
          PrefetchHooks Function({bool roleId})
        > {
  $$RolePermissionsTableTableManager(
    _$AppDatabase db,
    $RolePermissionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RolePermissionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RolePermissionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RolePermissionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> roleId = const Value.absent(),
                Value<String> permission = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RolePermissionsCompanion(
                roleId: roleId,
                permission: permission,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String roleId,
                required String permission,
                Value<int> rowid = const Value.absent(),
              }) => RolePermissionsCompanion.insert(
                roleId: roleId,
                permission: permission,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RolePermissionsTable, RolePermission>(table),
                  $$RolePermissionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({roleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (roleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.roleId,
                                referencedTable:
                                    $$RolePermissionsTableReferences
                                        ._roleIdTable(db),
                                referencedColumn:
                                    $$RolePermissionsTableReferences
                                        ._roleIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RolePermissionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RolePermissionsTable,
      RolePermission,
      $$RolePermissionsTableFilterComposer,
      $$RolePermissionsTableOrderingComposer,
      $$RolePermissionsTableAnnotationComposer,
      $$RolePermissionsTableCreateCompanionBuilder,
      $$RolePermissionsTableUpdateCompanionBuilder,
      (RolePermission, $$RolePermissionsTableReferences),
      RolePermission,
      PrefetchHooks Function({bool roleId})
    >;
typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> createdBy,
      Value<String?> deviceId,
      Value<DateTime?> deletedAt,
      required String username,
      required String displayName,
      Value<String?> memberId,
      required String roleId,
      required String passwordHash,
      Value<String?> pinHash,
      Value<bool> biometricEnabled,
      Value<bool> isActive,
      Value<int> failedAttempts,
      Value<DateTime?> lockedUntil,
      Value<DateTime?> lastLoginAt,
      Value<int> rowid,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> createdBy,
      Value<String?> deviceId,
      Value<DateTime?> deletedAt,
      Value<String> username,
      Value<String> displayName,
      Value<String?> memberId,
      Value<String> roleId,
      Value<String> passwordHash,
      Value<String?> pinHash,
      Value<bool> biometricEnabled,
      Value<bool> isActive,
      Value<int> failedAttempts,
      Value<DateTime?> lockedUntil,
      Value<DateTime?> lastLoginAt,
      Value<int> rowid,
    });

final class $$UsersTableReferences
    extends BaseReferences<_$AppDatabase, $UsersTable, User> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MembersTable _memberIdTable(_$AppDatabase db) =>
      db.members.createAlias('users__member_id__members__id');

  $$MembersTableProcessedTableManager? get memberId {
    final $_column = $_itemColumn<String>('member_id');
    if ($_column == null) return null;
    final manager = $$MembersTableTableManager(
      $_db,
      $_db.members,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memberIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RolesTable _roleIdTable(_$AppDatabase db) =>
      db.roles.createAlias('users__role_id__roles__id');

  $$RolesTableProcessedTableManager get roleId {
    final $_column = $_itemColumn<String>('role_id')!;

    final manager = $$RolesTableTableManager(
      $_db,
      $_db.roles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_roleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get biometricEnabled => $composableBuilder(
    column: $table.biometricEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lockedUntil => $composableBuilder(
    column: $table.lockedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastLoginAt => $composableBuilder(
    column: $table.lastLoginAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MembersTableFilterComposer get memberId {
    final $$MembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memberId,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableFilterComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RolesTableFilterComposer get roleId {
    final $$RolesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableFilterComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get biometricEnabled => $composableBuilder(
    column: $table.biometricEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lockedUntil => $composableBuilder(
    column: $table.lockedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastLoginAt => $composableBuilder(
    column: $table.lastLoginAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MembersTableOrderingComposer get memberId {
    final $$MembersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memberId,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableOrderingComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RolesTableOrderingComposer get roleId {
    final $$RolesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableOrderingComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => column);

  GeneratedColumn<bool> get biometricEnabled => $composableBuilder(
    column: $table.biometricEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lockedUntil => $composableBuilder(
    column: $table.lockedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastLoginAt => $composableBuilder(
    column: $table.lastLoginAt,
    builder: (column) => column,
  );

  $$MembersTableAnnotationComposer get memberId {
    final $$MembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memberId,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableAnnotationComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RolesTableAnnotationComposer get roleId {
    final $$RolesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableAnnotationComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          User,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (User, $$UsersTableReferences),
          User,
          PrefetchHooks Function({bool memberId, bool roleId})
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<String> roleId = const Value.absent(),
                Value<String> passwordHash = const Value.absent(),
                Value<String?> pinHash = const Value.absent(),
                Value<bool> biometricEnabled = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> failedAttempts = const Value.absent(),
                Value<DateTime?> lockedUntil = const Value.absent(),
                Value<DateTime?> lastLoginAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                deviceId: deviceId,
                deletedAt: deletedAt,
                username: username,
                displayName: displayName,
                memberId: memberId,
                roleId: roleId,
                passwordHash: passwordHash,
                pinHash: pinHash,
                biometricEnabled: biometricEnabled,
                isActive: isActive,
                failedAttempts: failedAttempts,
                lockedUntil: lockedUntil,
                lastLoginAt: lastLoginAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required String username,
                required String displayName,
                Value<String?> memberId = const Value.absent(),
                required String roleId,
                required String passwordHash,
                Value<String?> pinHash = const Value.absent(),
                Value<bool> biometricEnabled = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> failedAttempts = const Value.absent(),
                Value<DateTime?> lockedUntil = const Value.absent(),
                Value<DateTime?> lastLoginAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                deviceId: deviceId,
                deletedAt: deletedAt,
                username: username,
                displayName: displayName,
                memberId: memberId,
                roleId: roleId,
                passwordHash: passwordHash,
                pinHash: pinHash,
                biometricEnabled: biometricEnabled,
                isActive: isActive,
                failedAttempts: failedAttempts,
                lockedUntil: lockedUntil,
                lastLoginAt: lastLoginAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UsersTable, User>(table),
                  $$UsersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memberId = false, roleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (memberId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memberId,
                                referencedTable: $$UsersTableReferences
                                    ._memberIdTable(db),
                                referencedColumn: $$UsersTableReferences
                                    ._memberIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (roleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.roleId,
                                referencedTable: $$UsersTableReferences
                                    ._roleIdTable(db),
                                referencedColumn: $$UsersTableReferences
                                    ._roleIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      User,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (User, $$UsersTableReferences),
      User,
      PrefetchHooks Function({bool memberId, bool roleId})
    >;
typedef $$AuditLogsTableCreateCompanionBuilder =
    AuditLogsCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String?> username,
      required String action,
      Value<String?> entity,
      Value<String?> entityId,
      Value<String?> oldValue,
      Value<String?> newValue,
      Value<DateTime> at,
      Value<String?> deviceId,
      Value<int> rowid,
    });
typedef $$AuditLogsTableUpdateCompanionBuilder =
    AuditLogsCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String?> username,
      Value<String> action,
      Value<String?> entity,
      Value<String?> entityId,
      Value<String?> oldValue,
      Value<String?> newValue,
      Value<DateTime> at,
      Value<String?> deviceId,
      Value<int> rowid,
    });

class $$AuditLogsTableFilterComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AuditLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuditLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get oldValue =>
      $composableBuilder(column: $table.oldValue, builder: (column) => column);

  GeneratedColumn<String> get newValue =>
      $composableBuilder(column: $table.newValue, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$AuditLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AuditLogsTable,
          AuditLog,
          $$AuditLogsTableFilterComposer,
          $$AuditLogsTableOrderingComposer,
          $$AuditLogsTableAnnotationComposer,
          $$AuditLogsTableCreateCompanionBuilder,
          $$AuditLogsTableUpdateCompanionBuilder,
          (AuditLog, BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog>),
          AuditLog,
          PrefetchHooks Function()
        > {
  $$AuditLogsTableTableManager(_$AppDatabase db, $AuditLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String?> entity = const Value.absent(),
                Value<String?> entityId = const Value.absent(),
                Value<String?> oldValue = const Value.absent(),
                Value<String?> newValue = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditLogsCompanion(
                id: id,
                userId: userId,
                username: username,
                action: action,
                entity: entity,
                entityId: entityId,
                oldValue: oldValue,
                newValue: newValue,
                at: at,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> username = const Value.absent(),
                required String action,
                Value<String?> entity = const Value.absent(),
                Value<String?> entityId = const Value.absent(),
                Value<String?> oldValue = const Value.absent(),
                Value<String?> newValue = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditLogsCompanion.insert(
                id: id,
                userId: userId,
                username: username,
                action: action,
                entity: entity,
                entityId: entityId,
                oldValue: oldValue,
                newValue: newValue,
                at: at,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AuditLogsTable, AuditLog>(table),
                  BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuditLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AuditLogsTable,
      AuditLog,
      $$AuditLogsTableFilterComposer,
      $$AuditLogsTableOrderingComposer,
      $$AuditLogsTableAnnotationComposer,
      $$AuditLogsTableCreateCompanionBuilder,
      $$AuditLogsTableUpdateCompanionBuilder,
      (AuditLog, BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog>),
      AuditLog,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OrgSettingsTableTableManager get orgSettings =>
      $$OrgSettingsTableTableManager(_db, _db.orgSettings);
  $$ZonesTableTableManager get zones =>
      $$ZonesTableTableManager(_db, _db.zones);
  $$MembersTableTableManager get members =>
      $$MembersTableTableManager(_db, _db.members);
  $$MemberZonesTableTableManager get memberZones =>
      $$MemberZonesTableTableManager(_db, _db.memberZones);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db, _db.roles);
  $$RolePermissionsTableTableManager get rolePermissions =>
      $$RolePermissionsTableTableManager(_db, _db.rolePermissions);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db, _db.auditLogs);
}
