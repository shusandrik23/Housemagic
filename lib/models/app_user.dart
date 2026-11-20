import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_utils.dart';

/// Профиль `users/{uid}` (общий с YouBoost: тот же Firebase-проект и uid).
/// Принадлежность к семье хранится в общем `kidsUsers/{uid}.fid`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final DateTime? createdAt;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      email: d['email'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      photoUrl: d['photoUrl'] as String? ?? '',
      createdAt: readDate(d['createdAt']),
    );
  }
}
