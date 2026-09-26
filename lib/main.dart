import 'package:flutter/material.dart';

import 'data.dart';
import 'login.dart';
import 'paper.dart';
import 'portal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // SharedPreferences needs it
  final store = await Store.open();
  runApp(App(store: store));
}

class App extends StatelessWidget {
  const App({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TKB',
        debugShowCheckedModeBanner: false,
        theme: Paper.theme(),
        home: Root(store: store),
      );
}

/// Decides between the login screen and the app: with saved credentials we log
/// in again on every cold start, since the portal token only lives ~2h.
class Root extends StatefulWidget {
  const Root({super.key, required this.store});
  final Store store;

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  Session? _session;
  String? _error;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _resume();
  }

  Future<void> _resume() async {
    final saved = await Vault.read();
    if (saved != null) {
      try {
        _session = await Portal().login(saved.$1, saved.$2);
      } on PortalError catch (e) {
        _error = e.message;
      }
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(
                color: Paper.accent, strokeWidth: 3)),
      );
    }
    if (_session == null) {
      return LoginScreen(
        initialError: _error,
        onLoggedIn: (s) => setState(() {
          _session = s;
          _error = null;
        }),
      );
    }
    return Home(
      store: widget.store,
      session: _session!,
      onLogout: () async {
        await Vault.clear();
        if (mounted) setState(() => _session = null);
      },
    );
  }
}

const slotColors = [Paper.sun, Paper.rose, Paper.sky, Paper.peach, Paper.mint];

class Home extends StatefulWidget {
  const Home({
    super.key,
    required this.store,
    required this.session,
    required this.onLogout,
  });

  final Store store;
  final Session session;
  final VoidCallback onLogout;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Store get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      body: DotBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _Header(
                      now: now,
                      name: widget.session.fullName,
                      onLogout: widget.onLogout),
                  const SizedBox(height: 16),
                  _NextUp(store: store, now: now),
                  const SizedBox(height: 20),
                  _SectionTitle('Thời khoá biểu', onAdd: () => _editSlot()),
                  const SizedBox(height: 10),
                  _Week(store: store, now: now, onTap: _editSlot),
                  const SizedBox(height: 24),
                  _SectionTitle('Việc cần làm', onAdd: () => _editTask()),
                  const SizedBox(height: 10),
                  _Tasks(store: store, now: now, onTap: _editTask),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editSlot([Slot? slot]) async {
    final result = await showDialog<Slot?>(
      context: context,
      builder: (_) => SlotDialog(slot: slot),
    );
    if (result == null) return;
    if (slot == null) {
      store.slots.add(result);
    } else if (result.subject.isEmpty) {
      store.slots.remove(slot);
    }
    store.save();
  }

  Future<void> _editTask([Task? task]) async {
    final result = await showDialog<Task?>(
      context: context,
      builder: (_) => TaskDialog(task: task),
    );
    if (result == null) return;
    if (task == null) {
      store.tasks.add(result);
    } else if (result.title.isEmpty) {
      store.tasks.remove(task);
    }
    store.save();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now, required this.name, required this.onLogout});
  final DateTime now;
  final String name;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thời khoá biểu',
                    style: TextStyle(
                        fontFamily: 'Baloo',
                        fontWeight: FontWeight.w800,
                        fontSize: 34,
                        height: 1.1,
                        color: Paper.ink)),
                const SizedBox(height: 4),
                Text(
                    '$name · ${dayNames[now.weekday]}, '
                    '${now.day}/${now.month}/${now.year}',
                    style: const TextStyle(color: Paper.ink2, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: PaperButton(
                label: 'Thoát',
                color: Paper.card,
                onColor: Paper.ink,
                onPressed: onLogout),
          ),
        ],
      );
}

class _NextUp extends StatelessWidget {
  const _NextUp({required this.store, required this.now});
  final Store store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final next = store.nextClass(now);
    if (next == null) {
      return const PaperBox(
        child: Text('Chưa có buổi học nào. Bấm + để thêm.',
            style: TextStyle(color: Paper.ink2)),
      );
    }
    final (slot, at) = next;
    final left = at.difference(now);
    final inDays = left.inDays;
    final countdown = inDays > 0
        ? 'còn $inDays ngày'
        : left.inHours > 0
            ? 'còn ${left.inHours}h ${left.inMinutes % 60}p'
            : 'còn ${left.inMinutes}p';
    return PaperBox(
      color: slotColors[slot.colorIndex % slotColors.length],
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Pill('Buổi học tới', color: Paper.card),
            const Spacer(),
            Text(countdown,
                style: const TextStyle(
                    fontFamily: 'Baloo',
                    fontWeight: FontWeight.w800,
                    color: Paper.ink)),
          ]),
          const SizedBox(height: 10),
          Text(slot.subject,
              style: const TextStyle(
                  fontFamily: 'Baloo',
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  height: 1.2)),
          const SizedBox(height: 2),
          Text(
            '${dayNames[slot.day]} · ${hhmm(slot.start)}–${hhmm(slot.end)}'
            '${slot.room.isEmpty ? '' : ' · ${slot.room}'}'
            '${slot.teacher.isEmpty ? '' : ' · ${slot.teacher}'}',
            style: Paper.mono.copyWith(fontSize: 13, color: Paper.ink2),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.onAdd});
  final String text;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(text,
              style: const TextStyle(
                  fontFamily: 'Baloo', fontWeight: FontWeight.w800, fontSize: 22)),
          const SizedBox(width: 12),
          PaperButton(label: '+ Thêm', onPressed: onAdd),
        ],
      );
}

