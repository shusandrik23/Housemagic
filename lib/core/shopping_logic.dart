/// Тип списка покупок.
enum ShoppingListType {
  grocery('grocery', 'Продукты'),
  householdSupplies('household_supplies', 'Для дома и уборки');

  const ShoppingListType(this.value, this.label);
  final String value;
  final String label;

  static ShoppingListType fromValue(String? v) => ShoppingListType.values.firstWhere(
    (t) => t.value == v,
    orElse: () => ShoppingListType.grocery,
  );

  List<String> get categories =>
      this == grocery ? ShoppingCategories.grocery : ShoppingCategories.householdSupplies;
}

class ShoppingCategories {
  ShoppingCategories._();

  static const fruitsVeg = 'Овощи и фрукты';
  static const dairy = 'Молочное';
  static const pantry = 'Бакалея';
  static const bakery = 'Выпечка';
  static const drinks = 'Напитки';
  static const other = 'Другое';

  static const chemicals = 'Бытовая химия';
  static const cleaningSupplies = 'Расходники для уборки';
  static const pets = 'Для питомцев';
  static const repair = 'Ремонт и лампочки';

  static const grocery = [fruitsVeg, dairy, pantry, bakery, drinks, other];
  static const householdSupplies = [chemicals, cleaningSupplies, pets, repair];
}

/// Результат разбора быстрой записи «как ручкой в тетради».
class QuickEntry {
  const QuickEntry(this.title, this.quantity);
  final String title;
  final String? quantity;
}

class ShoppingLogic {
  ShoppingLogic._();

  static final _qtyPattern = RegExp(
    r'^(.*?)[\s,]+(\d+(?:[.,]\d+)?\s*(?:шт\.?|кг|г|гр\.?|л|мл|уп\.?|пач\.?|бут\.?|банк[аи]?|рулон(?:а|ов)?|x|х)?)$',
    caseSensitive: false,
  );

  /// «Молоко 2 л» → (Молоко, 2 л); «Хлеб» → (Хлеб, null).
  static QuickEntry parseQuickEntry(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final m = _qtyPattern.firstMatch(text);
    if (m != null && m.group(1)!.trim().isNotEmpty) {
      return QuickEntry(_capitalize(m.group(1)!.trim()), m.group(2)!.trim());
    }
    return QuickEntry(_capitalize(text), null);
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static const _groceryKeywords = <String, List<String>>{
    ShoppingCategories.fruitsVeg: [
      'яблок',
      'банан',
      'апельсин',
      'мандарин',
      'лимон',
      'груш',
      'виноград',
      'картоф',
      'картош',
      'морков',
      'лук',
      'чеснок',
      'помидор',
      'томат',
      'огур',
      'капуст',
      'перец',
      'зелень',
      'укроп',
      'петрушк',
      'салат',
      'кабач',
      'свекл',
      'ягод',
      'авокадо',
      'киви',
    ],
    ShoppingCategories.dairy: [
      'молок',
      'кефир',
      'сыр',
      'творог',
      'йогурт',
      'сметан',
      'сливк',
      'масло слив',
      'ряженк',
      'простокваш',
      'яйц',
      'яйца',
    ],
    ShoppingCategories.bakery: [
      'хлеб',
      'батон',
      'булк',
      'булоч',
      'лаваш',
      'багет',
      'круасс',
      'пирог',
      'печень',
      'пряник',
      'торт',
      'сухар',
    ],
    ShoppingCategories.drinks: [
      'вода',
      'сок',
      'чай',
      'кофе',
      'лимонад',
      'морс',
      'компот',
      'квас',
      'газиров',
      'вино',
      'пиво',
    ],
    ShoppingCategories.pantry: [
      'крупа',
      'круп',
      'рис',
      'гречк',
      'макарон',
      'спагетти',
      'мука',
      'сахар',
      'соль',
      'масло подсол',
      'масло олив',
      'овсян',
      'хлопь',
      'консерв',
      'фасол',
      'горох',
      'специ',
      'соус',
      'кетчуп',
      'майонез',
      'мёд',
      'мед',
      'варенье',
    ],
  };

  static const _suppliesKeywords = <String, List<String>>{
    ShoppingCategories.pets: [
      'корм',
      'наполнит',
      'лоток',
      'пелёнк',
      'пеленк',
      'когтеточ',
      'поводок',
      'для кош',
      'для соб',
      'лакомств',
    ],
    ShoppingCategories.repair: [
      'лампоч',
      'лампа',
      'батарей',
      'изолент',
      'клей',
      'шуруп',
      'гвозд',
      'дюбел',
      'герметик',
      'краск',
      'кисть',
      'валик',
      'отвёртк',
      'отвертк',
      'удлинит',
      'скотч',
      'смесител',
      'прокладк',
      'фильтр для вод',
    ],
    ShoppingCategories.cleaningSupplies: [
      'губк',
      'тряпк',
      'салфет',
      'перчат',
      'мешк',
      'пакет',
      'швабр',
      'щётк',
      'щетк',
      'ёрш',
      'ерш',
      'микрофибр',
      'фильтр',
      'мешок для пылес',
      'бумаг',
      'полотенц',
      'рулон',
    ],
    ShoppingCategories.chemicals: [
      'средств',
      'порош',
      'гель',
      'кондиционер',
      'отбелив',
      'чистящ',
      'моющ',
      'спрей',
      'таблетк',
      'ополаскив',
      'антинакип',
      'освежит',
      'мыло',
      'domestos',
      'fairy',
      'белизн',
      'для стёкол',
      'для стекол',
    ],
  };

  /// Предлагает категорию по названию товара.
  static String suggestCategory(String title, ShoppingListType type) {
    final t = title.toLowerCase();
    final dict = type == ShoppingListType.grocery ? _groceryKeywords : _suppliesKeywords;
    for (final entry in dict.entries) {
      if (entry.value.any(t.contains)) return entry.key;
    }
    return type == ShoppingListType.grocery
        ? ShoppingCategories.other
        : ShoppingCategories.chemicals;
  }

  /// Порог «большой закупки».
  static const bigTripThreshold = 10;
  static const regularTripReward = 25;
  static const bigTripReward = 40;

  /// Награда за «Завершить поход в магазин»: +25 пуговиц, а за большую
  /// закупку (10+ вычеркнутых позиций) — +40.
  static int tripReward(int boughtCount) {
    if (boughtCount <= 0) return 0;
    return boughtCount >= bigTripThreshold ? bigTripReward : regularTripReward;
  }
}

/// Быстрые подсказки для пикера «Закончилось средство / Нужны материалы».
class SupplySuggestion {
  const SupplySuggestion(this.title, this.category, {this.modifier, this.forRepair = false});
  final String title;
  final String category;

