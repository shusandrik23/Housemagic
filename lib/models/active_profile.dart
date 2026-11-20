/// Профиль, от имени которого сейчас работает приложение: взрослый
/// участник или ребёнок (в детском режиме). Используется для начисления
/// наград.
sealed class ActiveProfile {
  const ActiveProfile();
  String get displayName;
}

class AdultActiveProfile extends ActiveProfile {
  const AdultActiveProfile({required this.uid, required this.displayName});
  final String uid;
  @override
  final String displayName;
}

class ChildActiveProfile extends ActiveProfile {
  const ChildActiveProfile({required this.childId, required this.displayName});
  final String childId;
  @override
  final String displayName;
}
