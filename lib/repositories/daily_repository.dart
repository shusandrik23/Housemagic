import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/daily.dart';
import '../core/streak.dart';
import '../models/daily_progress.dart';
import 'paths.dart';

class DailyRepository {
  DailyRepository(FirebaseFirestore db, {DateTime Function()? clock})
    : paths = Paths(db),
      _clock = clock ?? DateTime.now;

  final Paths paths;
  final DateTime Function() _clock;

  DocumentReference<Map<String, dynamic>> _day(String fid, String uid, String dayKey) =>
      paths.memberStats(fid).doc(uid).collection('days').doc(dayKey);

  Stream<DailyProgress> watchDay(String fid, String uid, String dayKey) =>
      _day(fid, uid, dayKey).snapshots().map((s) => DailyProgress.fromMap(s.data()));

  /// Отметить или снять правило. Когда за день выполнены все правила,
  /// один раз начисляется +10 пуговиц и растёт серия дней.
  /// Возвращает число начисленных пуговиц (0, если награды не было).
  Future<int> setRule({
    required String fid,
    required String uid,
    required String ruleId,
    required bool done,
    required List<String> allRuleIds,
  }) async {
    final now = _clock();
    final dayRef = _day(fid, uid, Streak.dayKey(now));
    final statsRef = paths.memberStats(fid).doc(uid);
    return paths.db.runTransaction<int>((tx) async {
      final daySnap = await tx.get(dayRef);
      final statsSnap = await tx.get(statsRef);
      final progress = DailyProgress.fromMap(daySnap.data());
      final rules = {...progress.rulesDone};
      done ? rules.add(ruleId) : rules.remove(ruleId);
      final allDone = allRuleIds.isNotEmpty && allRuleIds.every(rules.contains);
      final reward = allDone && !progress.allRulesRewarded;
      txUpsert(tx, dayRef, daySnap, {
        'rulesDone': rules.toList()..sort(),
        'allRulesRewarded': progress.allRulesRewarded || reward,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (reward) {
        final stats = statsSnap.data() ?? const <String, dynamic>{};
        txUpsert(tx, statsRef, statsSnap, {
          'coinsBalance': FieldValue.increment(DailyRewards.allRules),
          'streakCount': Streak.next(
            lastDay: stats['lastRulesDay'] as String?,
            current: (stats['streakCount'] as num?)?.toInt() ?? 0,
            now: now,
          ),
          'lastRulesDay': Streak.dayKey(now),
        });
        return DailyRewards.allRules;
      }
      return 0;
    });
  }

  /// «Сделано» у мини-задачи дня: +5 пуговиц, один раз в день.
  Future<int> completeMiniTask({
    required String fid,
    required String uid,
    required String taskId,
  }) async {
    final dayRef = _day(fid, uid, Streak.dayKey(_clock()));
    final statsRef = paths.memberStats(fid).doc(uid);
    return paths.db.runTransaction<int>((tx) async {
      final daySnap = await tx.get(dayRef);
      final statsSnap = await tx.get(statsRef);
      if (DailyProgress.fromMap(daySnap.data()).miniDone) return 0;
      txUpsert(tx, dayRef, daySnap, {
        'miniDone': true,
        'miniTaskId': taskId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      txUpsert(tx, statsRef, statsSnap, {
        'coinsBalance': FieldValue.increment(DailyRewards.miniTask),
      });
      return DailyRewards.miniTask;
    });
  }

  /// Изменить список ежедневных правил дома.
  Future<void> saveRules(String fid, List<DailyRule> rules) => paths.household(fid).set({
    'dailyRules': rules.map((r) => r.toMap()).toList(),
  }, SetOptions(merge: true));
}