class _Week extends StatelessWidget {
  const _Week({required this.store, required this.now, required this.onTap});
  final Store store;
  final DateTime now;
  final void Function(Slot) onTap;

  @override
  Widget build(BuildContext context) {
    // 7 columns need real room; below this the days stack vertically.
    final wide = MediaQuery.sizeOf(context).width >= 900;
    // On a phone an empty day is just noise; on a desktop it keeps the grid square.
    final days = [
      for (var d = 1; d <= 7; d++)
        if (wide || store.onDay(d).isNotEmpty || d == now.weekday) d,
    ];
    final columns = [
      for (final d in days) _DayColumn(d: d, store: store, now: now, onTap: onTap),
    ];
    if (!wide) {
      return Column(
        children: [
          for (final c in columns)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in columns)
          Expanded(
            child: Padding(padding: const EdgeInsets.only(right: 10), child: c),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.d, required this.store, required this.now, required this.onTap});
  final int d;
  final Store store;
  final DateTime now;
  final void Function(Slot) onTap;

  @override
  Widget build(BuildContext context) {
    final today = d == now.weekday;
    final slots = store.onDay(d).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Pill(dayNames[d], color: today ? Paper.accent : Paper.card)
              .withInk(today ? Paper.card : Paper.ink),
        ),
        const SizedBox(height: 8),
        if (slots.isEmpty)
          Container(
            height: 54,
            decoration: BoxDecoration(
              border: Border.all(color: Paper.ink3, width: 2, strokeAlign: BorderSide.strokeAlignInside),
              borderRadius: const BorderRadius.all(Paper.radius),
            ),
            child: const Center(
              child: Text('—', style: TextStyle(color: Paper.ink3)),
            ),
          ),
        for (final s in slots)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PaperBox(
              onTap: () => onTap(s),
              color: slotColors[s.colorIndex % slotColors.length],
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hhmm(s.start),
                      style: Paper.mono.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Paper.ink2)),
                  Text(s.subject,
                      style: const TextStyle(
                          fontFamily: 'Baloo',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.25)),
                  if (s.room.isNotEmpty)
                    Text(s.room,
                        style: const TextStyle(fontSize: 12, color: Paper.ink2)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Tasks extends StatelessWidget {
  const _Tasks({required this.store, required this.now, required this.onTap});
  final Store store;
  final DateTime now;
  final void Function(Task) onTap;

  @override
  Widget build(BuildContext context) {
    if (store.tasks.isEmpty) {
      return const PaperBox(
        child: Text('Trống. Tận hưởng đi.', style: TextStyle(color: Paper.ink2)),
      );
    }
    return Column(
      children: [
        for (final t in store.tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PaperBox(
              onTap: () => onTap(t),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      t.done = !t.done;
                      store.save();
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: t.done ? Paper.mint : Paper.card,
                        border: Paper.border,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: t.done
                          ? const Icon(Icons.check, size: 16, color: Paper.ink)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title,
                            style: TextStyle(
                                fontFamily: 'Baloo',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: t.done ? Paper.ink3 : Paper.ink,
                                decoration:
                                    t.done ? TextDecoration.lineThrough : null)),
                        if (t.subject.isNotEmpty)
                          Text(t.subject,
                              style: const TextStyle(
                                  fontSize: 12, color: Paper.ink2)),
                      ],
                    ),
                  ),
                  _DueChip(due: t.due, now: now, done: t.done),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.due, required this.now, required this.done});
  final DateTime due;
  final DateTime now;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final days = DateTime(due.year, due.month, due.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final label = switch (days) {
      < 0 => 'trễ ${-days}n',
      0 => 'hôm nay',
      1 => 'mai',
      _ => 'còn ${days}n',
    };
    final color = done
        ? Paper.card
        : days < 0
            ? Paper.accent
            : days <= 1
                ? Paper.sun
                : Paper.sky;
    return Pill(label, color: color).withInk(
        !done && days < 0 ? Paper.card : Paper.ink);
  }
}

// ---------- dialogs ----------

class SlotDialog extends StatefulWidget {
  const SlotDialog({super.key, this.slot});
  final Slot? slot;

  @override
  State<SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<SlotDialog> {
  late final _subject = TextEditingController(text: widget.slot?.subject ?? '');
  late final _room = TextEditingController(text: widget.slot?.room ?? '');
  late final _teacher = TextEditingController(text: widget.slot?.teacher ?? '');
  late int _start = widget.slot?.start ?? 7 * 60;
  late int _end = widget.slot?.end ?? 9 * 60;
  late int _day = widget.slot?.day ?? DateTime.now().weekday;
  late int _color = widget.slot?.colorIndex ?? 0;
  String? _error;

  @override
  Widget build(BuildContext context) => _Dialog(
        title: widget.slot == null ? 'Thêm buổi học' : 'Sửa buổi học',
        existing: widget.slot != null,
        error: _error,
        onDelete: () {
          final s = widget.slot!..subject = '';
          Navigator.pop(context, s);
        },
        onSave: () {
          if (_subject.text.trim().isEmpty) {
            return setState(() => _error = 'Thiếu tên môn');
          }
          if (_end <= _start) {
            return setState(() => _error = 'Giờ kết thúc phải sau giờ bắt đầu');
          }
          final s = widget.slot ?? Slot(subject: '', day: _day, start: _start, end: _end);
          s
            ..subject = _subject.text.trim()
            ..day = _day
            ..start = _start
            ..end = _end
            ..room = _room.text.trim()
            ..teacher = _teacher.text.trim()
            ..colorIndex = _color;
          Navigator.pop(context, s);
        },
        children: [
          _Field(label: 'Môn', controller: _subject),
          _Field(label: 'Phòng', controller: _room),
          _Field(label: 'Giảng viên', controller: _teacher),
          Row(children: [
            Expanded(
                child: _TimeField(
                    label: 'Bắt đầu',
                    minutes: _start,
                    onPick: (m) => setState(() => _start = m))),
            const SizedBox(width: 12),
            Expanded(
                child: _TimeField(
                    label: 'Kết thúc',
                    minutes: _end,
                    onPick: (m) => setState(() => _end = m))),
          ]),
          const SizedBox(height: 12),
          const Text('Thứ', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var d = 1; d <= 7; d++)
                GestureDetector(
                  onTap: () => setState(() => _day = d),
                  child: Pill(dayNames[d], color: _day == d ? Paper.accent : Paper.card)
                      .withInk(_day == d ? Paper.card : Paper.ink),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Màu', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < slotColors.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _color = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: slotColors[i],
                      border: Border.all(color: Paper.ink, width: _color == i ? 3 : 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
}

class TaskDialog extends StatefulWidget {
  const TaskDialog({super.key, this.task});
  final Task? task;

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late final _subject = TextEditingController(text: widget.task?.subject ?? '');
  late DateTime _due = widget.task?.due ?? DateTime.now().add(const Duration(days: 1));
  String? _error;

  @override
  Widget build(BuildContext context) => _Dialog(
        title: widget.task == null ? 'Thêm việc' : 'Sửa việc',
        existing: widget.task != null,
        error: _error,
        onDelete: () => Navigator.pop(context, widget.task!..title = ''),
        onSave: () {
          if (_title.text.trim().isEmpty) {
            return setState(() => _error = 'Thiếu tên việc');
          }
          final t = widget.task ?? Task(title: '', due: _due);
          t
            ..title = _title.text.trim()
            ..subject = _subject.text.trim()
            ..due = _due;
          Navigator.pop(context, t);
        },
        children: [
          _Field(label: 'Việc', controller: _title),
          _Field(label: 'Môn', controller: _subject),
          const SizedBox(height: 4),
          Row(children: [
            const Text('Hạn: ', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('${_due.day}/${_due.month}/${_due.year}',
                style: Paper.mono),
            const Spacer(),
            PaperButton(
              label: 'Chọn ngày',
              color: Paper.sun,
              onColor: Paper.ink,
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _due,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _due = picked);
              },
            ),
          ]),
        ],
      );
}

class _Dialog extends StatelessWidget {
  const _Dialog({
    required this.title,
    required this.children,
    required this.onSave,
    required this.onDelete,
    required this.existing,
    this.error,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final bool existing;
  final String? error;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: PaperBox(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Baloo',
                          fontWeight: FontWeight.w800,
                          fontSize: 22)),
                  const SizedBox(height: 12),
                  ...children,
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!,
                        style: const TextStyle(
                            color: Paper.accent, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 18),
                  Row(children: [
                    if (existing)
                      PaperButton(
                          label: 'Xoá',
                          color: Paper.rose,
                          onColor: Paper.ink,
                          onPressed: onDelete),
                    const Spacer(),
                    PaperButton(
                        label: 'Thoát',
                        color: Paper.card,
                        onColor: Paper.ink,
                        onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 8),
                    PaperButton(label: 'Lưu', onPressed: onSave),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Tapping opens the platform time picker — no HH:MM typing on a phone.
class _TimeField extends StatelessWidget {
  const _TimeField(
      {required this.label, required this.minutes, required this.onPick});
  final String label;
  final int minutes;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          PaperBox(
            color: Paper.paper,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
              );
              if (picked != null) onPick(picked.hour * 60 + picked.minute);
            },
            child: Text(hhmm(minutes),
                style: Paper.mono.copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Paper.paper,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Paper.ink, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Paper.ink, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Paper.accent, width: 2),
                ),
              ),
            ),
          ],
        ),
      );
}
