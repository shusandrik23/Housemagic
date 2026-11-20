import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

int readInt(Object? value, [int fallback = 0]) => value is num ? value.toInt() : fallback;

List<String> readStringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];
