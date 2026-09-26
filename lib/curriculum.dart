import 'package:flutter/material.dart';

import 'paper.dart';
import 'portal.dart';

/// Gộp học phần theo học kỳ, giữ nguyên thứ tự portal trả về.
List<(String, List<dynamic>)> byTerm(List<dynamic> rows) {
  final out = <(String, List<dynamic>)>[];
  for (final r in rows) {
    final term = r['HocKy'] as String? ?? '';
    if (out.isEmpty || out.last.$1 != term) out.add((term, <dynamic>[]));
    out.last.$2.add(r);
  }
  return out;
}

/// Tổng số tín chỉ của một danh sách học phần.
int credits(List<dynamic> rows) =>
    rows.fold(0, (s, r) => s + ((r['STC'] as num?)?.toInt() ?? 0));

/// Chương trình đào tạo, nhóm theo học kỳ.
class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  List<dynamic>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final portal = widget.portal ?? Portal();
    try {
      final program = await portal.studyProgram(widget.session.token);
      final rows = await portal.curriculum(widget.session.token, program);
      if (mounted) setState(() => _rows = rows);
    } on PortalError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows ?? const <dynamic>[];
    return Scaffold(
      body: DotBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 20,
                20,
                40,
              ),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Chương trình đào tạo',
                        style: TextStyle(
                          fontFamily: 'Baloo',
                          fontWeight: FontWeight.w800,
                          fontSize: 30,
                          color: Paper.ink,
                        ),
                      ),
                    ),
                    PaperButton(
                      label: 'Quay lại',
                      color: Paper.card,
                      onColor: Paper.ink,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (_rows != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Pill('${rows.length} HP', color: Paper.sky),
                      const SizedBox(width: 6),
                      Pill('${credits(rows)} TC', color: Paper.sun),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (_error != null)
                  PaperBox(
                    color: Paper.rose,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Paper.ink),
                    ),
                  )
                else if (_rows == null)
                  for (var i = 0; i < 3; i++)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Skeleton(height: 140, radius: 16, ink: true),
                    )
                else
                  for (final (term, subjects) in byTerm(rows))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _Term(term: term, subjects: subjects),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Term extends StatelessWidget {
  const _Term({required this.term, required this.subjects});
  final String term;
  final List<dynamic> subjects;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              term,
              style: const TextStyle(
                fontFamily: 'Baloo',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Paper.ink,
              ),
            ),
          ),
          Pill('${credits(subjects)} TC'),
        ],
      ),
      const SizedBox(height: 8),
      PaperBox(
        child: Column(children: [for (final s in subjects) _Subject(s)]),
      ),
    ],
  );
}

class _Subject extends StatelessWidget {
  const _Subject(this.s);
  final dynamic s;

  @override
  Widget build(BuildContext context) {
    final required = s['BatBuoc'] == 'Bắt Buộc';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s['TenHP'] as String? ?? '',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Paper.ink,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill('${s['MaHP']}', color: Paper.sky),
              Pill('${s['STC']} TC', color: Paper.sun),
              Pill(
                required ? 'Bắt buộc' : 'Tự chọn',
                color: required ? Paper.mint : Paper.peach,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
