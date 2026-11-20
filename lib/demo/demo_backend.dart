import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:image_picker/image_picker.dart';

import '../core/codes.dart';
import '../core/streak.dart';
import '../services/app_services.dart';
import '../services/photo_service.dart';

/// Демо-режим: Firestore и вход живут в памяти вкладки браузера.
/// Ничего не уходит на сервер; после перезагрузки страницы всё сбрасывается.
class DemoBackend {
  DemoBackend._();

  static const momUid = 'demo-mom';
  static const dadUid = 'demo-dad';
  static const familyId = 'demo-family';
  static const parentPin = '1234';

  static Future<AppServices> create() async {
    final db = FakeFirebaseFirestore();
    await _seed(db);
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: momUid, email: 'anya@demo.cleanpage', displayName: 'Аня Иванова'),
    );
    return AppServices.withBackends(auth: auth, db: db, photos: DemoPhotoService());
  }

  static Future<void> _seed(FakeFirebaseFirestore db) async {
    final now = DateTime.now();
    Timestamp ago(int minutes) => Timestamp.fromDate(now.subtract(Duration(minutes: minutes)));
    final batch = db.batch();
    void set(String path, Map<String, dynamic> data) => batch.set(db.doc(path), data);

    // Профиль и общая семья (формат YouBoost Kids).
    set('users/$momUid', {
      'email': 'anya@demo.cleanpage',
      'displayName': 'Аня Иванова',
      'photoUrl': '',
      'createdAt': ago(60 * 24 * 30),
    });
    set('kidsUsers/$momUid', {'fid': familyId});
    set('kidsFamilies/$familyId', {
      'name': 'Дом Ивановых',
      'owner': momUid,
      'parents': {momUid: 'Аня', dadUid: 'Олег'},
      'rewards': <Object>[],
      'challenges': <Object>[],
      'createdAt': now.toUtc().toIso8601String(),
    });
    set('kidsFamilies/$familyId/members/$momUid', {'role': 'parent', 'name': 'Аня'});
    set('kidsFamilies/$familyId/members/$dadUid', {'role': 'parent', 'name': 'Олег'});
    set('kidsFamilies/$familyId/kids/misha', {
      'name': 'Миша',
      'age': 8,
      'avatar': '🦁',
      'color': '#ff8a3d',
      'habits': <Object>[],
      'pet': null,
      'order': 0,
      'createdAt': now.toUtc().toIso8601String(),
    });
    set('kidsFamilies/$familyId/kids/sonya', {
      'name': 'Соня',
      'age': 5,
      'avatar': '🦄',
      'color': '#7c5cff',
      'habits': <Object>[],
      'pet': null,
      'order': 1,
      'createdAt': now.toUtc().toIso8601String(),
    });

    // Надстройка Чистого Листа.
    set('households/$familyId', {
      'ownerUid': momUid,
      'parentPinHash': Codes.hashPin(parentPin, salt: familyId),
      'inviteCode': null,
      'inviteCodeExpires': null,
      'modifiers': ['cat', 'dishwasher'],
      'rooms': ['Кухня', 'Гостиная', 'Детская', 'Ванная', 'Прихожая'],
      'createdIn': 'cleanpage',
      'createdAt': ago(60 * 24 * 30),
    });
    set('households/$familyId/members/$momUid', {
      'uid': momUid,
      'name': 'Аня',
      'petType': 'hedgehog',
      'coinsBalance': 120,
      'streakCount': 5,
    });
    set('households/$familyId/members/$dadUid', {
      'uid': dadUid,
      'name': 'Олег',
      'petType': 'owl',
      'coinsBalance': 85,
      'streakCount': 2,
    });
    set('households/$familyId/children/misha', {
      'name': 'Миша',
      'ageGroup': '7-10',
      'petType': 'dragon',
      'goldButtons': 34,
      'streakCount': 3,
      'wishes': [
        {'title': 'Поход в кино', 'cost': 50},
        {'title': 'Набор LEGO', 'cost': 150},
      ],
    });
    set('households/$familyId/children/sonya', {
      'name': 'Соня',
      'ageGroup': '4-6',
      'petType': 'bunny',
      'goldButtons': 12,
      'streakCount': 1,
      'wishes': [
        {'title': 'Мороженое', 'cost': 20},
      ],
    });

    // Отметки Ани за сегодня: часть утренних правил уже выполнена.
    set('households/$familyId/members/$momUid/days/${Streak.dayKey(now)}', {
      'rulesDone': ['bed', 'dressed'],
      'miniDone': false,
    });

    // Квесты.
    Map<String, dynamic> quest(
      String child,
      String emoji,
      String monster,
      String title,
      int minutes,
      int reward,
      String status,
      int age, {
      String? photo,
    }) => {
      'childId': child,
      'title': title,
      'monster': monster,
      'emoji': emoji,
      'durationMinutes': minutes,
      'rewardButtons': reward,
      'status': status,
      'photoUrl': photo,
      'parentComment': null,
      'createdBy': momUid,
      'createdAt': ago(age),
      if (status == 'pending_approval') 'submittedAt': ago(age - 5),
    };
    set(
      'households/$familyId/child_quests/q1',
      quest(
        'misha',
        '🧦',
        'Носочный Гоблин',
        'Собери все носки и отнеси в корзину',
        10,
        8,
        'todo',
        120,
      ),
    );
    set(
      'households/$familyId/child_quests/q2',
      quest(
        'misha',
        '🐞',
        'Крошко-Жук',
        'Смахни крошки со стола',
        10,
        8,
        'pending_approval',
        60,
        photo: _demoPhoto,
      ),
    );
    set(
      'households/$familyId/child_quests/q3',
      quest('sonya', '🧸', 'Игрушечный Тролль', 'Расставь игрушки по домикам', 5, 5, 'todo', 90),
    );
    set('households/$familyId/victory_album/p1', {
      'childId': 'sonya',
      'childName': 'Соня',
      'questTitle': 'Заправь кровать',
      'photoUrl': _demoPhoto,
      'createdAt': ago(60 * 24),
    });

    // Покупки.
    var order = 300;
    void item(
      String list,
      String title,
      String category, {
      String? qty,
      bool bought = false,
      bool auto = false,
      String by = 'Аня',
    }) {
      set('households/$familyId/shopping_items/i$order', {
        'listType': list,
        'title': title,
        'quantity': qty,
        'category': category,
        'isBought': bought,
        'isAutoSuggested': auto,
        'addedByUid': by == 'Аня' ? momUid : dadUid,
        'addedByName': by,
        'boughtByUid': bought ? momUid : null,
        'createdAt': ago(order--),
      });
    }

    item('grocery', 'Молоко', 'Молочное', qty: '2 л');
    item('grocery', 'Бананы', 'Овощи и фрукты', qty: '1 кг', by: 'Олег');
    item('grocery', 'Хлеб', 'Выпечка');
    item('grocery', 'Кефир', 'Молочное', qty: '1 л', bought: true);
    item('grocery', 'Гречка', 'Бакалея', qty: '1 уп.');
    item('household_supplies', 'Губки', 'Расходники для уборки', auto: true);
    item('household_supplies', 'Средство для посуды', 'Бытовая химия');
    item('household_supplies', 'Наполнитель для лотка', 'Для питомцев', by: 'Олег');
    item('household_supplies', 'Лампочки E27', 'Ремонт и лампочки', auto: true);

    await batch.commit();
  }

  /// Картинка-заглушка «фото После»: тетрадный лист с зелёной галочкой (PNG).
  static const String _demoPhoto =
      'data:image/png;base64,'
      'iVBORw0KGgoAAAANSUhEUgAAAPAAAACgCAIAAAC9uXYyAAADYElEQVR42u3dMU4rMRSG0ayIgv2xRlbA'
      'HuhoQCJlpATimXHi699H8uu+yjrKG5h7w+n949NxYs7p/O/n+6v96PWVe6D1QOv1QOv1QOv1QOuBdkF6'
      'oPV6oPV6oPV6oPVAuyA90Ho90Ho90Hp9C2jHMQ+t13vk0OuB1uuB1gPtgvRA6/VA6/VA6/VA64F2QXqg'
      '9Xqg9Xqg9Xqg9UC7IL15aMcxD63Xe+TQ64HWA+1C9UDr9UDr9UDr9UDrgXaheqD1eqD1eqD1d/qXt9fr'
      'AzRAU/Y3Nf9lGmh96f4fzTdNA62v29/VfG3aPLRT9DRqPh/z0PrqfbvmwE9oIML6TZqB1pfut2oGWg80'
      '0Pqn9Ds0A60v2h/XDLS+St9FM9D6Ev0+zUADVLHvqBlo/aygjY8CVLHvqxlo/ci+u2ag9cP6R2gGWl9o'
      'AwVooNM2UA5qNg/t1J1yDh56Ng+90ErV7s9mjxz6oitVuzUDrX9ev/tJA2iA5l6puvxsBhqg6VeqgAYo'
      'agPl8tEZaOASQC97n0BbqQJab6UKaL2VKqCtVAENtJUqoIGbegMleKUKaCtVQK/66thKlXnotBni2Qed'
      'DYgvNw89xSecDRSPHD3ftFmpAjrt1fFcGyjtY/tArzsLYaUK6LThHitVQKdNq1mpAtr4pZUqoAuDfvSA'
      'vJUqoHNWmKxUAZ3ziVjzfwygV/kagO4/hFmpAnrwbxU6/prMShXQJX7v2+VFhg0UoHNeNdtAATpnGMhK'
      'lXnonG9Z9nXO5qFL/42SrfPTVqo8clRfeWoHZ6UK6Jwta3/UB+ic78GwgQL0yL7vNxVZqQJ6fN9LoZUq'
      'oKv0xy0OfBOpB7q/aStVQOfMT1upAjptftoGCtBp89M2UIBOm58GGui0+WkrVUCnzU9bqQI6bX7aSpV5'
      '6LT5aVPO5qHT5qdtoHjkSJufBhro5ean3T/Q08xPu0+gc+an3SfQOfPT7hPonPlp9wl0zvy0+wE6Z37a'
      '/QCt1wOt1wOtB9qF6oHW64HW681DO455aL1HDheqB1qvB1qvB1qvB1oPtF4PtF4PtF4PtB5oF6QHWq8H'
      'Wq8HWq8HWm8e2nHMQ+v1Hjn0eqD1eqD1QLsgPdB6PdB6PdB6PdB6oF2QHmi9Hmi9Hmi9Hmg90C5UP0//'
      'CwTisMPpgvC/AAAAAElFTkSuQmCC';
}

/// В демо фото не загружается в Storage, а остаётся в памяти как data URI.
class DemoPhotoService extends PhotoService {
  DemoPhotoService() : super();

  @override
  Future<String?> captureAndUpload({
    required String householdId,
    required String questId,
    ImageSource source = ImageSource.camera,
  }) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 900, imageQuality: 70);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }
}
