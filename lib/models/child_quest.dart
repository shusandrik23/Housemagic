import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_utils.dart';

enum QuestStatus {
  todo('todo'),
  pendingApproval('pending_approval'),
  completed('completed');

  const QuestStatus(this.value);
  final String value;

  static QuestStatus fromValue(String? v) =>
      QuestStatus.values.firstWhere((s) => s.value == v, orElse: () => QuestStatus.todo);
}

/// Документ `households/{householdId}/child_quests/{questId}`.
class ChildQuest {
  const ChildQuest({
    required this.id,
    required this.childId,
    required this.title,
    required this.monster,
    required this.emoji,
    required this.durationMinutes,
    required this.rewardButtons,
    required this.status,
    this.photoUrl,
    this.parentComment,
    this.createdAt,
    this.submittedAt,
  });

  final String id;
  final String childId;
  final String title;
  final String monster;
  final String emoji;
  final int durationMinutes;
  final int rewardButtons;
  final QuestStatus status;
  final String? photoUrl;
  final String? parentComment;
  final DateTime? createdAt;
  final DateTime? submittedAt;

  factory ChildQuest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ChildQuest(
      id: doc.id,
      childId: d['childId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      monster: d['monster'] as String? ?? '',
      emoji: d['emoji'] as String? ?? '✨',
      durationMinutes: readInt(d['durationMinutes'], 10),
      rewardButtons: readInt(d['rewardButtons'], 5),
      status: QuestStatus.fromValue(d['status'] as String?),
      photoUrl: d['photoUrl'] as String?,
      parentComment: d['parentComment'] as String?,
      createdAt: readDate(d['createdAt']),
      submittedAt: readDate(d['submittedAt']),
    );
  }
}

/// Документ `households/{householdId}/victory_album/{id}` — Альбом Побед.
class VictoryPhoto {
  const VictoryPhoto({
    required this.id,
    required this.childName,
    required this.questTitle,
    required this.photoUrl,
    this.createdAt,
  });

  final String id;
  final String childName;
  final String questTitle;
  final String photoUrl;
  final DateTime? createdAt;

  factory VictoryPhoto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return VictoryPhoto(
      id: doc.id,
      childName: d['childName'] as String? ?? '',
      questTitle: d['questTitle'] as String? ?? '',
      photoUrl: d['photoUrl'] as String? ?? '',
      createdAt: readDate(d['createdAt']),
    );
  }
}
