/// Подсчёт серии дней (стрика) по дате последнего выполненного дела.
class Streak {
  Streak._();

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Если последнее дело было вчера — серия растёт, сегодня — не меняется,
  /// раньше (или никогда) — начинается заново с 1.
  static int next({required String? lastDay, required int current, required DateTime now}) {
    final today = dayKey(now);
    if (lastDay == today) return current < 1 ? 1 : current;
    final yesterday = dayKey(DateTime(now.year, now.month, now.day - 1));
    if (lastDay == yesterday) return current + 1;
    return 1;
  }
}
