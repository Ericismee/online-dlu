// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $KhoTable extends Kho with TableInfo<$KhoTable, KhoData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KhoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nhomMeta = const VerificationMeta('nhom');
  @override
  late final GeneratedColumn<String> nhom = GeneratedColumn<String>(
    'nhom',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _khoaMeta = const VerificationMeta('khoa');
  @override
  late final GeneratedColumn<String> khoa = GeneratedColumn<String>(
    'khoa',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _giaTriMeta = const VerificationMeta('giaTri');
  @override
  late final GeneratedColumn<String> giaTri = GeneratedColumn<String>(
    'gia_tri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _batMeta = const VerificationMeta('bat');
  @override
  late final GeneratedColumn<bool> bat = GeneratedColumn<bool>(
    'bat',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("bat" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lucMeta = const VerificationMeta('luc');
  @override
  late final GeneratedColumn<DateTime> luc = GeneratedColumn<DateTime>(
    'luc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [nhom, khoa, giaTri, bat, luc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kho';
  @override
  VerificationContext validateIntegrity(
    Insertable<KhoData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('nhom')) {
      context.handle(
        _nhomMeta,
        nhom.isAcceptableOrUnknown(data['nhom']!, _nhomMeta),
      );
    } else if (isInserting) {
      context.missing(_nhomMeta);
    }
    if (data.containsKey('khoa')) {
      context.handle(
        _khoaMeta,
        khoa.isAcceptableOrUnknown(data['khoa']!, _khoaMeta),
      );
    } else if (isInserting) {
      context.missing(_khoaMeta);
    }
    if (data.containsKey('gia_tri')) {
      context.handle(
        _giaTriMeta,
        giaTri.isAcceptableOrUnknown(data['gia_tri']!, _giaTriMeta),
      );
    }
    if (data.containsKey('bat')) {
      context.handle(
        _batMeta,
        bat.isAcceptableOrUnknown(data['bat']!, _batMeta),
      );
    }
    if (data.containsKey('luc')) {
      context.handle(
        _lucMeta,
        luc.isAcceptableOrUnknown(data['luc']!, _lucMeta),
      );
    } else if (isInserting) {
      context.missing(_lucMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {nhom, khoa};
  @override
  KhoData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KhoData(
      nhom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nhom'],
      )!,
      khoa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}khoa'],
      )!,
      giaTri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gia_tri'],
      )!,
      bat: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}bat'],
      )!,
      luc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}luc'],
      )!,
    );
  }

  @override
  $KhoTable createAlias(String alias) {
    return $KhoTable(attachedDatabase, alias);
  }
}

class KhoData extends DataClass implements Insertable<KhoData> {
  /// Gom nhóm để xoá/đếm theo cụm: 'cache', 'cai_dat', 'moc'.
  final String nhom;
  final String khoa;

