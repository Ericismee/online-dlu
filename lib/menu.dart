import 'package:flutter/material.dart';

import 'behavior.dart';
import 'courses.dart';
import 'curriculum.dart';
import 'log_screen.dart';
import 'marks.dart';
import 'nhat_ky.dart';
import 'paper.dart';
import 'portal.dart';
import 'settings.dart';
import 'update_check.dart';

/// Một mục menu: tab, icon, nhãn, màu giấy. Tab âm = mở trang riêng thay vì
/// chuyển tab dưới.
typedef MucMenu = (int, IconData, String, Color);

/// Một danh mục: icon, tên, màu, các mục bên trong.
typedef DanhMuc = (IconData, String, Color, List<MucMenu>);

/// Thẻ menu trên Trang chủ: ba danh mục, bấm vào là mở màn danh mục đó.
///
/// Trước đây là một danh sách phẳng mười một dòng kéo thả được. Mười một dòng
/// cùng cỡ chữ cùng kiểu icon thì mắt không có chỗ nghỉ, mà thứ tự tự kéo cũng
/// chẳng cứu được: vẫn mười một dòng. Chia nhóm là thấy ba dòng, mỗi dòng nói
/// rõ bên trong có gì.
class MenuCard extends StatelessWidget {
  const MenuCard({super.key, required this.session, required this.onGo});
  final Session session;
  final ValueChanged<int> onGo;

  static final danhMuc = <DanhMuc>[
    (
      Icons.menu_book_rounded,
      'Học tập',
      Paper.sun,
      [
        (0, Icons.calendar_month_rounded, 'Thời khoá biểu', Paper.sun),
        (1, Icons.edit_note_rounded, 'Lịch thi', Paper.rose),
        (-1, Icons.menu_book_rounded, 'Học phần', Paper.mint),
        (-3, Icons.school_rounded, 'Chương trình đào tạo', Paper.sky),
      ],
    ),
    (
      Icons.grade_rounded,
      'Kết quả',
      Paper.accent,
      [
        (3, Icons.grade_rounded, 'Điểm', Paper.accent),
        (-6, Icons.trending_up_rounded, 'Cải thiện', Paper.rose),
        (-2, Icons.emoji_events_rounded, 'Điểm rèn luyện', Paper.peach),
        (-4, Icons.fact_check_rounded, 'Phiếu rèn luyện', Paper.mint),
      ],
    ),
    (
      Icons.person_rounded,
      'Tiện ích',
      Paper.sky,
      [
        (4, Icons.badge_rounded, 'Hồ sơ', Paper.sky),
        (-5, Icons.settings_rounded, 'Cài đặt', Paper.card),
        (-7, Icons.system_update_rounded, 'Cập nhật', Paper.sky),
        (-8, Icons.terminal_rounded, 'Log', Paper.mint),
      ],
    ),
  ];

  void _mo(BuildContext context, int tab) {
    if (tab >= 0) {
      onGo(tab);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => switch (tab) {
          -1 => CoursesTab(session: session),
          -2 => BehaviorScreen(session: session),
          -4 => BehaviorDetailScreen(session: session),
          -5 => SettingsScreen(session: session),
          -6 => ImprovementScreen(session: session),
          -7 => const ChangelogScreen(),
          -8 => const LogScreen(),
          _ => CurriculumScreen(session: session),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Menu',
        style: TextStyle(
          fontFamily: 'Display',
          fontWeight: FontWeight.w800,
          fontSize: 22,
          color: Paper.ink,
        ),
      ),
      const SizedBox(height: 10),
      for (final (i, d) in danhMuc.indexed) ...[
        if (i > 0) const SizedBox(height: 16),
        // Tên danh mục là một cái thẻ giấy màu, không phải dòng chữ trơn:
        // nhìn xuống là thấy ngay khối nào thuộc nhóm nào.
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: d.$3,
              border: Paper.border,
              borderRadius: BorderRadius.all(Paper.radius),
              boxShadow: Paper.shadow(3),
            ),
            child: Text(
              d.$2,
              style: TextStyle(
                fontFamily: 'Display',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Paper.ink,
              ),
            ),
          ),
        ),
        // Ô tự nó đã là mẩu giấy có viền với bóng riêng; bọc thêm một thẻ
        // nữa chỉ là thẻ lồng thẻ, nhìn nặng mà chẳng nói thêm gì.
        LayoutBuilder(
          builder: (_, c) {
            const khe = 10.0;
            // Hai ô một hàng: ô nằm ngang nên cần bề ngang cho nhãn, mà
            // hàng thấp hơn thì cả danh mục cũng gọn hơn lưới ba cột.
            final rong = (c.maxWidth - khe) / 2;
            return Wrap(
              spacing: khe,
              runSpacing: khe,
              children: [
                for (final (tab, icon, label, color) in d.$4)
                  if (tab != -8 || NhatKy.bat)
                    SizedBox(
                      width: rong,
                      child: _MenuO(
                        icon: icon,
                        label: label,
                        color: color,
                        onTap: () => _mo(context, tab),
                      ),
                    ),
              ],
            );
          },
        ),
      ],
    ],
  );
}

/// Một ô menu: cả ô là một mẩu giấy viền mực có bóng cứng, trong đó huy hiệu
/// icon màu nằm cạnh nhãn. Ô liền khối như vầy đọc ra một món bấm được, chứ
/// không phải mảng màu trơ với dòng chữ rơi ở dưới.
class _MenuO extends StatelessWidget {
  const _MenuO({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    shift: 3,
    builder: (down) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Paper.card,
        border: Paper.border,
        borderRadius: BorderRadius.all(Paper.radius),
        boxShadow: Paper.shadow(down ? 0 : 3),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Paper.ink, width: 2),
              borderRadius: BorderRadius.all(Paper.radius),
            ),
            child: Icon(icon, size: 21, color: Paper.ink),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Display',
                fontSize: 13,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: Paper.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
