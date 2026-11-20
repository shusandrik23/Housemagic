// Настройки Firebase для «Чистого Листа».
//
// Приложение использует ТОТ ЖЕ Firebase-проект, что и YouBoost
// (`poleznie-privichki`), — поэтому Google-аккаунт и семья общие.
//
// Web-конфиг взят из YouBoost (значения не секретные, доступ к данным
// защищают правила Firestore). Для Android/iOS зарегистрируйте приложения
// в этом же проекте и перегенерируйте файл:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=poleznie-privichki
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Платформа не поддерживается: $defaultTargetPlatform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCoU36JR_tB4BZDj0ovhiNaBrNuUXQdcTo',
    appId: '1:842120280158:web:f8af42ef754ee9d9411ccf',
    messagingSenderId: '842120280158',
    projectId: 'poleznie-privichki',
    authDomain: 'poleznie-privichki.firebaseapp.com',
    storageBucket: 'poleznie-privichki.firebasestorage.app',
  );

  // TODO: заменить через `flutterfire configure --project=poleznie-privichki`.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: '842120280158',
    projectId: 'poleznie-privichki',
    storageBucket: 'poleznie-privichki.firebasestorage.app',
  );

  // TODO: заменить через `flutterfire configure --project=poleznie-privichki`.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: '842120280158',
    projectId: 'poleznie-privichki',
    storageBucket: 'poleznie-privichki.firebasestorage.app',
    iosBundleId: 'com.cleanpage.cleanPage',
  );
}