  /// JSON, hoặc chuỗi rỗng khi [bat] chính là giá trị (cờ bật/tắt).
  final String giaTri;
  final bool bat;
  final DateTime luc;
  const KhoData({
    required this.nhom,
    required this.khoa,
    required this.giaTri,
    required this.bat,
    required this.luc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['nhom'] = Variable<String>(nhom);
    map['khoa'] = Variable<String>(khoa);
    map['gia_tri'] = Variable<String>(giaTri);
    map['bat'] = Variable<bool>(bat);
    map['luc'] = Variable<DateTime>(luc);
    return map;
  }

  KhoCompanion toCompanion(bool nullToAbsent) {
    return KhoCompanion(
      nhom: Value(nhom),
      khoa: Value(khoa),
      giaTri: Value(giaTri),
      bat: Value(bat),
      luc: Value(luc),
    );
  }

  factory KhoData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KhoData(
      nhom: serializer.fromJson<String>(json['nhom']),
      khoa: serializer.fromJson<String>(json['khoa']),
      giaTri: serializer.fromJson<String>(json['giaTri']),
      bat: serializer.fromJson<bool>(json['bat']),
      luc: serializer.fromJson<DateTime>(json['luc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'nhom': serializer.toJson<String>(nhom),
      'khoa': serializer.toJson<String>(khoa),
      'giaTri': serializer.toJson<String>(giaTri),
      'bat': serializer.toJson<bool>(bat),
      'luc': serializer.toJson<DateTime>(luc),
    };
  }

  KhoData copyWith({
    String? nhom,
    String? khoa,
    String? giaTri,
    bool? bat,
    DateTime? luc,
  }) => KhoData(
    nhom: nhom ?? this.nhom,
    khoa: khoa ?? this.khoa,
    giaTri: giaTri ?? this.giaTri,
    bat: bat ?? this.bat,
    luc: luc ?? this.luc,
  );
  KhoData copyWithCompanion(KhoCompanion data) {
    return KhoData(
      nhom: data.nhom.present ? data.nhom.value : this.nhom,
      khoa: data.khoa.present ? data.khoa.value : this.khoa,
      giaTri: data.giaTri.present ? data.giaTri.value : this.giaTri,
      bat: data.bat.present ? data.bat.value : this.bat,
      luc: data.luc.present ? data.luc.value : this.luc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KhoData(')
          ..write('nhom: $nhom, ')
          ..write('khoa: $khoa, ')
          ..write('giaTri: $giaTri, ')
          ..write('bat: $bat, ')
          ..write('luc: $luc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(nhom, khoa, giaTri, bat, luc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KhoData &&
          other.nhom == this.nhom &&
          other.khoa == this.khoa &&
          other.giaTri == this.giaTri &&
          other.bat == this.bat &&
          other.luc == this.luc);
}

class KhoCompanion extends UpdateCompanion<KhoData> {
  final Value<String> nhom;
  final Value<String> khoa;
  final Value<String> giaTri;
  final Value<bool> bat;
  final Value<DateTime> luc;
  final Value<int> rowid;
  const KhoCompanion({
    this.nhom = const Value.absent(),
    this.khoa = const Value.absent(),
    this.giaTri = const Value.absent(),
    this.bat = const Value.absent(),
    this.luc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KhoCompanion.insert({
    required String nhom,
    required String khoa,
    this.giaTri = const Value.absent(),
    this.bat = const Value.absent(),
    required DateTime luc,
    this.rowid = const Value.absent(),
  }) : nhom = Value(nhom),
       khoa = Value(khoa),
       luc = Value(luc);
  static Insertable<KhoData> custom({
    Expression<String>? nhom,
    Expression<String>? khoa,
    Expression<String>? giaTri,
    Expression<bool>? bat,
    Expression<DateTime>? luc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (nhom != null) 'nhom': nhom,
      if (khoa != null) 'khoa': khoa,
      if (giaTri != null) 'gia_tri': giaTri,
      if (bat != null) 'bat': bat,
      if (luc != null) 'luc': luc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KhoCompanion copyWith({
    Value<String>? nhom,
    Value<String>? khoa,
    Value<String>? giaTri,
    Value<bool>? bat,
    Value<DateTime>? luc,
    Value<int>? rowid,
  }) {
    return KhoCompanion(
      nhom: nhom ?? this.nhom,
      khoa: khoa ?? this.khoa,
      giaTri: giaTri ?? this.giaTri,
      bat: bat ?? this.bat,
      luc: luc ?? this.luc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (nhom.present) {
      map['nhom'] = Variable<String>(nhom.value);
    }
    if (khoa.present) {
      map['khoa'] = Variable<String>(khoa.value);
    }
    if (giaTri.present) {
      map['gia_tri'] = Variable<String>(giaTri.value);
    }
    if (bat.present) {
      map['bat'] = Variable<bool>(bat.value);
    }
    if (luc.present) {
      map['luc'] = Variable<DateTime>(luc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KhoCompanion(')
          ..write('nhom: $nhom, ')
          ..write('khoa: $khoa, ')
          ..write('giaTri: $giaTri, ')
          ..write('bat: $bat, ')
          ..write('luc: $luc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LichRiengsTable extends LichRiengs
    with TableInfo<$LichRiengsTable, LichRieng> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LichRiengsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ngayMeta = const VerificationMeta('ngay');
  @override
  late final GeneratedColumn<String> ngay = GeneratedColumn<String>(
    'ngay',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tieuDeMeta = const VerificationMeta('tieuDe');
  @override
  late final GeneratedColumn<String> tieuDe = GeneratedColumn<String>(
    'tieu_de',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batDauMeta = const VerificationMeta('batDau');
  @override
  late final GeneratedColumn<int> batDau = GeneratedColumn<int>(
    'bat_dau',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ketThucMeta = const VerificationMeta(
    'ketThuc',
  );
  @override
  late final GeneratedColumn<int> ketThuc = GeneratedColumn<int>(
    'ket_thuc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mauMeta = const VerificationMeta('mau');
  @override
  late final GeneratedColumn<int> mau = GeneratedColumn<int>(
    'mau',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(customLichMauMacDinh),
  );
  static const VerificationMeta _viTriMeta = const VerificationMeta('viTri');
  @override
  late final GeneratedColumn<String> viTri = GeneratedColumn<String>(
    'vi_tri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lapMeta = const VerificationMeta('lap');
  @override
  late final GeneratedColumn<String> lap = GeneratedColumn<String>(
    'lap',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _denNgayMeta = const VerificationMeta(
    'denNgay',
  );
  @override
  late final GeneratedColumn<String> denNgay = GeneratedColumn<String>(
    'den_ngay',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gocMeta = const VerificationMeta('goc');
  @override
  late final GeneratedColumn<int> goc = GeneratedColumn<int>(
    'goc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _batMeta = const VerificationMeta('bat');
  @override
  late final GeneratedColumn<bool> bat = GeneratedColumn<bool>(
    'bat',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("bat" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lucMeta = const VerificationMeta('luc');
  @override
  late final GeneratedColumn<DateTime> luc = GeneratedColumn<DateTime>(
    'luc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ngay,
    tieuDe,
    batDau,
    ketThuc,
    mau,
    viTri,
    lap,
    denNgay,
    goc,
    bat,
    luc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lich_riengs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LichRieng> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ngay')) {
      context.handle(
        _ngayMeta,
        ngay.isAcceptableOrUnknown(data['ngay']!, _ngayMeta),
      );
    } else if (isInserting) {
      context.missing(_ngayMeta);
    }
    if (data.containsKey('tieu_de')) {
      context.handle(
        _tieuDeMeta,
        tieuDe.isAcceptableOrUnknown(data['tieu_de']!, _tieuDeMeta),
      );
    } else if (isInserting) {
      context.missing(_tieuDeMeta);
    }
    if (data.containsKey('bat_dau')) {
      context.handle(
        _batDauMeta,
        batDau.isAcceptableOrUnknown(data['bat_dau']!, _batDauMeta),
      );
    } else if (isInserting) {
      context.missing(_batDauMeta);
    }
    if (data.containsKey('ket_thuc')) {
      context.handle(
        _ketThucMeta,
        ketThuc.isAcceptableOrUnknown(data['ket_thuc']!, _ketThucMeta),
      );
    }
    if (data.containsKey('mau')) {
      context.handle(
        _mauMeta,
        mau.isAcceptableOrUnknown(data['mau']!, _mauMeta),
      );
    }
    if (data.containsKey('vi_tri')) {
      context.handle(
        _viTriMeta,
        viTri.isAcceptableOrUnknown(data['vi_tri']!, _viTriMeta),
      );
    }
    if (data.containsKey('lap')) {
      context.handle(
        _lapMeta,
        lap.isAcceptableOrUnknown(data['lap']!, _lapMeta),
      );
    }
    if (data.containsKey('den_ngay')) {
      context.handle(
        _denNgayMeta,
        denNgay.isAcceptableOrUnknown(data['den_ngay']!, _denNgayMeta),
      );
    }
    if (data.containsKey('goc')) {
      context.handle(
        _gocMeta,
        goc.isAcceptableOrUnknown(data['goc']!, _gocMeta),
      );
    }
    if (data.containsKey('bat')) {
      context.handle(
        _batMeta,
        bat.isAcceptableOrUnknown(data['bat']!, _batMeta),
      );
    }
    if (data.containsKey('luc')) {
      context.handle(
        _lucMeta,
        luc.isAcceptableOrUnknown(data['luc']!, _lucMeta),
      );
    } else if (isInserting) {
      context.missing(_lucMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LichRieng map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LichRieng(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ngay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ngay'],
      )!,
      tieuDe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tieu_de'],
      )!,
      batDau: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bat_dau'],
      )!,
      ketThuc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ket_thuc'],
      ),
      mau: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mau'],
      )!,
      viTri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vi_tri'],
      ),
      lap: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lap'],
      ),
      denNgay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}den_ngay'],
      ),
      goc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}goc'],
      ),
      bat: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}bat'],
      )!,
      luc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}luc'],
      )!,
    );
  }

  @override
  $LichRiengsTable createAlias(String alias) {
    return $LichRiengsTable(attachedDatabase, alias);
  }
}

class LichRieng extends DataClass implements Insertable<LichRieng> {
  final int id;
  final String ngay;
  final String tieuDe;
  final int batDau;
  final int? ketThuc;
  final int mau;
  final String? viTri;

  /// Các thứ trong tuần mục này lặp lại, dạng '2,4' theo [DateTime.weekday].
  /// Null là mục chỉ xảy ra đúng ngày [ngay].
  final String? lap;

  /// Lặp tới hết ngày này (yyyy-mm-dd). Null là lặp không hạn.
  final String? denNgay;

  /// Dòng ngoại lệ của một mục lặp: [goc] là id mục lặp, [ngay] là buổi bị
  /// đụng tới. `bat = false` nghĩa là buổi đó bỏ, còn bật thì là buổi đó sửa
  /// riêng. Mục lặp vẫn nằm nguyên, đúng luật không xoá gì.
  final int? goc;
  final bool bat;
  final DateTime luc;
  const LichRieng({
    required this.id,
    required this.ngay,
    required this.tieuDe,
    required this.batDau,
    this.ketThuc,
    required this.mau,
    this.viTri,
    this.lap,
    this.denNgay,
    this.goc,
    required this.bat,
    required this.luc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ngay'] = Variable<String>(ngay);
    map['tieu_de'] = Variable<String>(tieuDe);
    map['bat_dau'] = Variable<int>(batDau);
    if (!nullToAbsent || ketThuc != null) {
      map['ket_thuc'] = Variable<int>(ketThuc);
    }
    map['mau'] = Variable<int>(mau);
    if (!nullToAbsent || viTri != null) {
      map['vi_tri'] = Variable<String>(viTri);
    }
    if (!nullToAbsent || lap != null) {
      map['lap'] = Variable<String>(lap);
    }
    if (!nullToAbsent || denNgay != null) {
      map['den_ngay'] = Variable<String>(denNgay);
    }
    if (!nullToAbsent || goc != null) {
      map['goc'] = Variable<int>(goc);
    }
    map['bat'] = Variable<bool>(bat);
    map['luc'] = Variable<DateTime>(luc);
    return map;
  }

  LichRiengsCompanion toCompanion(bool nullToAbsent) {
    return LichRiengsCompanion(
      id: Value(id),
      ngay: Value(ngay),
      tieuDe: Value(tieuDe),
      batDau: Value(batDau),
      ketThuc: ketThuc == null && nullToAbsent
          ? const Value.absent()
          : Value(ketThuc),
      mau: Value(mau),
      viTri: viTri == null && nullToAbsent
          ? const Value.absent()
          : Value(viTri),
      lap: lap == null && nullToAbsent ? const Value.absent() : Value(lap),
      denNgay: denNgay == null && nullToAbsent
          ? const Value.absent()
          : Value(denNgay),
      goc: goc == null && nullToAbsent ? const Value.absent() : Value(goc),
      bat: Value(bat),
      luc: Value(luc),
    );
  }

  factory LichRieng.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LichRieng(
      id: serializer.fromJson<int>(json['id']),
      ngay: serializer.fromJson<String>(json['ngay']),
      tieuDe: serializer.fromJson<String>(json['tieuDe']),
      batDau: serializer.fromJson<int>(json['batDau']),
      ketThuc: serializer.fromJson<int?>(json['ketThuc']),
      mau: serializer.fromJson<int>(json['mau']),
      viTri: serializer.fromJson<String?>(json['viTri']),
      lap: serializer.fromJson<String?>(json['lap']),
      denNgay: serializer.fromJson<String?>(json['denNgay']),
      goc: serializer.fromJson<int?>(json['goc']),
      bat: serializer.fromJson<bool>(json['bat']),
      luc: serializer.fromJson<DateTime>(json['luc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ngay': serializer.toJson<String>(ngay),
      'tieuDe': serializer.toJson<String>(tieuDe),
      'batDau': serializer.toJson<int>(batDau),
      'ketThuc': serializer.toJson<int?>(ketThuc),
      'mau': serializer.toJson<int>(mau),
      'viTri': serializer.toJson<String?>(viTri),
      'lap': serializer.toJson<String?>(lap),
      'denNgay': serializer.toJson<String?>(denNgay),
      'goc': serializer.toJson<int?>(goc),
      'bat': serializer.toJson<bool>(bat),
      'luc': serializer.toJson<DateTime>(luc),
    };
  }

  LichRieng copyWith({
    int? id,
    String? ngay,
    String? tieuDe,
    int? batDau,
    Value<int?> ketThuc = const Value.absent(),
    int? mau,
    Value<String?> viTri = const Value.absent(),
    Value<String?> lap = const Value.absent(),
    Value<String?> denNgay = const Value.absent(),
    Value<int?> goc = const Value.absent(),
    bool? bat,
    DateTime? luc,
  }) => LichRieng(
    id: id ?? this.id,
    ngay: ngay ?? this.ngay,
    tieuDe: tieuDe ?? this.tieuDe,
    batDau: batDau ?? this.batDau,
    ketThuc: ketThuc.present ? ketThuc.value : this.ketThuc,
    mau: mau ?? this.mau,
    viTri: viTri.present ? viTri.value : this.viTri,
    lap: lap.present ? lap.value : this.lap,
    denNgay: denNgay.present ? denNgay.value : this.denNgay,
    goc: goc.present ? goc.value : this.goc,
    bat: bat ?? this.bat,
    luc: luc ?? this.luc,
  );
  LichRieng copyWithCompanion(LichRiengsCompanion data) {
    return LichRieng(
      id: data.id.present ? data.id.value : this.id,
      ngay: data.ngay.present ? data.ngay.value : this.ngay,
      tieuDe: data.tieuDe.present ? data.tieuDe.value : this.tieuDe,
      batDau: data.batDau.present ? data.batDau.value : this.batDau,
      ketThuc: data.ketThuc.present ? data.ketThuc.value : this.ketThuc,
      mau: data.mau.present ? data.mau.value : this.mau,
      viTri: data.viTri.present ? data.viTri.value : this.viTri,
      lap: data.lap.present ? data.lap.value : this.lap,
      denNgay: data.denNgay.present ? data.denNgay.value : this.denNgay,
      goc: data.goc.present ? data.goc.value : this.goc,
      bat: data.bat.present ? data.bat.value : this.bat,
      luc: data.luc.present ? data.luc.value : this.luc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LichRieng(')
          ..write('id: $id, ')
          ..write('ngay: $ngay, ')
          ..write('tieuDe: $tieuDe, ')
          ..write('batDau: $batDau, ')
          ..write('ketThuc: $ketThuc, ')
          ..write('mau: $mau, ')
          ..write('viTri: $viTri, ')
          ..write('lap: $lap, ')
          ..write('denNgay: $denNgay, ')
          ..write('goc: $goc, ')
          ..write('bat: $bat, ')
          ..write('luc: $luc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ngay,
    tieuDe,
    batDau,
    ketThuc,
    mau,
    viTri,
    lap,
    denNgay,
    goc,
    bat,
    luc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LichRieng &&
          other.id == this.id &&
          other.ngay == this.ngay &&
          other.tieuDe == this.tieuDe &&
          other.batDau == this.batDau &&
          other.ketThuc == this.ketThuc &&
          other.mau == this.mau &&
          other.viTri == this.viTri &&
          other.lap == this.lap &&
          other.denNgay == this.denNgay &&
          other.goc == this.goc &&
          other.bat == this.bat &&
          other.luc == this.luc);
}

class LichRiengsCompanion extends UpdateCompanion<LichRieng> {
  final Value<int> id;
  final Value<String> ngay;
  final Value<String> tieuDe;
  final Value<int> batDau;
  final Value<int?> ketThuc;
  final Value<int> mau;
  final Value<String?> viTri;
  final Value<String?> lap;
  final Value<String?> denNgay;
  final Value<int?> goc;
  final Value<bool> bat;
  final Value<DateTime> luc;
  const LichRiengsCompanion({
    this.id = const Value.absent(),
    this.ngay = const Value.absent(),
    this.tieuDe = const Value.absent(),
    this.batDau = const Value.absent(),
    this.ketThuc = const Value.absent(),
    this.mau = const Value.absent(),
    this.viTri = const Value.absent(),
    this.lap = const Value.absent(),
    this.denNgay = const Value.absent(),
    this.goc = const Value.absent(),
    this.bat = const Value.absent(),
    this.luc = const Value.absent(),
  });
  LichRiengsCompanion.insert({
    this.id = const Value.absent(),
    required String ngay,
    required String tieuDe,
    required int batDau,
    this.ketThuc = const Value.absent(),
    this.mau = const Value.absent(),
    this.viTri = const Value.absent(),
    this.lap = const Value.absent(),
    this.denNgay = const Value.absent(),
    this.goc = const Value.absent(),
    this.bat = const Value.absent(),
    required DateTime luc,
  }) : ngay = Value(ngay),
       tieuDe = Value(tieuDe),
       batDau = Value(batDau),
       luc = Value(luc);
  static Insertable<LichRieng> custom({
    Expression<int>? id,
    Expression<String>? ngay,
    Expression<String>? tieuDe,
    Expression<int>? batDau,
    Expression<int>? ketThuc,
    Expression<int>? mau,
    Expression<String>? viTri,
    Expression<String>? lap,
    Expression<String>? denNgay,
    Expression<int>? goc,
    Expression<bool>? bat,
    Expression<DateTime>? luc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ngay != null) 'ngay': ngay,
      if (tieuDe != null) 'tieu_de': tieuDe,
      if (batDau != null) 'bat_dau': batDau,
      if (ketThuc != null) 'ket_thuc': ketThuc,
      if (mau != null) 'mau': mau,
      if (viTri != null) 'vi_tri': viTri,
      if (lap != null) 'lap': lap,
      if (denNgay != null) 'den_ngay': denNgay,
      if (goc != null) 'goc': goc,
      if (bat != null) 'bat': bat,
      if (luc != null) 'luc': luc,
    });
  }

  LichRiengsCompanion copyWith({
    Value<int>? id,
    Value<String>? ngay,
    Value<String>? tieuDe,
    Value<int>? batDau,
    Value<int?>? ketThuc,
    Value<int>? mau,
    Value<String?>? viTri,
    Value<String?>? lap,
    Value<String?>? denNgay,
    Value<int?>? goc,
    Value<bool>? bat,
    Value<DateTime>? luc,
  }) {
    return LichRiengsCompanion(
      id: id ?? this.id,
      ngay: ngay ?? this.ngay,
      tieuDe: tieuDe ?? this.tieuDe,
      batDau: batDau ?? this.batDau,
      ketThuc: ketThuc ?? this.ketThuc,
      mau: mau ?? this.mau,
      viTri: viTri ?? this.viTri,
      lap: lap ?? this.lap,
      denNgay: denNgay ?? this.denNgay,
      goc: goc ?? this.goc,
      bat: bat ?? this.bat,
      luc: luc ?? this.luc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ngay.present) {
      map['ngay'] = Variable<String>(ngay.value);
    }
    if (tieuDe.present) {
      map['tieu_de'] = Variable<String>(tieuDe.value);
    }
    if (batDau.present) {
      map['bat_dau'] = Variable<int>(batDau.value);
    }
    if (ketThuc.present) {
      map['ket_thuc'] = Variable<int>(ketThuc.value);
    }
    if (mau.present) {
      map['mau'] = Variable<int>(mau.value);
    }
    if (viTri.present) {
      map['vi_tri'] = Variable<String>(viTri.value);
    }
    if (lap.present) {
      map['lap'] = Variable<String>(lap.value);
    }
    if (denNgay.present) {
      map['den_ngay'] = Variable<String>(denNgay.value);
    }
    if (goc.present) {
      map['goc'] = Variable<int>(goc.value);
    }
    if (bat.present) {
      map['bat'] = Variable<bool>(bat.value);
    }
    if (luc.present) {
      map['luc'] = Variable<DateTime>(luc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LichRiengsCompanion(')
          ..write('id: $id, ')
          ..write('ngay: $ngay, ')
          ..write('tieuDe: $tieuDe, ')
          ..write('batDau: $batDau, ')
          ..write('ketThuc: $ketThuc, ')
          ..write('mau: $mau, ')
          ..write('viTri: $viTri, ')
          ..write('lap: $lap, ')
          ..write('denNgay: $denNgay, ')
          ..write('goc: $goc, ')
          ..write('bat: $bat, ')
          ..write('luc: $luc')
          ..write(')'))
        .toString();
  }
}

abstract class _$Db extends GeneratedDatabase {
  _$Db(QueryExecutor e) : super(e);
  $DbManager get managers => $DbManager(this);
  late final $KhoTable kho = $KhoTable(this);
  late final $LichRiengsTable lichRiengs = $LichRiengsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [kho, lichRiengs];
}

typedef $$KhoTableCreateCompanionBuilder = KhoCompanion Function({
  required String nhom,
  required String khoa,
  Value<String> giaTri,
  Value<bool> bat,
  required DateTime luc,
  Value<int> rowid,
});
typedef $$KhoTableUpdateCompanionBuilder = KhoCompanion Function({
  Value<String> nhom,
  Value<String> khoa,
  Value<String> giaTri,
  Value<bool> bat,
  Value<DateTime> luc,
  Value<int> rowid,
});

class $$KhoTableFilterComposer extends Composer<_$Db, $KhoTable> {
  $$KhoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get nhom => $composableBuilder(
    column: $table.nhom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get khoa => $composableBuilder(
    column: $table.khoa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get giaTri => $composableBuilder(
    column: $table.giaTri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get bat => $composableBuilder(
    column: $table.bat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get luc => $composableBuilder(
    column: $table.luc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KhoTableOrderingComposer extends Composer<_$Db, $KhoTable> {
  $$KhoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get nhom => $composableBuilder(
    column: $table.nhom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get khoa => $composableBuilder(
    column: $table.khoa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get giaTri => $composableBuilder(
    column: $table.giaTri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get bat => $composableBuilder(
    column: $table.bat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get luc => $composableBuilder(
    column: $table.luc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KhoTableAnnotationComposer extends Composer<_$Db, $KhoTable> {
  $$KhoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get nhom =>
      $composableBuilder(column: $table.nhom, builder: (column) => column);

  GeneratedColumn<String> get khoa =>
      $composableBuilder(column: $table.khoa, builder: (column) => column);

  GeneratedColumn<String> get giaTri =>
      $composableBuilder(column: $table.giaTri, builder: (column) => column);

  GeneratedColumn<bool> get bat =>
      $composableBuilder(column: $table.bat, builder: (column) => column);

  GeneratedColumn<DateTime> get luc =>
      $composableBuilder(column: $table.luc, builder: (column) => column);
}

class $$KhoTableTableManager
    extends
        RootTableManager<
          _$Db,
          $KhoTable,
          KhoData,
          $$KhoTableFilterComposer,
          $$KhoTableOrderingComposer,
          $$KhoTableAnnotationComposer,
          $$KhoTableCreateCompanionBuilder,
          $$KhoTableUpdateCompanionBuilder,
          (KhoData, BaseReferences<_$Db, $KhoTable, KhoData>),
          KhoData,
          PrefetchHooks Function()
        > {
  $$KhoTableTableManager(_$Db db, $KhoTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KhoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KhoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KhoTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> nhom = const Value.absent(),
                Value<String> khoa = const Value.absent(),
                Value<String> giaTri = const Value.absent(),
                Value<bool> bat = const Value.absent(),
                Value<DateTime> luc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KhoCompanion(
                nhom: nhom,
                khoa: khoa,
                giaTri: giaTri,
                bat: bat,
                luc: luc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String nhom,
                required String khoa,
                Value<String> giaTri = const Value.absent(),
                Value<bool> bat = const Value.absent(),
                required DateTime luc,
                Value<int> rowid = const Value.absent(),
              }) => KhoCompanion.insert(
                nhom: nhom,
                khoa: khoa,
                giaTri: giaTri,
                bat: bat,
                luc: luc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KhoTable, KhoData>(table),
                  BaseReferences<_$Db, $KhoTable, KhoData>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KhoTableProcessedTableManager =
    ProcessedTableManager<
      _$Db,
      $KhoTable,
      KhoData,
      $$KhoTableFilterComposer,
      $$KhoTableOrderingComposer,
      $$KhoTableAnnotationComposer,
      $$KhoTableCreateCompanionBuilder,
      $$KhoTableUpdateCompanionBuilder,
      (KhoData, BaseReferences<_$Db, $KhoTable, KhoData>),
      KhoData,
      PrefetchHooks Function()
    >;
typedef $$LichRiengsTableCreateCompanionBuilder = LichRiengsCompanion Function({
  Value<int> id,
  required String ngay,
  required String tieuDe,
  required int batDau,
  Value<int?> ketThuc,
  Value<int> mau,
  Value<String?> viTri,
  Value<String?> lap,
  Value<String?> denNgay,
  Value<int?> goc,
  Value<bool> bat,
  required DateTime luc,
});
typedef $$LichRiengsTableUpdateCompanionBuilder = LichRiengsCompanion Function({
  Value<int> id,
  Value<String> ngay,
  Value<String> tieuDe,
  Value<int> batDau,
  Value<int?> ketThuc,
  Value<int> mau,
  Value<String?> viTri,
  Value<String?> lap,
  Value<String?> denNgay,
  Value<int?> goc,
  Value<bool> bat,
  Value<DateTime> luc,
});

class $$LichRiengsTableFilterComposer extends Composer<_$Db, $LichRiengsTable> {
  $$LichRiengsTableFilterComposer({
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

  ColumnFilters<String> get ngay => $composableBuilder(
    column: $table.ngay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tieuDe => $composableBuilder(
    column: $table.tieuDe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get batDau => $composableBuilder(
    column: $table.batDau,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ketThuc => $composableBuilder(
    column: $table.ketThuc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mau => $composableBuilder(
    column: $table.mau,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viTri => $composableBuilder(
    column: $table.viTri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lap => $composableBuilder(
    column: $table.lap,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get denNgay => $composableBuilder(
    column: $table.denNgay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goc => $composableBuilder(
    column: $table.goc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get bat => $composableBuilder(
    column: $table.bat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get luc => $composableBuilder(
    column: $table.luc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LichRiengsTableOrderingComposer
    extends Composer<_$Db, $LichRiengsTable> {
  $$LichRiengsTableOrderingComposer({
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

  ColumnOrderings<String> get ngay => $composableBuilder(
    column: $table.ngay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tieuDe => $composableBuilder(
    column: $table.tieuDe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get batDau => $composableBuilder(
    column: $table.batDau,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ketThuc => $composableBuilder(
    column: $table.ketThuc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mau => $composableBuilder(
    column: $table.mau,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viTri => $composableBuilder(
    column: $table.viTri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lap => $composableBuilder(
    column: $table.lap,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get denNgay => $composableBuilder(
    column: $table.denNgay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goc => $composableBuilder(
    column: $table.goc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get bat => $composableBuilder(
    column: $table.bat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get luc => $composableBuilder(
    column: $table.luc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LichRiengsTableAnnotationComposer
    extends Composer<_$Db, $LichRiengsTable> {
  $$LichRiengsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ngay =>
      $composableBuilder(column: $table.ngay, builder: (column) => column);

  GeneratedColumn<String> get tieuDe =>
      $composableBuilder(column: $table.tieuDe, builder: (column) => column);

  GeneratedColumn<int> get batDau =>
      $composableBuilder(column: $table.batDau, builder: (column) => column);

  GeneratedColumn<int> get ketThuc =>
      $composableBuilder(column: $table.ketThuc, builder: (column) => column);

  GeneratedColumn<int> get mau =>
      $composableBuilder(column: $table.mau, builder: (column) => column);

  GeneratedColumn<String> get viTri =>
      $composableBuilder(column: $table.viTri, builder: (column) => column);

  GeneratedColumn<String> get lap =>
      $composableBuilder(column: $table.lap, builder: (column) => column);

  GeneratedColumn<String> get denNgay =>
      $composableBuilder(column: $table.denNgay, builder: (column) => column);

  GeneratedColumn<int> get goc =>
      $composableBuilder(column: $table.goc, builder: (column) => column);

  GeneratedColumn<bool> get bat =>
      $composableBuilder(column: $table.bat, builder: (column) => column);

  GeneratedColumn<DateTime> get luc =>
      $composableBuilder(column: $table.luc, builder: (column) => column);
}

class $$LichRiengsTableTableManager
    extends
        RootTableManager<
          _$Db,
          $LichRiengsTable,
          LichRieng,
          $$LichRiengsTableFilterComposer,
          $$LichRiengsTableOrderingComposer,
          $$LichRiengsTableAnnotationComposer,
          $$LichRiengsTableCreateCompanionBuilder,
          $$LichRiengsTableUpdateCompanionBuilder,
          (LichRieng, BaseReferences<_$Db, $LichRiengsTable, LichRieng>),
          LichRieng,
          PrefetchHooks Function()
        > {
  $$LichRiengsTableTableManager(_$Db db, $LichRiengsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LichRiengsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LichRiengsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LichRiengsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> ngay = const Value.absent(),
                Value<String> tieuDe = const Value.absent(),
                Value<int> batDau = const Value.absent(),
                Value<int?> ketThuc = const Value.absent(),
                Value<int> mau = const Value.absent(),
                Value<String?> viTri = const Value.absent(),
                Value<String?> lap = const Value.absent(),
                Value<String?> denNgay = const Value.absent(),
                Value<int?> goc = const Value.absent(),
                Value<bool> bat = const Value.absent(),
                Value<DateTime> luc = const Value.absent(),
              }) => LichRiengsCompanion(
                id: id,
                ngay: ngay,
                tieuDe: tieuDe,
                batDau: batDau,
                ketThuc: ketThuc,
                mau: mau,
                viTri: viTri,
                lap: lap,
                denNgay: denNgay,
                goc: goc,
                bat: bat,
                luc: luc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String ngay,
                required String tieuDe,
                required int batDau,
                Value<int?> ketThuc = const Value.absent(),
                Value<int> mau = const Value.absent(),
                Value<String?> viTri = const Value.absent(),
                Value<String?> lap = const Value.absent(),
                Value<String?> denNgay = const Value.absent(),
                Value<int?> goc = const Value.absent(),
                Value<bool> bat = const Value.absent(),
                required DateTime luc,
              }) => LichRiengsCompanion.insert(
                id: id,
                ngay: ngay,
                tieuDe: tieuDe,
                batDau: batDau,
                ketThuc: ketThuc,
                mau: mau,
                viTri: viTri,
                lap: lap,
                denNgay: denNgay,
                goc: goc,
                bat: bat,
                luc: luc,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LichRiengsTable, LichRieng>(table),
                  BaseReferences<_$Db, $LichRiengsTable, LichRieng>(
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

typedef $$LichRiengsTableProcessedTableManager =
    ProcessedTableManager<
      _$Db,
      $LichRiengsTable,
      LichRieng,
      $$LichRiengsTableFilterComposer,
      $$LichRiengsTableOrderingComposer,
      $$LichRiengsTableAnnotationComposer,
      $$LichRiengsTableCreateCompanionBuilder,
      $$LichRiengsTableUpdateCompanionBuilder,
      (LichRieng, BaseReferences<_$Db, $LichRiengsTable, LichRieng>),
      LichRieng,
      PrefetchHooks Function()
    >;

class $DbManager {
  final _$Db _db;
  $DbManager(this._db);
  $$KhoTableTableManager get kho => $$KhoTableTableManager(_db, _db.kho);
  $$LichRiengsTableTableManager get lichRiengs =>
      $$LichRiengsTableTableManager(_db, _db.lichRiengs);
}
