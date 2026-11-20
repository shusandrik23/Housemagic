import 'package:cloud_firestore/cloud_firestore.dart';

/// Пути коллекций Firestore.
///
/// Общие с YouBoost (тот же Firebase-проект `poleznie-privichki`):
///   kidsUsers/{uid}                  — { fid } в какой семье пользователь
///   kidsCodes/{code}                 — код подключения (6 символов, сутки)
///   kidsFamilies/{fid}               — семья (name, owner, parents, …)
///   kidsFamilies/{fid}/members/{uid} — родители и телефоны детей
///   kidsFamilies/{fid}/kids/{kidId}  — общая карточка ребёнка
///
/// Только Чистый Лист — тот же id семьи:
///   households/{fid}                 — комнаты, модификаторы, PIN, код
///   households/{fid}/members/{uid}   — питомец, пуговицы, серия взрослого
///   households/{fid}/children/{kid}  — возраст, питомец, золотые пуговицы
///   households/{fid}/child_quests, victory_album, shopping_items, shopping_trips
class Paths {
  Paths(this.db);
  final FirebaseFirestore db;

  // --- Общее с YouBoost ---
  CollectionReference<Map<String, dynamic>> get users => db.collection('users');
  CollectionReference<Map<String, dynamic>> get kidsUsers => db.collection('kidsUsers');
  CollectionReference<Map<String, dynamic>> get kidsCodes => db.collection('kidsCodes');
  CollectionReference<Map<String, dynamic>> get kidsFamilies => db.collection('kidsFamilies');
  DocumentReference<Map<String, dynamic>> family(String fid) => kidsFamilies.doc(fid);
  CollectionReference<Map<String, dynamic>> familyMembers(String fid) =>
      family(fid).collection('members');
  CollectionReference<Map<String, dynamic>> familyKids(String fid) =>
      family(fid).collection('kids');

  // --- Чистый Лист ---
  CollectionReference<Map<String, dynamic>> get households => db.collection('households');
  DocumentReference<Map<String, dynamic>> household(String fid) => households.doc(fid);
  CollectionReference<Map<String, dynamic>> memberStats(String fid) =>
      household(fid).collection('members');
  CollectionReference<Map<String, dynamic>> children(String fid) =>
      household(fid).collection('children');
  CollectionReference<Map<String, dynamic>> quests(String fid) =>
      household(fid).collection('child_quests');
  CollectionReference<Map<String, dynamic>> album(String fid) =>
      household(fid).collection('victory_album');
  CollectionReference<Map<String, dynamic>> shoppingItems(String fid) =>
      household(fid).collection('shopping_items');
  CollectionReference<Map<String, dynamic>> shoppingTrips(String fid) =>
      household(fid).collection('shopping_trips');
}

class FamilyRole {
  static const parent = 'parent';
  static const child = 'child';
}

/// Ошибка, понятная пользователю (показывается в SnackBar).
class UserFacingException implements Exception {
  UserFacingException(this.message);
  final String message;
  @override
  String toString() => message;
}
