import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../repositories/children_repository.dart';
import '../repositories/daily_repository.dart';
import '../repositories/household_repository.dart';
import '../repositories/quest_repository.dart';
import '../repositories/shopping_repository.dart';
import '../repositories/user_repository.dart';
import 'auth_service.dart';
import 'biometric_service.dart';
import 'photo_service.dart';

/// Контейнер зависимостей, раздаётся через Provider.
class AppServices {
  AppServices({
    required this.auth,
    required this.users,
    required this.households,
    required this.children,
    required this.quests,
    required this.shopping,
    required this.daily,
    required this.photos,
    required this.biometrics,
  });

  /// Для тестов и эмулятора: любые экземпляры FirebaseAuth / Firestore.
  factory AppServices.withBackends({
    required FirebaseAuth auth,
    required FirebaseFirestore db,
    BiometricService? biometrics,
    PhotoService? photos,
  }) => AppServices(
    auth: AuthService(auth),
    users: UserRepository(db),
    households: HouseholdRepository(db),
    children: ChildrenRepository(db),
    quests: QuestRepository(db),
    shopping: ShoppingRepository(db),
    daily: DailyRepository(db),
    photos: photos ?? PhotoService(),
    biometrics: biometrics ?? BiometricService(),
  );

  factory AppServices.firebase() {
    final db = FirebaseFirestore.instance;
    return AppServices(
      auth: AuthService(FirebaseAuth.instance),
      users: UserRepository(db),
      households: HouseholdRepository(db),
      children: ChildrenRepository(db),
      quests: QuestRepository(db),
      shopping: ShoppingRepository(db),
      daily: DailyRepository(db),
      photos: PhotoService(storage: FirebaseStorage.instance),
      biometrics: BiometricService(),
    );
  }

  final AuthService auth;
  final UserRepository users;
  final HouseholdRepository households;
  final ChildrenRepository children;
  final QuestRepository quests;
  final ShoppingRepository shopping;
  final DailyRepository daily;
  final PhotoService photos;
  final BiometricService biometrics;
}
