/// Справочники приложения: комнаты, модификаторы, питомцы, монстрики.
class Catalog {
  Catalog._();

  static const rooms = <String>[
    'Кухня',
    'Гостиная',
    'Спальня',
    'Детская',
    'Ванная',
    'Туалет',
    'Прихожая',
    'Балкон',
    'Кабинет',
  ];

  static const modifiers = <String, String>{
    'cat': '🐱 Кошка',
    'dog': '🐶 Собака',
    'robot_vacuum': '🤖 Робот-пылесос',
    'dishwasher': '🍽 Посудомойка',
  };

  static const pets = <String, String>{
    'hedgehog': '🦔 Ёжик Шуршик',
    'cat': '🐈 Котик Мурчик',
    'owl': '🦉 Совёнок Ух',
    'fox': '🦊 Лисёнок Рыжик',
    'dragon': '🐉 Дракоша Пых',
    'bunny': '🐰 Зайка Пушок',
  };

  static String petEmoji(String? petType) => (pets[petType] ?? '🦔').split(' ').first;

  static String petLabel(String? petType) => pets[petType] ?? pets['hedgehog']!;

  /// Шаблоны детских квестов с монстриками.
  static const questTemplates = <QuestTemplate>[
    QuestTemplate('🧦', 'Носочный Гоблин', 'Собери все носки и отнеси в корзину'),
    QuestTemplate('🐞', 'Крошко-Жук', 'Смахни крошки со стола'),
    QuestTemplate('🧸', 'Игрушечный Тролль', 'Расставь игрушки по домикам'),
    QuestTemplate('🐉', 'Пыльный Дракончик', 'Протри пыль на полках'),
    QuestTemplate('👟', 'Обувной Кракен', 'Выставь обувь в прихожей парами'),
    QuestTemplate('🛏', 'Одеяльный Призрак', 'Заправь кровать'),
  ];
}

class QuestTemplate {
  const QuestTemplate(this.emoji, this.monster, this.title);
  final String emoji;
  final String monster;
  final String title;
}

/// Значения общей карточки ребёнка в формате YouBoost Kids.
class YouBoostKid {
  YouBoostKid._();

  static const avatars = [
    '🦁',
    '🐯',
    '🐻',
    '🐼',
    '🐨',
    '🐰',
    '🦊',
    '🐸',
    '🐵',
    '🦄',
    '🐙',
    '🦖',
    '🐧',
    '🐝',
    '🦋',
    '🐬',
    '🚀',
    '⚽',
    '🌸',
    '🌟',
  ];
  static const colors = [
    '#ff8a3d',
    '#7c5cff',
    '#2fbf71',
    '#ff5d8f',
    '#22a7f0',
    '#f5b400',
    '#14b8a6',
    '#e0533d',
  ];
}
