import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A weekly recurring class slot. [day] is 1=Mon .. 7=Sun (DateTime weekday).
class Slot {
  Slot({
    required this.subject,
    required this.day,
    required this.start,
    required this.end,
    this.room = '',
    this.teacher = '',
    this.colorIndex = 0,
  });

  String subject;
  int day;
  int start; // minutes from midnight
  int end;
  String room;
  String teacher;
  int colorIndex;

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'day': day,
        'start': start,
        'end': end,
        'room': room,
        'teacher': teacher,
        'color': colorIndex,
      };

  static Slot fromJson(Map<String, dynamic> j) => Slot(
        subject: j['subject'] as String,
        day: j['day'] as int,
        start: j['start'] as int,
        end: j['end'] as int,
        room: j['room'] as String? ?? '',
        teacher: j['teacher'] as String? ?? '',
        colorIndex: j['color'] as int? ?? 0,
      );
}

class Task {
  Task({required this.title, required this.due, this.subject = '', this.done = false});

  String title;
  DateTime due;
  String subject;
  bool done;

  Map<String, dynamic> toJson() => {
        'title': title,
        'due': due.toIso8601String(),
        'subject': subject,
        'done': done,
      };

  static Task fromJson(Map<String, dynamic> j) => Task(
        title: j['title'] as String,
        due: DateTime.parse(j['due'] as String),
        subject: j['subject'] as String? ?? '',
        done: j['done'] as bool? ?? false,
      );
}

/// Everything lives in one SharedPreferences key as JSON. Small data, one file.
class Store extends ChangeNotifier {
  Store(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) _load(raw);
  }

  static const _key = 'tkb';
  final SharedPreferences _prefs;

  final List<Slot> slots = [];
  final List<Task> tasks = [];

  static Future<Store> open() async => Store(await SharedPreferences.getInstance());

  void _load(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    slots.addAll((j['slots'] as List).map((e) => Slot.fromJson(e as Map<String, dynamic>)));
    tasks.addAll((j['tasks'] as List).map((e) => Task.fromJson(e as Map<String, dynamic>)));
    _sort();
  }

  void _sort() {
    slots.sort((a, b) => a.day != b.day ? a.day - b.day : a.start - b.start);
    // Done tasks sink to the bottom, otherwise soonest first.
    tasks.sort((a, b) =>
        a.done != b.done ? (a.done ? 1 : -1) : a.due.compareTo(b.due));
  }

  void save() {
    _sort();
    _prefs.setString(
      _key,
      jsonEncode({
        'slots': slots.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
      }),
    );
    notifyListeners();
  }

  /// Next upcoming class from [now], searching the next 7 days.
  /// Returns null when there are no slots at all.
  (Slot, DateTime)? nextClass(DateTime now) {
    if (slots.isEmpty) return null;
    for (var d = 0; d < 8; d++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));
      for (final s in slots.where((s) => s.day == day.weekday)) {
        final at = day.add(Duration(minutes: s.start));
        if (at.isAfter(now)) return (s, at);
      }
    }
    return null;
  }

  Iterable<Slot> onDay(int weekday) => slots.where((s) => s.day == weekday);
  Iterable<Task> get todo => tasks.where((t) => !t.done);
}

String hhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

const dayNames = ['', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];
