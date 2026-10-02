import 'package:dlu_tkb/db.dart';
import 'package:drift/native.dart';

/// Mỗi test một SQLite trong RAM: khỏi dọn tệp, khỏi dính dữ liệu test trước.
void dungDbTam() => Db.dungTam(Db(NativeDatabase.memory()));
