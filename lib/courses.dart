import 'package:flutter/material.dart';

import 'graph.dart';
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

class _CoursesTabState extends State<CoursesTab> {
  late (String, String) _pick = yearTermFor(DateTime.now());
  List<dynamic>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pick = _pick;
    setState(() {
      _list = null;
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
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _list ?? const <dynamic>[];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 20,
            20,
            120,
          ),
          children: [
            const Text(
              'Học phần',
              style: TextStyle(
                fontFamily: 'Baloo',
                fontWeight: FontWeight.w800,
                fontSize: 30,
                color: Paper.ink,
              ),
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
                if (list.isNotEmpty)
                  Text(
                    '${list.first['TongLHP']} LHP · ${list.first['TongSTC']} TC',
                    style: const TextStyle(color: Paper.ink3, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null)
              PaperBox(
                color: Paper.rose,
                child: Text(_error!, style: const TextStyle(color: Paper.ink)),
              )
            else if (_list == null)
              for (var i = 0; i < 4; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Skeleton(height: 96, radius: 16, ink: true),
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
            c['CurriculumName'] as String? ?? '',
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
              Pill(
                c['ScheduleStudyUnitAlias'] as String? ?? '',
                color: Paper.sky,
              ),
              Pill('${c['Credits']} TC'),
              Pill(
                c['TinhTrang'] as String? ?? '',
                color: c['IsAccepted'] == 1 ? Paper.mint : Paper.peach,
              ),
            ],
          ),
          if (gv.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'GV: $gv',
              style: const TextStyle(color: Paper.ink2, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
