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

class ClientChatsPage extends StatefulWidget {
  const ClientChatsPage({super.key});

  @override
  State<ClientChatsPage> createState() => _ClientChatsPageState();
}

class _ClientChatsPageState extends State<ClientChatsPage> {
  String? _adminUid;
  String _adminName = 'الدعم';
  bool _loadingAdmin = true;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _chatsDocs = [];
  final Map<String, String> _userNamesCache = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatsSub;

  bool _loadingChats = true;
  bool _listeningWithOrderBy = false;
  final int _limit = 50;

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

  Future<void> _fetchAdmin() async {
    setState(() => _loadingAdmin = true);
    try {
      var q = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();
      if (q.docs.isEmpty) {
        q = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'روسورنت')
            .limit(1)
            .get();
      }
      if (q.docs.isNotEmpty) {
        final d = q.docs.first;
        _adminUid = d.id;
        _adminName = (d.data()['displayName'] ?? 'الدعم').toString();
      } else {
        final any =
            await FirebaseFirestore.instance.collection('users').limit(1).get();
        if (any.docs.isNotEmpty) {
          final d = any.docs.first;
          _adminUid = d.id;
          _adminName = (d.data()['displayName'] ?? 'الدعم').toString();
        } else {
          _adminUid = null;
          _adminName = 'الدعم';
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchAdmin failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر جلب بيانات الدعم: $e')));
      }
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

  Future<void> _ensureAndOpenChatWithAdmin() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول')));
      return;
    }
    if (_adminUid == null) {
      await _fetchAdmin();
      if (_adminUid == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يوجد مسؤول متاح حالياً')));
        return;
      }
    }

    try {
      final chatId = await getOrCreateChat(me.uid, _adminUid!);
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatPage(
                    chatId: chatId,
                    otherUid: _adminUid!,
                    otherName: _adminName,
                    myUid: me.uid,
                  )));
    } catch (e) {
      if (kDebugMode) debugPrint('ensureAndOpenChatWithAdmin failed: $e');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح المحادثة، حاول لاحقاً')));
    }
  }

  Future<void> _ensureChatAndOpen({
    required String myUid,
    required String otherUid,
    required String otherName,
  }) async {
    try {
      final chatId = await getOrCreateChat(myUid, otherUid);
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatPage(
                    chatId: chatId,
                    otherUid: otherUid,
                    otherName: otherName,
                    myUid: myUid,
                  )));
    } catch (e) {
      if (kDebugMode) debugPrint('ensureChatAndOpen failed: $e');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر فتح المحادثة')));
    }
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
        appBar: AppBar(title: const Text('الدعم والمحادثات')),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: FloatingActionButton.extended(
            icon: const Icon(Icons.chat),
            label: const Text('تواصل مع الدعم'),
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
                    ? const Center(child: Text('لا توجد محادثات بعد'))
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
                                otherName: otherName,
                              );
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
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          otherName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
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
                                              : Text(
                                                  preview,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                        ),
                                      ],
                                    ),
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
                                          child: Text(
                                            updatedLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.open_in_new,
                                                size: 20),
                                            onPressed: () async {
                                              await _ensureChatAndOpen(
                                                myUid: myUid,
                                                otherUid: otherUid,
                                                otherName: otherName,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
