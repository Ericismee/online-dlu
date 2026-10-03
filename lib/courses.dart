import 'package:flutter/material.dart';

import 'graph.dart';
import 'data.dart';
import 'paper.dart';
import 'portal.dart';

/// 6 năm học gần nhất, mới nhất trước.
List<String> recentYears(DateTime now) {
  final start = now.month >= 8 ? now.year : now.year - 1;
  return [for (var y = start; y > start - 6; y--) '$y-${y + 1}'];
}

/// 'Kết quả đăng ký học phần' của một học kỳ.
class CoursesTab extends StatefulWidget {
  const CoursesTab({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> with Reloadable<CoursesTab> {
  @override
  Future<void> reload() => _load();

  late (String, String) _pick = yearTermFor(DateTime.now());
  List<dynamic>? _list;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool blank = false}) async {
    final pick = _pick;
    setState(() {
      if (blank) _list = null;
      _error = null;
    });
    try {
      final r = await (widget.portal ?? Portal()).registrations(
        widget.session.token,
        year: pick.$1,
        term: pick.$2,
      );
      if (mounted && pick == _pick) setState(() => _list = r);
    } on PortalError catch (e) {
      if (mounted && pick == _pick) setState(() => _error = e.message);
    }
  }

  void _set((String, String) p) {
    setState(() => _pick = p);
    _load(blank: true);
  }

  @override
  Widget build(BuildContext context) {
    final all = _list ?? const <dynamic>[];
    // Tìm cả theo tên môn, mã lớp học phần lẫn tên thầy.
    final list = [
      for (final c in all)
        if (khop(
          '${subjectName(c['CurriculumName'])} '
          '${clean(c['ScheduleStudyUnitAlias'])} '
          '${c['ProfessorName'] ?? ''}',
          _q,
        ))
          c,
    ];
    // Dùng được cả hai kiểu: một tab trong thanh đáy, hoặc một trang mở từ menu.
    final pop = Navigator.of(context).canPop();
    return Scaffold(
      body: DotBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: PullRefresh(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top + 20,
                  20,
                  MediaQuery.paddingOf(context).bottom + (pop ? 40 : 110),
                ),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Học phần',
                          style: TextStyle(
                            fontFamily: 'Baloo',
                            fontWeight: FontWeight.w800,
                            fontSize: 30,
                            color: Paper.ink,
                          ),
                        ),
                      ),
                      if (pop)
                        PaperButton(
                          label: 'Quay lại',
                          color: Paper.card,
                          onColor: Paper.ink,
                          onPressed: () => Navigator.pop(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Choice(
                        label: _pick.$1,
                        onTap: () async {
                          final y = await chooseOption(
                            context,
                            recentYears(DateTime.now()),
                            _pick.$1,
                          );
                          if (y != null) _set((y, _pick.$2));
                        },
                      ),
                      const SizedBox(width: 8),
                      Choice(
                        label: _pick.$2,
                        color: Paper.mint,
                        onTap: () async {
                          final t = await chooseOption(context, const [
                            'HK01',
                            'HK02',
                            'HK03',
                          ], _pick.$2);
                          if (t != null) _set((_pick.$1, t));
                        },
                      ),
                      const Spacer(),
                      if (all.isNotEmpty)
                        // Flexible: máy hẹp hoặc cỡ chữ to thì cắt bớt,
                        // không thì hàng tràn qua mép.
                        Flexible(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Pill(
                                '${all.first['TongLHP']} LHP',
                                color: Paper.card,
                              ),
                              Pill(
                                '${all.first['TongSTC']} TC',
                                color: Paper.sun,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (all.length > 5) ...[
                    const SizedBox(height: 12),
                    SearchBox(
                      hint: 'Tìm môn, mã lớp, tên thầy',
                      onChanged: (v) => setState(() => _q = v),
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
                  else if (_list == null)
                    for (var i = 0; i < 4; i++)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Skeleton(height: 96, radius: 16, ink: true),
                      )
                  else if (all.isNotEmpty && list.isEmpty)
                    PaperBox(
                      child: const Text(
                        'Không có học phần nào khớp.',
                        style: TextStyle(color: Paper.ink2),
                      ),
                    )
                  else if (list.isEmpty)
                    PaperBox(
                      child: Container(
                        color: Paper.sun,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: const Text(
                          'Chưa đăng ký',
                          style: TextStyle(
                            fontFamily: 'Baloo',
                            fontWeight: FontWeight.w800,
                            fontSize: 30,
                            color: Paper.ink,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final c in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _Course(c),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Course extends StatelessWidget {
  const _Course(this.c);
  final dynamic c;

  @override
  Widget build(BuildContext context) {
    final gv = (c['ProfessorName'] as String? ?? '').trim();
    return PaperBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subjectName(c['CurriculumName']),
            style: const TextStyle(
              fontFamily: 'Baloo',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Paper.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(clean(c['ScheduleStudyUnitAlias']), color: Paper.sky),
              Pill('${c['Credits']} TC'),
              Pill(
                c['TinhTrang'] as String? ?? '',
                color: c['IsAccepted'] == 1 ? Paper.mint : Paper.peach,
              ),
            ],
          ),
          if (gv.isNotEmpty) ...[
            const SizedBox(height: 6),
            // Hàng riêng chứ không nhét vào Wrap trên: tên thầy dài hơn mọi
            // huy hiệu khác, phải có Flexible mới cắt được.
            Row(
              children: [Flexible(child: Pill('GV · $gv', color: Paper.card))],
            ),
          ],
        ],
      ),
    );
  }
}
