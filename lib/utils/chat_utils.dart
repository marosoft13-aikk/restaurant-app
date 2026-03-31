// utils/chat_utils.dart
// وظائف مساعدة للمحادثات: توليد chatId، إنشاء المستند إن لم يكن موجودًا، وأدوات تشخيص.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// يولد chatId حتمي عن طريق ترتيب UIDs أبجديًا.
String chatIdFor(String a, String b) {
  final aNorm = a.trim();
  final bNorm = b.trim();
  final list = [aNorm, bNorm]..sort();
  return '${list[0]}_${list[1]}';
}

/// يتأكد من وجود مستند chat مع الـ chatId الحتمي.
/// إن لم يوجد ينشئه داخل transaction لضمان الاتساق.
/// يعيد chatId المستخدم.
Future<String> getOrCreateChat(String uidA, String uidB) async {
  final chatId = chatIdFor(uidA, uidB);
  final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

  try {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(chatRef);
      final partsSet = <String>{uidA.trim(), uidB.trim()};

      if (!snap.exists) {
        // إنشاء الوثيقة إن لم تكن موجودة
        tx.set(
          chatRef,
          {
            'participants': partsSet.toList(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastMessage': '',
          },
          SetOptions(merge: true),
        );
        if (kDebugMode) debugPrint('getOrCreateChat: created chat $chatId');
      } else {
        // تأكد من وجود participants ومزامنتها إن لزم
        final data = snap.data() ?? {};
        final existingParts = (data['participants'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];
        final existingSet = existingParts.toSet();

        // إن لم تتطابق المجموعة، حدث الحقل
        if (!setEquals(existingSet, partsSet)) {
          tx.update(chatRef, {
            'participants': partsSet.toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (kDebugMode)
            debugPrint('getOrCreateChat: updated participants for $chatId');
        } else {
          // فقط حدِّث updatedAt لضمان ترتيب القوائم
          tx.update(chatRef, {'updatedAt': FieldValue.serverTimestamp()});
        }
      }
    });
  } on FirebaseException catch (fe) {
    if (kDebugMode)
      debugPrint('getOrCreateChat FirebaseException: ${fe.code} ${fe.message}');
    rethrow;
  } catch (e) {
    if (kDebugMode) debugPrint('getOrCreateChat failed: $e');
    rethrow;
  }

  return chatId;
}

/// دالة تشخيصية لعرض آخر الرسائل في محادثة (مفيدة أثناء التطوير).
Future<void> debugDumpChat(String chatId, {int limit = 50}) async {
  try {
    final msgsSnap = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    debugPrint('DEBUG dump chat=$chatId count=${msgsSnap.docs.length}');
    for (final d in msgsSnap.docs) {
      debugPrint('  ${d.id} -> ${d.data()}');
    }
  } on FirebaseException catch (fe) {
    if (kDebugMode)
      debugPrint('debugDumpChat FirebaseException: ${fe.code} ${fe.message}');
    rethrow;
  } catch (e) {
    if (kDebugMode) debugPrint('debugDumpChat failed: $e');
    rethrow;
  }
}
