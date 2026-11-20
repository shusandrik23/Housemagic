import 'firestore_utils.dart';

/// Отметки взрослого за один день:
/// `households/{fid}/members/{uid}/days/{yyyy-MM-dd}`.
class DailyProgress {
  const DailyProgress({
    this.rulesDone = const {},
    this.miniDone = false,
    this.allRulesRewarded = false,
  });

  final Set<String> rulesDone;
  final bool miniDone;
  final bool allRulesRewarded;

  factory DailyProgress.fromMap(Map<String, dynamic>? d) {
    if (d == null) return const DailyProgress();
    return DailyProgress(
      rulesDone: readStringList(d['rulesDone']).toSet(),
      miniDone: d['miniDone'] == true,
      allRulesRewarded: d['allRulesRewarded'] == true,
    );
  }
}
