import 'package:dlu_tkb/cache.dart';
import 'package:dlu_tkb/db.dart';
import 'package:drift/native.dart';

/// Mỗi test một SQLite trong RAM: khỏi dọn tệp, khỏi dính dữ liệu test trước.
/// Kèm luôn [Cache.open] vì bản cache trong RAM là static — không dọn thì test
/// sau đọc được dữ liệu portal của test trước dù DB đã mới.
Future<void> dungDbTam() async {
  Db.dungTam(Db(NativeDatabase.memory()));
  await Cache.open();
}
