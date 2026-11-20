import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_profile.dart';
import '../models/app_user.dart';
import '../models/child_profile.dart';
import '../models/household.dart';
import '../repositories/children_repository.dart';
import '../repositories/household_repository.dart';
import '../repositories/paths.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

enum SessionStage {
  loading,
  signedOut,

  /// Пользователь не состоит ни в одной семье → «Создать Дом / Присоединиться».
  needsHousehold,

  /// Семья есть (например, создана в YouBoost), но Чистый Лист для неё ещё
  /// не настроен → короткая настройка: комнаты, модификаторы, PIN.
  needsSetup,
  ready,
}

/// Состояние сессии: Firebase-пользователь → `kidsUsers/{uid}.fid` →
/// общая семья + надстройка Чистого Листа. Хранит активный профиль
/// (взрослый или ребёнок в детском режиме).
class SessionController extends ChangeNotifier {
  SessionController({
    required this.auth,
    required this.users,
    required this.households,
    required this.children,
    SharedPreferences? prefs,
  }) {
    _prefs = prefs;
    _authSub = auth.authStateChanges().listen(_onAuthChanged);
  }

  final AuthService auth;
  final UserRepository users;
  final HouseholdRepository households;
  final ChildrenRepository children;
  SharedPreferences? _prefs;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<String?>? _fidSub;
  final List<StreamSubscription<Object?>> _dataSubs = [];

  SessionStage stage = SessionStage.loading;
  User? firebaseUser;
  AppUser? appUser;
  String? familyId;
  String? errorMessage;

  /// Код, введённый на экране входа до авторизации.
  String? pendingCode;

  // Сырые данные из Firestore.
  DocMap? _family;
  bool _familyLoaded = false;
  DocMap? _ext;
  Map<String, DocMap> _familyMembers = const {};
  Map<String, DocMap> _memberStats = const {};
  Map<String, DocMap> _kids = const {};
  Map<String, DocMap> _childExt = const {};

  // Собранные модели.
  Household? household;
  List<Member> members = const [];
  List<ChildProfile> childProfiles = const [];
  String? _activeChildId;

  String? get uid => firebaseUser?.uid;

  Member? get me {
    for (final m in members) {
      if (m.uid == uid) return m;
    }
    return null;
  }

  String? get _myFamilyRole => _familyMembers[uid]?['role'] as String?;

  /// Взрослый участник семьи. По общим правилам YouBoost любой родитель
  /// может управлять детьми, кодами и подтверждениями.
  bool get isParent => _myFamilyRole == FamilyRole.parent;

  /// Устройство привязано к ребёнку (Сценарий 2) — детский режим постоянный.
  bool get isChildDevice => _myFamilyRole == FamilyRole.child;

  String? get activeChildId {
    if (!isChildDevice) return _activeChildId;
    final kidId = _familyMembers[uid]?['kidId'];
    return kidId is String ? kidId : null;
  }

