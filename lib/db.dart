import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_lich.dart' show CustomLich, customLichMauMacDinh;

part 'db.g.dart';

/// Nhóm khoá trong [Kho]: cache JSON của portal, cờ cài đặt, mốc "đã xem",
/// thông báo LMS.
const nhomCache = 'cache';
const nhomCaiDat = 'cai_dat';
const nhomMoc = 'moc';
const nhomThongBao = 'thong_bao';

/// Mọi thứ app lưu lâu dài đều nằm trong một tệp SQLite, không có gì bị xoá
/// thật: mỗi dòng mang cờ [bat]. `bat = false` nghĩa là "ẩn đi" — người dùng
/// bấm xoá, hay tắt một cờ cài đặt — dòng vẫn còn đó, bật lại là có lại.
///
/// Hai bảng là đủ: [Kho] cho mọi thứ khoá–giá trị (cache của portal, cờ cài
/// đặt, mốc đã xem), [LichRiengs] cho lịch tự đặt vì xoá từng mục nên mỗi mục
/// phải là một dòng riêng mới ẩn lẻ được.
class Kho extends Table {
  /// Gom nhóm để xoá/đếm theo cụm: 'cache', 'cai_dat', 'moc'.
  TextColumn get nhom => text()();
  TextColumn get khoa => text()();

  /// JSON, hoặc chuỗi rỗng khi [bat] chính là giá trị (cờ bật/tắt).
  TextColumn get giaTri => text().withDefault(const Constant(''))();
  BoolColumn get bat => boolean().withDefault(const Constant(true))();
  DateTimeColumn get luc => dateTime()();

  @override
  Set<Column> get primaryKey => {nhom, khoa};
}

/// Một mục lịch tự đặt. [ngay] là khoá ngày yyyy-mm-dd như bản cũ.
class LichRiengs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ngay => text()();
  TextColumn get tieuDe => text()();
  IntColumn get batDau => integer()();
  IntColumn get ketThuc => integer().nullable()();
  IntColumn get mau =>
      integer().withDefault(const Constant(customLichMauMacDinh))();
  TextColumn get viTri => text().nullable()();
  BoolColumn get bat => boolean().withDefault(const Constant(true))();
  DateTimeColumn get luc => dateTime()();
}

@DriftDatabase(tables: [Kho, LichRiengs])
class Db extends _$Db {
  Db(super.e);

  @override
  int get schemaVersion => 1;

  /// Một kết nối dùng chung cả app. Test gọi [dungTam] để thay bằng bộ nhớ.
  static Db? _i;
  static Db get i => _i ??= Db(driftDatabase(name: 'dlu'));

  static void dungTam(Db db) => _i = db;

  /// Dòng còn hiệu lực của một khoá. Trả cả dòng đã ẩn thì dùng [dong].
  Future<KhoData?> dong(String nhom, String khoa) => (select(
    kho,
  )..where((t) => t.nhom.equals(nhom) & t.khoa.equals(khoa))).getSingleOrNull();

  /// Giá trị đang bật, đã ẩn thì coi như không có.
  Future<KhoData?> doc(String nhom, String khoa) async {
    final d = await dong(nhom, khoa);
    return d == null || !d.bat ? null : d;
  }

  /// Mọi dòng còn bật của một nhóm.
  Future<List<KhoData>> nhomDang(String nhom) =>
      (select(kho)..where((t) => t.nhom.equals(nhom) & t.bat)).get();

  Future<void> ghi(
    String nhom,
    String khoa, {
    String giaTri = '',
    bool bat = true,
  }) => into(kho).insertOnConflictUpdate(
    KhoCompanion.insert(
      nhom: nhom,
      khoa: khoa,
      giaTri: Value(giaTri),
      bat: Value(bat),
      luc: DateTime.now(),
    ),
  );

  /// Ẩn một khoá, hoặc cả nhóm khi [khoa] để trống. Không xoá dòng nào.
  Future<void> an(String nhom, [String? khoa]) =>
      (update(kho)..where(
            (t) => khoa == null
                ? t.nhom.equals(nhom)
                : t.nhom.equals(nhom) & t.khoa.equals(khoa),
          ))
          .write(const KhoCompanion(bat: Value(false)));

  /// Bản cũ lưu trong SharedPreferences. Chuyển sang SQLite một lần duy nhất
  /// để người đang dùng không mất lịch tự đặt lẫn cờ cài đặt; prefs cũ cứ để
  /// nguyên đó, không xoá gì. Cache portal thì bỏ — nó tự nạp lại.
  Future<void> nhapTuPrefs() async {
    if (await dong(nhomMoc, _khoaNhap) != null) return;
    final prefs = await SharedPreferences.getInstance();
    final luc = DateTime.now();

    for (final khoa in const [
      'dev_mode',
      'unlock_dangerous',
      'app_lock',
      'lms_enabled',
      'nhac_truoc_gio',
    ]) {
      final v = prefs.getBool(khoa);
      if (v != null) await ghi(nhomCaiDat, khoa, bat: v);
    }
    for (final khoa in const ['menu_order']) {
      final v = prefs.getString(khoa);
      if (v != null) await ghi(nhomCaiDat, khoa, giaTri: v);
    }
    for (final khoa in const [
      'dismissed_update',
      'shown_update',
      'dismissed_changelog',
    ]) {
      final v = prefs.getString(khoa);
      if (v != null) await ghi(nhomMoc, khoa, giaTri: v);
    }

    final lich = prefs.getString('custom_lich');
    if (lich != null) {
      for (final e in (jsonDecode(lich) as Map<String, dynamic>).entries) {
        for (final j in e.value as List) {
          final c = CustomLich.fromJson(j as Map<String, dynamic>);
          await into(lichRiengs).insert(
            LichRiengsCompanion.insert(
              ngay: e.key,
              tieuDe: c.tieuDe,
              batDau: c.batDau,
              ketThuc: Value(c.ketThuc),
              mau: Value(c.mau),
              viTri: Value(c.viTri),
              luc: luc,
            ),
          );
        }
      }
    }
    await ghi(nhomMoc, _khoaNhap, giaTri: luc.toIso8601String());
  }

  static const _khoaNhap = 'da_nhap_prefs';
}
