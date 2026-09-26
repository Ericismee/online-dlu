import 'package:flutter/material.dart';

import 'paper.dart';
import 'portal.dart';

/// Môn đạt thì xanh, chưa đạt thì hồng.
Color markColor(dynamic m) => m['IsPass'] == 'x' ? Paper.mint : Paper.rose;

/// Bảng điểm theo năm học / học kỳ.
class MarksScreen extends StatefulWidget {
  const MarksScreen({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends State<MarksScreen> {
  List<dynamic>? _years;
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
      final years = await portal.marks(widget.session.token, program);
      if (mounted) setState(() => _years = years);
    } on PortalError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                      'Điểm',
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
              const SizedBox(height: 16),
              if (_error != null)
                PaperBox(
                  color: Paper.rose,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Paper.ink),
                  ),
                )
              else if (_years == null)
                for (var i = 0; i < 3; i++)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Skeleton(height: 140, radius: 16, ink: true),
                  )
              else
                for (final y in _years!.reversed)
                  for (final t in (y['DanhSachDiem'] as List).reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _Term(year: y['NamHoc'] as String? ?? '', term: t),
                    ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Term extends StatelessWidget {
  const _Term({required this.year, required this.term});
  final String year;
  final dynamic term;

  @override
  Widget build(BuildContext context) {
    final subjects = (term['DanhSachDiemHK'] as List?) ?? const [];
    final first = subjects.isEmpty ? null : subjects.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$year · ${term['HocKy']}',
                style: const TextStyle(
                  fontFamily: 'Baloo',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Paper.ink,
                ),
              ),
            ),
            if (first != null)
              Pill('TB ${first['TB_HK_10']} · ${first['TB_HK_4']}'),
          ],
        ),
        const SizedBox(height: 8),
        PaperBox(child: Column(children: [for (final m in subjects) _Mark(m)])),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark(this.m);
  final dynamic m;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m['CurriculumName'] as String? ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Paper.ink,
                ),
              ),
              Text(
                '${m['Credits']} TC',
                style: const TextStyle(fontSize: 12, color: Paper.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Pill('${m['DiemTK_10']} · ${m['DiemTK_Chu']}', color: markColor(m)),
      ],
    ),
  );
}
