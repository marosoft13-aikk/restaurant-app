import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../utils/chat_utils.dart';
import 'chat_page.dart';

class ClientSupportPage extends StatefulWidget {
  const ClientSupportPage({super.key});

  @override
  State<ClientSupportPage> createState() => _ClientSupportPageState();
}

// دالة موحدة لبناء chatId (انسخها مرة واحدة واستخدمها دائماً)
String chatIdFor(String a, String b) {
  final list = [a, b]..sort();
  return '${list[0]}_${list[1]}';
}

class _ClientSupportPageState extends State<ClientSupportPage> {
  String? _adminUid;
  String _adminName = 'الدعم';
  bool _loadingAdmin = true;
  String? _adminLoadError;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _chatsDocs = [];
  final Map<String, String> _userNamesCache = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatsSub;

  bool _loadingChats = true;
  bool _listeningWithOrderBy = false;
  final int _limit = 50;

  // ثابت الأدمن الافتراضي (fallback) — يمكنك تغييره أو إزالته إذا لا تريد fallback
  static const String fallbackAdminUid = 'DsHRVxhNE5Qj4PXS83dWYDOWao13';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ar').catchError((_) {});
    _initAndSubscribe();
  }

  Future<void> _initAndSubscribe() async {
    await _fetchAdmin();
    _subscribeChatsSafely();
  }

  @override
  void dispose() {
    _chatsSub?.cancel();
    super.dispose();
  }

  // ===========================
  // جلب الأدمن: الآن نعتبر 'restaurant' و 'روسورنت' كأدوار أدمنية أيضاً
  // ===========================
  Future<void> _fetchAdmin() async {
    setState(() {
      _loadingAdmin = true;
      _adminLoadError = null;
    });

    try {
      // القيم التي نعتبرها "أدمن"
      final allowedRoles = ['admin', 'restaurant', 'روسورنت'];

      // ⚠️ ملاحظة: whereIn يدعم حتى 10 عناصر؛ هنا عدد صغير لذا آمن.
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: allowedRoles)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        final d = q.docs.first;
        _adminUid = d.id;
        _adminName = (d.data()['displayName'] ?? 'الدعم').toString();
        if (kDebugMode)
          debugPrint('ClientSupport: found admin $_adminUid ($_adminName)');
      } else {
        // لا يوجد مستخدم بالـ roles المسموح بها => اختر fallback (اختياري)
        _adminUid = fallbackAdminUid;
        _adminName = 'الدعم';
        _adminLoadError =
            'لم يتم العثور على حساب role ضمن ${allowedRoles.join(", ")} — تم استخدام fallback';
        if (kDebugMode) debugPrint('ClientSupport: no admin users found');
      }
    } catch (e) {
      _adminUid = null;
      _adminLoadError = 'فشل جلب بيانات الدعم: $e';
      if (kDebugMode) debugPrint('fetchAdmin failed: $e');
    } finally {
      if (mounted) setState(() => _loadingAdmin = false);
    }
  }

  void _subscribeChatsSafely() {
    _chatsSub?.cancel();
    setState(() {
      _loadingChats = true;
      _chatsDocs = [];
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        // user not logged in; no subscription
        setState(() {
          _loadingChats = false;
        });
        return;
      }

      final q = FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: uid)
          .orderBy('updatedAt', descending: true)
          .limit(_limit);

      _chatsSub = q.snapshots().listen((snap) {
        _onChatsSnapshot(snap);
        _listeningWithOrderBy = true;
      }, onError: (err) {
        if (kDebugMode) debugPrint('chats stream error (orderBy): $err');
        _subscribeChatsFallback();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('subscribe chats (orderBy) failed: $e');
      _subscribeChatsFallback();
    }
  }

  void _subscribeChatsFallback() {
    _chatsSub?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      setState(() {
        _loadingChats = false;
      });
      return;
    }
    final q = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: uid)
        .limit(_limit);
    _chatsSub = q.snapshots().listen((snap) {
      _onChatsSnapshot(snap);
      _listeningWithOrderBy = false;
    }, onError: (err) {
      if (kDebugMode) debugPrint('chats stream fallback error: $err');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('خطأ بجلب المحادثات')));
      }
    });
  }

  void _onChatsSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final docs = snap.docs;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final Set<String> otherUids = {};
    for (final d in docs) {
      final participants =
          List<String>.from((d.data()['participants'] ?? []) as List<dynamic>);
      final other = participants.firstWhere((u) => u != myUid,
          orElse: () => participants.isNotEmpty ? participants.first : '');
      if (other.isNotEmpty && !_userNamesCache.containsKey(other))
        otherUids.add(other);
    }
    if (otherUids.isNotEmpty) _fetchNamesBatch(otherUids.toList());

    if (!_listeningWithOrderBy) {
      docs.sort((a, b) {
        final aAt = a.data()['updatedAt'];
        final bAt = b.data()['updatedAt'];
        DateTime da = aAt is Timestamp
            ? aAt.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        DateTime db = bAt is Timestamp
            ? bAt.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    }

    if (mounted) {
      setState(() {
        _chatsDocs = docs;
        _loadingChats = false;
      });
    }
  }

  Future<void> _fetchNamesBatch(List<String> uids) async {
    const int chunkSize = 10;
    for (var i = 0; i < uids.length; i += chunkSize) {
      final chunk = uids.skip(i).take(chunkSize).toList();
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          _userNamesCache[d.id] = (d.data()['displayName'] ?? d.id).toString();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('batch user fetch failed: $e');
      }
    }
    if (mounted) setState(() {});
  }

  // Enhanced: ensure admin exists then create/get chat and open it.
  Future<void> _ensureAndOpenChatWithAdmin() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول')));
      }
      return;
    }

    // إذا _adminUid غير محمّل، حاول جلبه
    if (_adminUid == null) {
      setState(() => _loadingAdmin = true);
      await _fetchAdmin();
      setState(() => _loadingAdmin = false);
    }

    if (_adminUid == null) {
      final err = _adminLoadError ?? 'لا يوجد مسؤول متاح حالياً';
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    try {
      final chatId = chatIdFor(me.uid, _adminUid!);
      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc(chatId);
      final snap = await chatRef.get();
      if (!snap.exists) {
        final ids = [me.uid, _adminUid!]..sort();
        await chatRef.set({
          'participants': ids,
          'lastMessage': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            chatId: chatId,
            otherUid: _adminUid!,
            otherName: _adminName,
            myUid: me.uid,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ensureAndOpenChatWithAdmin failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر فتح المحادثة')));
      }
    }
  }

  // دالة عامة لضمان وجود chat وفتحه بين myUid و otherUid
  Future<void> _ensureChatAndOpen({
    required String myUid,
    required String otherUid,
    required String otherName,
  }) async {
    try {
      final chatId = chatIdFor(myUid, otherUid);
      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();
      if (!chatDoc.exists) {
        final ids = [myUid, otherUid]..sort();
        await chatRef.set({
          'participants': ids,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
        });
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            chatId: chatId,
            otherUid: otherUid,
            otherName: otherName,
            myUid: myUid,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ensureChatAndOpen failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر فتح المحادثة')));
      }
    }
  }

  // أداة تشخيصية — تبقى كما هي
  Future<void> _runDiagnostics() async {
    if (kDebugMode) debugPrint('--- DIAGNOSTICS START ---');
    final me = FirebaseAuth.instance.currentUser;
    debugPrint('DIAG: currentUser = ${me?.uid}  email=${me?.email}');
    debugPrint(
        'DIAG: adminUid = $_adminUid  adminName = $_adminName  adminLoadError = $_adminLoadError');

    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تسجيل الدخول قبل التشخيص')));
      return;
    }

    // 1) تأكد من صلاحية قراءة users/admin
    try {
      if (_adminUid != null && _adminUid!.isNotEmpty) {
        final adminSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(_adminUid!)
            .get();
        debugPrint(
            'DIAG: admin doc exists=${adminSnap.exists} data=${adminSnap.data()}');
      } else {
        debugPrint('DIAG: adminUid is null or empty');
      }
    } catch (e) {
      debugPrint('DIAG: failed reading admin doc: $e');
    }

    // 2) جرّب إنشاء أو إرجاع chat
    try {
      if (_adminUid != null) {
        final chatId = chatIdFor(me.uid, _adminUid!);
        debugPrint('DIAG: test chatId=$chatId');

        // اطبع آخر الرسائل (debugDumpChat) إن وُجدت الدالة
        try {
          await debugDumpChat(chatId, limit: 50);
        } catch (_) {}
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Diagnostics done — check console. chatId=$chatId')));
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('لا يوجد admin لفتح شات التجربة')));
      }
    } catch (e) {
      debugPrint('DIAG: getOrCreateChat/debugDumpChat failed: $e');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Diagnostics failed: $e')));
    }
    if (kDebugMode) debugPrint('--- DIAGNOSTICS END ---');
  }

  String _formatDateTime(dynamic at) {
    if (at == null) return '';
    DateTime dt;
    if (at is Timestamp)
      dt = at.toDate();
    else if (at is DateTime)
      dt = at;
    else
      return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat.Hm('ar').format(dt);
    if (diff.inDays == 1) return 'أمس ${DateFormat.Hm('ar').format(dt)}';
    return DateFormat('dd/MM/yyyy HH:mm', 'ar').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('الدعم')),
          body: const Center(child: Text('يرجى تسجيل الدخول لعرض المحادثات')),
        ),
      );
    }
    final myUid = me.uid;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الدعم والمحادثات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'تشخيص المحادثات (Debug)',
              onPressed: _runDiagnostics,
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: FloatingActionButton.extended(
            icon: _loadingAdmin
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.chat),
            label: Text(_loadingAdmin ? 'جارٍ التحضير...' : 'تواصل مع الدعم'),
            onPressed: _loadingAdmin ? null : _ensureAndOpenChatWithAdmin,
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await _fetchAdmin();
            _subscribeChatsSafely();
            setState(() {});
          },
          child: SafeArea(
            child: _loadingChats
                ? const Center(child: CircularProgressIndicator())
                : _chatsDocs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('لا توجد محادثات بعد'),
                            if (_adminLoadError != null) ...[
                              const SizedBox(height: 8),
                              Text(_adminLoadError!,
                                  style: const TextStyle(color: Colors.red)),
                            ]
                          ]),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 120,
                            top: 8),
                        itemCount: _chatsDocs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final d = _chatsDocs[idx];
                          final data = d.data();
                          final participants = List<String>.from(
                              (data['participants'] ?? []) as List<dynamic>);
                          final otherUid = participants.firstWhere(
                              (u) => u != myUid,
                              orElse: () => participants.isNotEmpty
                                  ? participants.first
                                  : '');
                          final updated = data['updatedAt'];
                          final updatedLabel = (updated is Timestamp)
                              ? _formatDateTime(updated.toDate())
                              : '';
                          final preview =
                              (data['lastMessage'] ?? '').toString();
                          final typingMap = (data['typing'] is Map)
                              ? Map<String, dynamic>.from(data['typing'] as Map)
                              : null;
                          final otherName = _userNamesCache[otherUid] ??
                              (otherUid == _adminUid ? 'الدعم' : 'مستخدم');
                          final isOtherTyping = typingMap != null &&
                              (typingMap[otherUid] == true);

                          return InkWell(
                            onTap: () async {
                              await _ensureChatAndOpen(
                                  myUid: myUid,
                                  otherUid: otherUid,
                                  otherName: otherName);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                      radius: 20,
                                      child: Text(
                                          otherName.isNotEmpty
                                              ? otherName[0]
                                              : '?',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(otherName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          DefaultTextStyle(
                                              style: const TextStyle(
                                                  color: Colors.black54,
                                                  fontSize: 13),
                                              child: isOtherTyping
                                                  ? const Text('يكتب...',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          color: Colors.green))
                                                  : Text(preview,
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                        ]),
                                  ),
                                  const SizedBox(width: 12),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 110),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Flexible(
                                              child: Text(updatedLabel,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black54))),
                                          const SizedBox(height: 6),
                                          SizedBox(
                                              width: 36,
                                              height: 36,
                                              child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  icon: const Icon(
                                                      Icons.open_in_new,
                                                      size: 20),
                                                  onPressed: () async {
                                                    await _ensureChatAndOpen(
                                                        myUid: myUid,
                                                        otherUid: otherUid,
                                                        otherName: otherName);
                                                  }))
                                        ]),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ),
    );
  }
}
