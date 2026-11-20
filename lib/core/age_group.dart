/// Возрастная группа ребёнка — определяет сложность квестов и длину таймера.
enum AgeGroup {
  small('4-6', '4–6 лет', 5, 'Малыш-Хранитель', 5),
  middle('7-10', '7–10 лет', 10, 'Юный Хранитель', 8),
  teen('11+', '11+ лет', 15, 'Старший Хранитель', 11);

  const AgeGroup(this.value, this.label, this.timerMinutes, this.rank, this.typicalAge);

  /// Значение в Firestore (`'4-6' | '7-10' | '11+'`).
  final String value;
  final String label;

  /// Длительность таймера квеста в минутах (для 4–6 лет — 3–5 минут).
  final int timerMinutes;
  final String rank;

  /// Возраст, который пишется в общую карточку ребёнка YouBoost (`age`).
  final int typicalAge;

  static AgeGroup fromValue(String? value) =>
      AgeGroup.values.firstWhere((g) => g.value == value, orElse: () => AgeGroup.middle);

  /// Группа по возрасту из карточки YouBoost (там `age` — число 5…14).
  static AgeGroup fromAge(int? age) {
    if (age == null) return AgeGroup.middle;
    if (age <= 6) return AgeGroup.small;
    if (age <= 10) return AgeGroup.middle;
    return AgeGroup.teen;
  }
}
