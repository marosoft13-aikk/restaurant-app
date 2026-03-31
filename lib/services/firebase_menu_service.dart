import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/menu_item_model.dart';

class FirebaseMenuService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String collectionName = 'products';

  Stream<List<MenuItemModel>> menuStream({bool removeOrderBy = false}) {
    final colRef = _db.collection(collectionName);
    final query =
        removeOrderBy ? colRef : colRef.orderBy('createdAt', descending: true);

    return query.snapshots().handleError((e, st) {
      debugPrint('menuStream: snapshot error: $e\n$st');
    }).map((snap) {
      debugPrint('menuStream: snapshot docs=${snap.docs.length}');
      final list = <MenuItemModel>[];
      for (final doc in snap.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final map = Map<String, dynamic>.from(data);
          map['id'] = doc.id;

          map['imagePath'] = (map['imagePath']?.toString().isNotEmpty == true)
              ? map['imagePath']
              : (map['image'] ?? map['imageUrl'] ?? '');

          map['category'] = (map['category']?.toString() ?? '').toLowerCase();

          if (map['options'] == null) {
            map['options'] = <Map<String, dynamic>>[];
          } else if (map['options'] is String) {
            map['options'] = map['options']
                .toString()
                .split(',')
                .map((s) => {'value': s.trim()})
                .where((m) => (m['value'] ?? '').toString().isNotEmpty)
                .toList();
          } else {
            try {
              map['options'] = List<Map<String, dynamic>>.from(map['options']);
            } catch (_) {
              map['options'] = <Map<String, dynamic>>[];
            }
          }

          final item = MenuItemModel.fromMap(doc.id, map);
          list.add(item);
        } catch (e, st) {
          debugPrint('menuStream: failed mapping doc ${doc.id}: $e\n$st');
        }
      }
      return list;
    });
  }

  Future<List<MenuItemModel>> getMenu({bool removeOrderBy = false}) async {
    try {
      final colRef = _db.collection(collectionName);
      final snap = removeOrderBy
          ? await colRef.get()
          : await colRef.orderBy('createdAt', descending: true).get();
      debugPrint('getMenu: got ${snap.docs.length} docs');
      final list = <MenuItemModel>[];
      for (final doc in snap.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final map = Map<String, dynamic>.from(data);
          map['id'] = doc.id;
          map['imagePath'] = (map['imagePath']?.toString().isNotEmpty == true)
              ? map['imagePath']
              : (map['image'] ?? map['imageUrl'] ?? '');
          map['category'] = (map['category']?.toString() ?? '').toLowerCase();
          list.add(MenuItemModel.fromMap(doc.id, map));
        } catch (e, st) {
          debugPrint('getMenu: mapping failed for ${doc.id}: $e\n$st');
        }
      }
      return list;
    } catch (e, st) {
      debugPrint('getMenu error: $e\n$st');
      return [];
    }
  }

  Future<void> addOrUpdateItem2(MenuItemModel item) async {
    await _db
        .collection(collectionName)
        .doc(item.id)
        .set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteItem(String id) async {
    await _db.collection(collectionName).doc(id).delete();
  }

  Future<void> clearAll() async {
    final snap = await _db.collection(collectionName).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  Future<void> uploadMenuItems2(List<MenuItemModel> items) async {
    if (items.isEmpty) return;
    final batch = _db.batch();
    for (final it in items) {
      final docRef = _db.collection(collectionName).doc(it.id);
      final map = it.toMap();
      map['createdAt'] = map['createdAt'] ?? FieldValue.serverTimestamp();
      batch.set(docRef, map, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// تحديث حقول معينة لمستند واحد (آمن)
  Future<void> updateFields(String id, Map<String, dynamic> fields) async {
    await _db
        .collection(collectionName)
        .doc(id)
        .set(fields, SetOptions(merge: true));
  }

  /// تنفيذ تحديث دفعات (batch) لتعديل مجموعة عناصر (مثلاً تغيير order/visible/category)
  Future<void> batchUpdateItems(List<Map<String, dynamic>> updates) async {
    if (updates.isEmpty) return;
    final batch = _db.batch();
    final col = _db.collection(collectionName);
    for (final u in updates) {
      final id = u['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final docRef = col.doc(id);
      final map = Map<String, dynamic>.from(u)..remove('id');
      batch.set(docRef, map, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
