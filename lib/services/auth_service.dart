import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Вход через Google (FirebaseAuth + GoogleSignIn) и анонимная сессия для
/// детского телефона. Сессия сохраняется FirebaseAuth автоматически —
/// при повторном запуске срабатывает auto-login через `authStateChanges`.
class AuthService {
  AuthService(this._auth);
  final FirebaseAuth _auth;
  bool _googleInitialized = false;

  /// Web client ID (тип «Web application» из Google Cloud Console). Нужен на
  /// Android для получения idToken. Передаётся через
  /// `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.
  static const _serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// iOS client ID, если он не прописан в Info.plist (GIDClientID).
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Возвращает `null`, если пользователь закрыл окно выбора аккаунта.
  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});
      try {
        final cred = await _auth.signInWithPopup(provider);
        return cred.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
          return null;
        }
        rethrow;
      }
    }

    final google = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await google.initialize(
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
        clientId: _iosClientId.isEmpty ? null : _iosClientId,
      );
      _googleInitialized = true;
    }
    try {
      final account = await google.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Анонимная сессия — для детского телефона без Google-аккаунта.
  /// Сразу после входа устройство привязывается к ребёнку по коду.
  Future<User?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  Future<void> signOut() async {
    if (!kIsWeb && _googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Нет активной Google-сессии — не страшно.
      }
    }
    await _auth.signOut();
  }
}