  ChildProfile? get activeChild {
    final id = activeChildId;
    if (id == null) return null;
    for (final c in childProfiles) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool get inChildMode => activeChildId != null;

  ActiveProfile get activeProfile {
    final child = activeChild;
    if (child != null) return ChildActiveProfile(childId: child.id, displayName: child.name);
    return AdultActiveProfile(uid: uid ?? '', displayName: displayName);
  }

  String get displayName {
    final fromMember = me?.name ?? '';
    if (fromMember.isNotEmpty && fromMember != 'Взрослый') return fromMember;
    final fromDoc = appUser?.displayName ?? '';
    if (fromDoc.isNotEmpty) return fromDoc.split(' ').first;
    final fromAuth = firebaseUser?.displayName ?? '';
    return fromAuth.isNotEmpty ? fromAuth.split(' ').first : 'Хранитель';
  }

  Future<void> _onAuthChanged(User? user) async {
    await _cancelDataSubs();
    await _userSub?.cancel();
    await _fidSub?.cancel();
    _userSub = null;
    _fidSub = null;
    firebaseUser = user;
    appUser = null;
    familyId = null;
    errorMessage = null;
    if (user == null) {
      stage = SessionStage.signedOut;
      notifyListeners();
      return;
    }
    stage = SessionStage.loading;
    notifyListeners();
    try {
      await users.ensureUserDoc(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );
    } catch (e) {
      errorMessage = 'Не удалось создать профиль: $e';
    }
    _userSub = users.watchUser(user.uid).listen((u) {
      appUser = u;
      notifyListeners();
    }, onError: _onStreamError);
    _fidSub = users.watchFamilyId(user.uid).listen(_onFamilyId, onError: _onStreamError);
  }

  Future<void> _onFamilyId(String? fid) async {
    if (fid == familyId && _dataSubs.isNotEmpty) return;
    await _cancelDataSubs();
    familyId = fid;
    if (fid == null) {
      household = null;
      stage = SessionStage.needsHousehold;
      notifyListeners();
      return;
    }
    stage = SessionStage.loading;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    // Детский режим переживает перезапуск — ребёнок не выйдет из него,
    // просто закрыв приложение.
    _activeChildId = _prefs!.getString(_childPrefKey(fid));
    _dataSubs
      ..add(
        households.watchFamily(fid).listen((d) {
          _family = d;
          _familyLoaded = true;
          _rebuild();
        }, onError: _onStreamError),
      )
      ..add(
        households.watchHouseholdExt(fid).listen((d) {
          _ext = d;
          _rebuild();
        }, onError: _onStreamError),
      )
      ..add(
        households.watchFamilyMembers(fid).listen((d) {
          _familyMembers = d;
          _rebuild();
        }, onError: _onStreamError),
      )
      ..add(
        households.watchMemberStats(fid).listen((d) {
          _memberStats = d;
          _rebuild();
        }, onError: _onStreamError),
      )
      ..add(
        children.watchKids(fid).listen((d) {
          _kids = d;
          _rebuild();
        }, onError: _onStreamError),
      )
      ..add(
        children.watchChildExt(fid).listen((d) {
          _childExt = d;
          _rebuild();
        }, onError: _onStreamError),
      );
  }

  /// Собирает модели из общих данных семьи и надстройки Чистого Листа.
  void _rebuild() {
    final fid = familyId;
    if (fid == null) return;
    final family = _family;
    if (!_familyLoaded) return;
    if (family == null) {
      household = null;
      stage = SessionStage.needsHousehold;
      notifyListeners();
      return;
    }
    final h = Household.fromParts(
      id: fid,
      family: family,
      ext: _ext,
      kidsHaveHabits: _kids.values.any((k) {
        final habits = k['habits'];
        return habits is List && habits.isNotEmpty;
      }),
    );
    household = h;
    members = [
      for (final e in _familyMembers.entries)
        if (e.value['role'] == FamilyRole.parent)
          Member.fromParts(
            uid: e.key,
            ownerUid: h.ownerUid,
            familyMember: e.value,
            stats: _memberStats[e.key],
          ),
    ]..sort((a, b) => a.isAdmin == b.isAdmin ? a.name.compareTo(b.name) : (a.isAdmin ? -1 : 1));
    final devicesByKid = <String, List<String>>{};
    for (final e in _familyMembers.entries) {
      final kidId = e.value['kidId'];
      if (e.value['role'] == FamilyRole.child && kidId is String) {
        devicesByKid.putIfAbsent(kidId, () => []).add(e.key);
      }
    }
    final kidEntries = _kids.entries.toList()
      ..sort((a, b) {
        final oa = (a.value['order'] as num?)?.toInt() ?? 0;
        final ob = (b.value['order'] as num?)?.toInt() ?? 0;
        return oa != ob ? oa.compareTo(ob) : '${a.value['name']}'.compareTo('${b.value['name']}');
      });
    childProfiles = [
      for (final e in kidEntries)
        ChildProfile.fromParts(
          id: e.key,
          kid: e.value,
          ext: _childExt[e.key],
          linkedUids: devicesByKid[e.key] ?? const [],
        ),
    ];
    if (_activeChildId != null && _kids.isNotEmpty && !_kids.containsKey(_activeChildId)) {
      _activeChildId = null;
    }
    stage = (!h.isConfigured && !isChildDevice) ? SessionStage.needsSetup : SessionStage.ready;
    notifyListeners();
  }

  void _onStreamError(Object e) {
    errorMessage = '$e';
    notifyListeners();
  }

  Future<void> _cancelDataSubs() async {
    for (final s in _dataSubs) {
      await s.cancel();
    }
    _dataSubs.clear();
    _family = null;
    _familyLoaded = false;
    _ext = null;
    _familyMembers = const {};
    _memberStats = const {};
    _kids = const {};
    _childExt = const {};
    members = const [];
    childProfiles = const [];
  }

  String _childPrefKey(String fid) => 'activeChild_$fid';

  /// Переключатель профиля: родитель открывает Детский режим.
  Future<void> enterChildMode(String childId) async {
    final fid = familyId;
    if (fid == null) return;
    _activeChildId = childId;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_childPrefKey(fid), childId);
    notifyListeners();
  }

  /// Выход из детского режима — только с верным Родительским PIN-кодом.
  Future<bool> exitChildMode({required String pin}) async {
    if (!verifyPin(pin)) return false;
    await _clearChildMode();
    return true;
  }

  /// Выход по биометрии (проверка выполняется вызывающим кодом).
  Future<void> exitChildModeAfterBiometrics() => _clearChildMode();

  Future<void> _clearChildMode() async {
    final fid = familyId;
    _activeChildId = null;
    if (fid != null) {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_childPrefKey(fid));
    }
    notifyListeners();
  }

  bool verifyPin(String pin) {
    final h = household;
    return h != null && households.verifyPin(h, pin);
  }

  Future<void> signOut() async {
    final fid = familyId;
    if (fid != null) {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_childPrefKey(fid));
    }
    _activeChildId = null;
    await auth.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    _fidSub?.cancel();
    for (final s in _dataSubs) {
      s.cancel();
    }
    super.dispose();
  }
}
