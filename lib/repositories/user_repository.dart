import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import 'paths.dart';

class UserRepository {
  UserRepository(FirebaseFirestore db) : paths = Paths(db);
  final Paths paths;

  /// Первый вход: создаёт `users/{uid}` (email, displayName, photoUrl,
  /// createdAt). Если документ уже есть (например, его создал YouBoost),
  /// только дописывает недостающие поля профиля через merge — привычки и
  /// настройки YouBoost не трогаются. Возвращает `true`, если документ создан.
  Future<bool> ensureUserDoc({
    required String uid,
    required String? email,
    required String? displayName,
    required String? photoUrl,
  }) async {
    final ref = paths.users.doc(uid);
    final snap = await ref.get();
    final name = (displayName ?? '').isNotEmpty ? displayName! : (email ?? '').split('@').first;
    if (!snap.exists) {
      await ref.set({
        'email': email ?? '',
        'displayName': name,
        'photoUrl': photoUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    }
    final data = snap.data() ?? const {};
    final patch = <String, dynamic>{
      if (!data.containsKey('email')) 'email': email ?? '',
      if (!data.containsKey('displayName')) 'displayName': name,
      if (!data.containsKey('photoUrl')) 'photoUrl': photoUrl ?? '',
      if (!data.containsKey('createdAt')) 'createdAt': FieldValue.serverTimestamp(),
    };
    if (patch.isNotEmpty) await ref.set(patch, SetOptions(merge: true));
    return false;
  }

  Stream<AppUser?> watchUser(String uid) =>
      paths.users.doc(uid).snapshots().map((s) => s.exists ? AppUser.fromDoc(s) : null);

  /// id семьи пользователя (общий с YouBoost `kidsUsers/{uid}.fid`).
  Stream<String?> watchFamilyId(String uid) => paths.kidsUsers.doc(uid).snapshots().map((s) {
    final fid = s.data()?['fid'];
    return fid is String && fid.isNotEmpty ? fid : null;
  });
}