  /// Показывать только если в доме есть этот модификатор.
  final String? modifier;
  final bool forRepair;

  static const all = <SupplySuggestion>[
    SupplySuggestion('Средство для посуды', ShoppingCategories.chemicals),
    SupplySuggestion('Средство для стёкол', ShoppingCategories.chemicals),
    SupplySuggestion('Средство для ванной', ShoppingCategories.chemicals),
    SupplySuggestion('Стиральный порошок', ShoppingCategories.chemicals),
    SupplySuggestion(
      'Таблетки для посудомойки',
      ShoppingCategories.chemicals,
      modifier: 'dishwasher',
    ),
    SupplySuggestion('Губки', ShoppingCategories.cleaningSupplies),
    SupplySuggestion('Мешки для мусора', ShoppingCategories.cleaningSupplies),
    SupplySuggestion('Салфетки из микрофибры', ShoppingCategories.cleaningSupplies),
    SupplySuggestion('Перчатки', ShoppingCategories.cleaningSupplies),
    SupplySuggestion(
      'Фильтр для робота-пылесоса',
      ShoppingCategories.cleaningSupplies,
      modifier: 'robot_vacuum',
    ),
    SupplySuggestion('Наполнитель для лотка', ShoppingCategories.pets, modifier: 'cat'),
    SupplySuggestion('Корм для кошки', ShoppingCategories.pets, modifier: 'cat'),
    SupplySuggestion('Корм для собаки', ShoppingCategories.pets, modifier: 'dog'),
    SupplySuggestion('Пакеты для выгула', ShoppingCategories.pets, modifier: 'dog'),
    SupplySuggestion('Лампочки', ShoppingCategories.repair, forRepair: true),
    SupplySuggestion('Батарейки', ShoppingCategories.repair, forRepair: true),
    SupplySuggestion('Изолента', ShoppingCategories.repair, forRepair: true),
    SupplySuggestion('Герметик', ShoppingCategories.repair, forRepair: true),
    SupplySuggestion('Шурупы и дюбели', ShoppingCategories.repair, forRepair: true),
    SupplySuggestion('Клей', ShoppingCategories.repair, forRepair: true),
  ];

  /// Подсказки под контекст (уборка или ремонт) и модификаторы дома.
  static List<SupplySuggestion> forContext({
    required bool repair,
    required List<String> modifiers,
  }) {
    final visible = all.where((s) => s.modifier == null || modifiers.contains(s.modifier));
    final primary = visible.where((s) => s.forRepair == repair);
    final secondary = visible.where((s) => s.forRepair != repair);
    return [...primary, ...secondary];
  }
}
