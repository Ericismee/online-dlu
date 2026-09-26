import 'package:flutter/material.dart';

import 'paper.dart';
import 'portal.dart';

/// Hồ sơ sinh viên, đọc từ `/api/student/info`.
class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

/// Label + key, in the order they show up on the card. Empty values are hidden.
const _fields = [
  ('Mã sinh viên', 'MaSinhVien'),
  ('Họ tên', 'HoTen'),
  ('Lớp', 'LopSinhVien'),
  ('Khoá học', 'KhoaHoc'),
  ('Niên khoá', 'NienKhoa'),
  ('Tình trạng', 'TinhTrangHoc'),
  ('Giới tính', 'GioiTinh'),
  ('Ngày sinh', 'NgaySinh'),
  ('CMND/CCCD', 'CMND'),
  ('Dân tộc', 'DanToc'),
  ('Tôn giáo', 'TonGiao'),
  ('Di động', 'DiDong'),
  ('Email trường', 'EmailTruong'),
  ('Email cá nhân', 'EmailCaNhan'),
  ('Quốc gia', 'QuocGia'),
  ('Tỉnh/Thành', 'TinhThanh'),
  ('Quận/Huyện', 'QuanHuyen'),
  ('Địa chỉ', 'DiaChi'),
  ('Cố vấn học tập', 'CoVanHocTap'),
];

class _InfoScreenState extends State<InfoScreen> {
  Map<String, dynamic>? _info;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info =
          await (widget.portal ?? Portal()).studentInfo(widget.session.token);
      if (mounted) setState(() => _info = info);
    } on PortalError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DotBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Hồ sơ sinh viên',
                              style: TextStyle(
                                  fontFamily: 'Baloo',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 30,
                                  color: Paper.ink)),
                        ),
                        PaperButton(
                            label: 'Quay lại',
                            color: Paper.card,
                            onColor: Paper.ink,
                            onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      PaperBox(
                          color: Paper.rose,
                          child: Text(_error!,
                              style: const TextStyle(color: Paper.ink)))
                    else if (_info == null)
                      const PaperBox(
                          child: Text('Đang tải…',
                              style: TextStyle(color: Paper.ink2)))
                    else
                      PaperBox(
                        child: Column(
                          children: [
                            for (final (label, key) in _fields)
                              if ((_info![key]?.toString() ?? '').isNotEmpty)
                                _Row(label, _info![key].toString()),
                          ],
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(color: Paper.ink3, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Paper.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
