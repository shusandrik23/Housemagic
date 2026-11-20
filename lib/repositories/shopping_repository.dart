import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/shopping_logic.dart';
import '../models/active_profile.dart';
import '../models/shopping_item.dart';
import 'paths.dart';

class ShoppingRepository {
  ShoppingRepository(FirebaseFirestore db) : paths = Paths(db);
  final Paths paths;

  /// Живой список одной вкладки (синхронизация через snapshots).
  /// Сортировка на клиенте — без составного индекса.
  Stream<List<ShoppingItem>> watchList(String householdId, ShoppingListType type) => paths
      .shoppingItems(householdId)
      .where('listType', isEqualTo: type.value)
      .snapshots()
      .map(
        (q) => q.docs.map(ShoppingItem.fromDoc).toList()
          ..sort(
            (a, b) => (a.createdAt ?? DateTime(2100)).compareTo(b.createdAt ?? DateTime(2100)),
          ),
      );

  Future<String> addItem({
    required String householdId,
    required ShoppingListType listType,
    required String title,
    String? quantity,
    String? category,
    required String addedByUid,
    required String addedByName,
    bool isAutoSuggested = false,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw UserFacingException('Пустая строка');
    final resolvedCategory = (category != null && listType.categories.contains(category))
        ? category
        : ShoppingLogic.suggestCategory(cleanTitle, listType);
    final ref = paths.shoppingItems(householdId).doc();
    await ref.set({
      'listType': listType.value,
      'title': cleanTitle,
      // У хозтоваров количества нет по схеме.
      'quantity': listType == ShoppingListType.grocery ? quantity : null,
      'category': resolvedCategory,
      'isBought': false,
      'isAutoSuggested': isAutoSuggested,
      'addedByUid': addedByUid,
      'addedByName': addedByName,
      'boughtByUid': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Кнопка «Закончилось средство / Нужны материалы» из карточки уборки
  /// или ремонта — пишет СТРОГО во вкладку `household_supplies`.
  /// Если такая позиция уже есть и не куплена — дубль не создаётся.
  Future<bool> addSupplyFromTask({
    required String householdId,
    required String title,
    String? category,
    required String addedByUid,
    required String addedByName,
  }) async {
    final existing = await paths
        .shoppingItems(householdId)
        .where('listType', isEqualTo: ShoppingListType.householdSupplies.value)
        .get();
    final norm = title.trim().toLowerCase();
    final duplicate = existing.docs.any(
      (d) =>
          (d.data()['title'] as String? ?? '').toLowerCase() == norm &&
          d.data()['isBought'] != true,
    );
    if (duplicate) return false;
    await addItem(
      householdId: householdId,
      listType: ShoppingListType.householdSupplies,
      title: title,
      category: category,
      addedByUid: addedByUid,
      addedByName: addedByName,
      isAutoSuggested: true,
    );
    return true;
  }

  Future<void> setBought({
    required String householdId,
    required String itemId,
    required bool isBought,
    required String byUid,
  }) => paths.shoppingItems(householdId).doc(itemId).update({
    'isBought': isBought,
    'boughtByUid': isBought ? byUid : null,
  });

  Future<void> deleteItem(String householdId, String itemId) =>
      paths.shoppingItems(householdId).doc(itemId).delete();

  /// «Завершить поход в магазин»: купленные позиции уходят в архив
  /// `shopping_trips`, удаляются из списка, а профилю начисляется награда.
  /// Возвращает количество начисленных пуговиц.
  Future<int> completeTrip({
    required String householdId,
    required ShoppingListType listType,
    required String byUid,
    required ActiveProfile profile,
  }) async {
    final bought = await paths
        .shoppingItems(householdId)
        .where('listType', isEqualTo: listType.value)
        .where('isBought', isEqualTo: true)
        .get();
    if (bought.docs.isEmpty) {
      throw UserFacingException('Сначала вычеркните купленное');
    }
    final items = bought.docs.map(ShoppingItem.fromDoc).toList();
    final reward = ShoppingLogic.tripReward(items.length);
    final batch = paths.db.batch();
    batch.set(paths.shoppingTrips(householdId).doc(), {
      'listType': listType.value,
      'items': items.map((i) => i.toArchiveMap()).toList(),
      'itemCount': items.length,
      'reward': reward,
      'completedByUid': byUid,
      'completedByName': profile.displayName,
      'completedAt': FieldValue.serverTimestamp(),
    });
    for (final doc in bought.docs) {
      batch.delete(doc.reference);
    }
    switch (profile) {
      case AdultActiveProfile(:final uid):
        batch.set(paths.memberStats(householdId).doc(uid), {
          'coinsBalance': FieldValue.increment(reward),
        }, SetOptions(merge: true));
      case ChildActiveProfile(:final childId):
        batch.set(paths.children(householdId).doc(childId), {
          'goldButtons': FieldValue.increment(reward),
        }, SetOptions(merge: true));
    }
    await batch.commit();
    return reward;
  }
}
