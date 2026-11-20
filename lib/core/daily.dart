// Ежедневные правила и мини-задача дня.

enum RulePeriod {
  morning('morning', 'Утро', '🌅'),
  evening('evening', 'Вечер', '🌙');

  const RulePeriod(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static RulePeriod fromValue(String? v) =>
      v == 'evening' ? RulePeriod.evening : RulePeriod.morning;
}

/// Правило, которое выполняется каждый день (утром или вечером).
class DailyRule {
  const DailyRule({required this.id, required this.title, required this.period});

  final String id;
  final String title;
  final RulePeriod period;

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'period': period.value};

  static DailyRule? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    if (id is! String || title is! String || title.trim().isEmpty) return null;
    return DailyRule(id: id, title: title, period: RulePeriod.fromValue(raw['period'] as String?));
  }

  /// Правила дома по умолчанию.
  static const defaults = <DailyRule>[
    DailyRule(id: 'bed', title: 'Заправить кровать', period: RulePeriod.morning),
    DailyRule(
      id: 'dressed',
      title: 'Одеться «до обуви» — сразу после подъёма',
      period: RulePeriod.morning,
    ),
    DailyRule(
      id: 'dishes-morning',
      title: 'Посуда после завтрака — сразу в мойку или посудомойку',
      period: RulePeriod.morning,
    ),
    DailyRule(id: 'sink', title: 'Сияющая раковина на кухне', period: RulePeriod.evening),
    DailyRule(
      id: 'hotspot',
      title: '5 минут на «горячую точку» (место, где копятся вещи)',
      period: RulePeriod.evening,
    ),
    DailyRule(
      id: 'tomorrow',
      title: 'Подготовить одежду и сумки на завтра',
      period: RulePeriod.evening,
    ),
  ];
}

/// Мини-задача дня: одно маленькое дело на 2–5 минут.
class MiniTask {
  const MiniTask(this.id, this.emoji, this.title, this.minutes, {this.room, this.modifier});

  final String id;
  final String emoji;
  final String title;
  final int minutes;

  /// Показывать, только если в доме есть эта комната / этот модификатор.
  final String? room;
  final String? modifier;

  static const catalog = <MiniTask>[
    MiniTask('handles', '🚪', 'Протри дверные ручки и выключатели', 3),
    MiniTask('fridge-shelf', '🧊', 'Разбери одну полку в холодильнике', 5, room: 'Кухня'),
    MiniTask('microwave', '🍲', 'Протри микроволновку изнутри', 3, room: 'Кухня'),
    MiniTask('spices', '🧂', 'Наведи порядок в специях', 4, room: 'Кухня'),
    MiniTask('mirror', '🪞', 'Отполируй зеркало в ванной', 2, room: 'Ванная'),
    MiniTask('towels', '🧺', 'Поменяй полотенца на свежие', 3, room: 'Ванная'),
    MiniTask('expired', '💊', 'Выброси просроченную косметику или лекарства', 5, room: 'Ванная'),
    MiniTask('shoes', '👟', 'Расставь обувь в прихожей парами', 3, room: 'Прихожая'),
    MiniTask('keys', '🔑', 'Разбери полочку для ключей и мелочей', 3, room: 'Прихожая'),
    MiniTask('remote', '📺', 'Протри пульты и телефон', 2, room: 'Гостиная'),
    MiniTask('pillows', '🛋', 'Взбей подушки и сложи пледы', 2, room: 'Гостиная'),
    MiniTask('nightstand', '🛏', 'Разбери прикроватную тумбочку', 5, room: 'Спальня'),
    MiniTask(
      'toys-box',
      '🧸',
      'Найди 5 игрушек, которые давно никому не нужны',
      5,
      room: 'Детская',
    ),
    MiniTask('desk', '🖊', 'Освободи рабочий стол от лишнего', 4, room: 'Кабинет'),
    MiniTask('balcony', '🪴', 'Полей цветы и убери сухие листья', 4),
    MiniTask('bag', '👜', 'Вытряхни сумку или рюкзак', 3),
    MiniTask('27things', '🗑', 'Выброси 10 ненужных вещей', 5),
    MiniTask('fridge-door', '🧲', 'Протри дверцу холодильника и магниты', 2, room: 'Кухня'),
    MiniTask('trash-can', '🚮', 'Помой мусорное ведро', 5),
    MiniTask('litter', '🐱', 'Помой кошачьи миски и коврик под лотком', 4, modifier: 'cat'),
    MiniTask('dog-toys', '🐶', 'Постирай или протри собачьи игрушки и поводок', 4, modifier: 'dog'),
    MiniTask(
      'robot',
      '🤖',
      'Почисти щётки и контейнер робота-пылесоса',
      4,
      modifier: 'robot_vacuum',
    ),
    MiniTask('dishwasher-filter', '🍽', 'Промой фильтр посудомойки', 4, modifier: 'dishwasher'),
  ];

  /// Задача дня: одна и та же у всей семьи в этот день, меняется каждый день.
  static MiniTask forDay(
    DateTime day, {
    List<String> rooms = const [],
    List<String> modifiers = const [],
  }) {
    final pool = catalog
        .where(
          (t) =>
              (t.room == null || rooms.isEmpty || rooms.contains(t.room)) &&
              (t.modifier == null || modifiers.contains(t.modifier)),
        )
        .toList();
    final list = pool.isEmpty ? catalog : pool;
    final dayNumber = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ 86400000;
    // Простое перемешивание, чтобы соседние дни не шли по порядку каталога.
    final index = (dayNumber * 7919) % list.length;
    return list[index];
  }
}

class DailyRewards {
  DailyRewards._();
  static const miniTask = 5;
  static const allRules = 10;
}
