import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/shopping_logic.dart';
import 'firestore_utils.dart';

/// Документ `households/{householdId}/shopping_items/{itemId}`.
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.listType,
    required this.title,
    required this.quantity,
    required this.category,
    required this.isBought,
    required this.isAutoSuggested,
    required this.addedByUid,
    required this.addedByName,
    required this.boughtByUid,
    this.createdAt,
  });

  final String id;
  final ShoppingListType listType;
  final String title;
  final String? quantity;
  final String category;
  final bool isBought;
  final bool isAutoSuggested;
  final String addedByUid;
  final String addedByName;
  final String? boughtByUid;
  final DateTime? createdAt;

  factory ShoppingItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ShoppingItem(
      id: doc.id,
      listType: ShoppingListType.fromValue(d['listType'] as String?),
      title: d['title'] as String? ?? '',
      quantity: d['quantity'] as String?,
      category: d['category'] as String? ?? ShoppingCategories.other,
      isBought: d['isBought'] as bool? ?? false,
      isAutoSuggested: d['isAutoSuggested'] as bool? ?? false,
      addedByUid: d['addedByUid'] as String? ?? '',
      addedByName: d['addedByName'] as String? ?? '',
      boughtByUid: d['boughtByUid'] as String?,
      createdAt: readDate(d['createdAt']),
    );
  }

  Map<String, dynamic> toArchiveMap() => {
    'id': id,
    'title': title,
    'quantity': quantity,
    'category': category,
    'addedByName': addedByName,
    'boughtByUid': boughtByUid,
  };
}
