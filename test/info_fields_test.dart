import 'package:dlu_tkb/info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email trường suy từ mssv, quốc gia về tiếng Việt', () {
    const info = {
      'MaSinhVien': '2312577',
      'EmailTruong': 'loi@portal',
      'QuocGia': 'Vietnam',
      'DiDong': '0900000000',
    };
    expect(field(info, 'EmailTruong'), '2312577@dlu.edu.vn');
    expect(field(info, 'QuocGia'), 'Việt Nam');
    expect(field(info, 'DiDong'), '0900000000');
  });
}
