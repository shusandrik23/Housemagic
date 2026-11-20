import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/streak.dart';
import '../models/child_quest.dart';
import 'paths.dart';

class QuestRepository {
  QuestRepository(FirebaseFirestore db, {DateTime Function()? clock})
    : paths = Paths(db),
      _clock = clock ?? DateTime.now;

  final Paths paths;
  final DateTime Function() _clock;

  Future<String> createQuest({
    required String householdId,
    required String childId,
    required String title,
    required String monster,
    required String emoji,
    required int durationMinutes,
    required int rewardButtons,
    required String createdByUid,
  }) async {
    final ref = paths.quests(householdId).doc();
    await ref.set({
      'childId': childId,
      'title': title,
      'monster': monster,
      'emoji': emoji,
      'durationMinutes': durationMinutes,
      'rewardButtons': rewardButtons,
      'status': QuestStatus.todo.value,
      'photoUrl': null,
      'parentComment': null,
      'createdBy': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<List<ChildQuest>> watchChildQuests(String householdId, String childId) => paths
      .quests(householdId)
      .where('childId', isEqualTo: childId)
      .snapshots()
      .map(
        (q) =>
            q.docs.map(ChildQuest.fromDoc).where((x) => x.status != QuestStatus.completed).toList()
              ..sort(_byCreated),
      );

  /// Квесты, ожидающие проверки родителем (стикер «Проверить квест»).
  Stream<List<ChildQuest>> watchPendingApprovals(String householdId) => paths
      .quests(householdId)
      .where('status', isEqualTo: QuestStatus.pendingApproval.value)
      .snapshots()
      .map((q) => q.docs.map(ChildQuest.fromDoc).toList()..sort(_byCreated));

  static int _byCreated(ChildQuest a, ChildQuest b) =>
      (a.createdAt ?? DateTime(2100)).compareTo(b.createdAt ?? DateTime(2100));

  /// Ребёнок прикрепил фото «После» → статус `pending_approval`.
  Future<void> submitForApproval({
    required String householdId,
    required String questId,
    required String photoUrl,
  }) => paths.quests(householdId).doc(questId).update({
    'status': QuestStatus.pendingApproval.value,
    'photoUrl': photoUrl,
    'parentComment': null,
    'submittedAt': FieldValue.serverTimestamp(),
  });

  /// «Принять ✨»: квест → `completed`, ребёнку начисляются золотые
  /// пуговицы и растёт серия, фото попадает в Альбом Побед.
  Future<void> approve({
    required String householdId,
    required String questId,
    required String approverUid,
  }) async {
    final questRef = paths.quests(householdId).doc(questId);
    await paths.db.runTransaction((tx) async {
      final questSnap = await tx.get(questRef);
      if (!questSnap.exists) return;
      final quest = ChildQuest.fromDoc(questSnap);
      if (quest.status != QuestStatus.pendingApproval) return;
      final childRef = paths.children(householdId).doc(quest.childId);
      final childSnap = await tx.get(childRef);
      final kidSnap = await tx.get(paths.familyKids(householdId).doc(quest.childId));
      final childData = childSnap.data() ?? const <String, dynamic>{};
      final childName = kidSnap.data()?['name'] ?? childData['name'] ?? '';
      final now = _clock();
      final streak = Streak.next(
        lastDay: childData['lastQuestDay'] as String?,
        current: (childData['streakCount'] as num?)?.toInt() ?? 0,
        now: now,
      );
      tx.update(questRef, {
        'status': QuestStatus.completed.value,
        'approvedBy': approverUid,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      // set(merge) — надстройки может ещё не быть, если ребёнка создали в YouBoost.
      txUpsert(tx, childRef, childSnap, {
        'goldButtons': FieldValue.increment(quest.rewardButtons),
        'streakCount': streak,
        'lastQuestDay': Streak.dayKey(now),
      });
      if ((quest.photoUrl ?? '').isNotEmpty) {
        tx.set(paths.album(householdId).doc(), {
          'childId': quest.childId,
          'childName': childName,
          'questId': quest.id,
          'questTitle': quest.title,
          'photoUrl': quest.photoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// «Переделать»: квест возвращается ребёнку с комментарием.
  Future<void> sendBack({required String householdId, required String questId, String? comment}) =>
      paths.quests(householdId).doc(questId).update({
        'status': QuestStatus.todo.value,
        'parentComment': comment,
      });

  Future<void> deleteQuest(String householdId, String questId) =>
      paths.quests(householdId).doc(questId).delete();

  Stream<List<VictoryPhoto>> watchAlbum(String householdId) => paths
      .album(householdId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((q) => q.docs.map(VictoryPhoto.fromDoc).toList());
}
