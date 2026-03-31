import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/chat_utils.dart';
import 'chat_page.dart';

class AdminChatsPage extends StatefulWidget {
  const AdminChatsPage({super.key});

  @override
  State<AdminChatsPage> createState() => _AdminChatsPageState();
}

class _AdminChatsPageState extends State<AdminChatsPage> {
  List<String> _adminUids = [];
  bool _loading = true;
  String? _error;

  // Cache for user display names to avoid many single-document reads
  final Map<String, String> _userNameCache = {};

  // debug: show raw docs for diagnosis
  bool _showRawDocs = false;

  // whether current user is confirmed admin
  bool _isCurrentUserAdmin = false;

  // diagnostic: the raw role value read from Firestore for the current user
  String _detectedRole = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _loadAdminUids();
    await _verifyCurrentUserIsAdmin();
    if (mounted) setState(() => _loading = false);
  }

  // Helper to normalize role strings and check admin-like roles
  bool _isAdminRoleString(String? rawRole) {
    if (rawRole == null) return false;
    final role = rawRole.toLowerCase().trim();
    return role == 'admin' || role == 'restaurant' || role == 'روسورنت';
  }

  // تحقق أوسع مع debug info — يستعمل fallback بواسطة _adminUids أيضاً
  Future<void> _verifyCurrentUserIsAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _isCurrentUserAdmin = false;
      _detectedRole = 'no-user';
      if (kDebugMode) debugPrint('verifyAdmin: no signed-in user');
      return;
    }
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final rawRole = (doc.data()?['role'] ?? '').toString();
      _detectedRole = rawRole;
      // قبول حالات متعددة: "admin" أو "restaurant" أو "روسورنت" أو uid ضمن قائم�� _adminUids كـ fallback
      if (_isAdminRoleString(rawRole) || _adminUids.contains(uid)) {
        _isCurrentUserAdmin = true;
      } else {
        _isCurrentUserAdmin = false;
      }
      if (kDebugMode) {
        debugPrint(
            'verifyAdmin: uid=$uid role="$rawRole" isAdmin=$_isCurrentUserAdmin');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('verify admin failed: $e');
      _isCurrentUserAdmin = false;
      _detectedRole = 'error';
    }
  }

  Future<void> _loadAdminUids() async {
    // load all admin uids (for debugging / fallback)
    try {
      // نعتبر هذه القيم كأدوار أدمن
      final allowedRoles = ['admin', 'restaurant', 'روسورنت'];

      // استخدم whereIn لقراءة كل المستخدمين الذين دورهم ضمن allowedRoles
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: allowedRoles)
          .get();

      final uids = <String>{};
      for (final d in q.docs) uids.add(d.id);

      final list = uids.toList();
      if (kDebugMode) debugPrint('AdminChatsPage: adminUids=$list');

      if (mounted) {
        setState(() {
          _adminUids = list;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AdminChatsPage: load admin uids failed: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatsStream() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null && myUid.isNotEmpty && _isCurrentUserAdmin) {
      if (kDebugMode)
        debugPrint('AdminChatsPage: subscribing to chats for uid=$myUid');
      // admin sees chats where he/she is participant, ordered by updatedAt
      return FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: myUid)
          .orderBy('updatedAt', descending: true)
          .snapshots();
    }

    // If not signed in as admin: return an empty stream (no accidental results)
    if (kDebugMode)
      debugPrint(
          'AdminChatsPage: not signed-in admin; returning empty chats stream');
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: '__NO_SUCH_UID__')
        .snapshots();
  }

  Future<void> _ensureUserName(String uid) async {
    if (uid.isEmpty) return;
    if (_userNameCache.containsKey(uid)) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final name = (doc.data()?['displayName'] ?? '').toString();
      _userNameCache[uid] = name.isNotEmpty ? name : uid;
      if (mounted) setState(() {}); // refresh UI to show cached name
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to fetch user $uid name: $e');
      _userNameCache[uid] = uid;
      if (mounted) setState(() {});
    }
  }

  // فتح/بدء محادثة حتمية مع user آخر (نستخدم chatIdFor لضمان نفس الـ id للطرفين)
  Future<void> _openChat(String otherUid, String otherName) async {
    final currentAdminUid = FirebaseAuth.instance.currentUser?.uid ??
        (_adminUids.isNotEmpty ? _adminUids.first : '');
    if (currentAdminUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('لا يوجد معرف مسؤول صالح لبدء المحادثة')));
      }
      return;
    }

    final chatId = chatIdFor(currentAdminUid, otherUid);
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    try {
      await chatRef.set({
        'participants': [currentAdminUid, otherUid],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('openChat: ensure chat doc failed: $e');
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          chatId: chatId,
          otherUid: otherUid,
          otherName: otherName,
          myUid: currentAdminUid,
        ),
      ),
    );
  }

  // فتح المحادثة اعتمادًا على doc من الاستريم — نحسب chatId حتمي للتوافق
  Future<void> _openChatFromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> d) async {
    final data = d.data();
    final participants =
        List<String>.from((data['participants'] ?? []) as List<dynamic>);
    if (participants.isEmpty) return;

    final currentAdminUid = FirebaseAuth.instance.currentUser?.uid ??
        (_adminUids.isNotEmpty ? _adminUids.first : '');

    String otherUid = '';
    if (currentAdminUid.isNotEmpty) {
      otherUid = participants.firstWhere((u) => u != currentAdminUid,
          orElse: () => participants.first);
    } else {
      otherUid = participants.first;
    }

    if (otherUid.isNotEmpty && !_userNameCache.containsKey(otherUid)) {
      await _ensureUserName(otherUid);
    }
    final otherName =
        _userNameCache[otherUid] ?? (otherUid.isNotEmpty ? otherUid : 'مستخدم');

    // Use canonical chatId when admin uid is available to avoid mismatches
    final chatId = (currentAdminUid.isNotEmpty)
        ? chatIdFor(currentAdminUid, otherUid)
        : d.id;

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    try {
      await chatRef.set({
        'participants': [currentAdminUid, otherUid],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('openChatFromDoc: ensure chat doc failed: $e');
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          chatId: chatId,
          otherUid: otherUid,
          otherName: otherName,
          myUid: currentAdminUid,
        ),
      ),
    );
  }

  // manual start chat (debug) - إدخال UID واختبار
  Future<void> _manualStartDialog() async {
    final t = TextEditingController();
    await showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('بدء محادثة يدويًا'),
              content: TextField(
                controller: t,
                decoration: const InputDecoration(
                    hintText: 'أدخل معرف المستخدم الآخر (uid)'),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء')),
                TextButton(
                    onPressed: () {
                      final val = t.text.trim();
                      Navigator.pop(context);
                      if (val.isNotEmpty) _startManualChat(val);
                    },
                    child: const Text('افتح المحادثة')),
              ],
            ));
  }

  Future<void> _startManualChat(String otherUid) async {
    // fetch display name if possible
    String otherName = otherUid;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUid)
          .get();
      otherName = (doc.data()?['displayName'] ?? otherUid).toString();
    } catch (_) {}
    await _openChat(otherUid, otherName);
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    final myUid = me?.uid ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('محادثات الدعم (الأدمن)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _init,
              tooltip: 'تحديث قائمة المسؤولين / حالة الحساب',
            ),
            IconButton(
              icon:
                  Icon(_showRawDocs ? Icons.visibility_off : Icons.bug_report),
              onPressed: () => setState(() => _showRawDocs = !_showRawDocs),
              tooltip: 'عرض بيانات التشخيص الخام',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _manualStartDialog,
              tooltip: 'بدء محادثة يدويًا عبر UID',
            ),
          ],
        ),
        body: Builder(builder: (context) {
          if (_loading) return const Center(child: CircularProgressIndicator());
          if (_error != null) return Center(child: Text('خطأ: $_error'));

          // If current user is not an admin, instruct to sign-in as admin.
          if (!_isCurrentUserAdmin) {
            final currentUid =
                FirebaseAuth.instance.currentUser?.uid ?? '(not signed)';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('يجب أن تكون مسجلاً كمسؤول لعرض هذه الصفحة.'),
                  const SizedBox(height: 8),
                  Text('معرفك: $currentUid'),
                  const SizedBox(height: 4),
                  Text(
                      'الدور المكتشف في الـ Firestore: ${_detectedRole.isNotEmpty ? _detectedRole : "(لم يتم الفحص)"}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                      onPressed: _init,
                      child: const Text('إعادة المحاولة / تحديث')),
                ]),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _chatsStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snap.hasError) {
                if (kDebugMode) debugPrint('chats stream error: ${snap.error}');
                return Center(child: Text('خطأ: ${snap.error}'));
              }

              final docs =
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                      snap.data?.docs ?? []);
              if (kDebugMode) {
                debugPrint('AdminChatsPage: snapshot count=${docs.length}');
                for (final d in docs) {
                  debugPrint(
                      '  docId=${d.id} participants=${d.data()['participants']} lastMessage=${d.data()['lastMessage']}');
                }
              }

              if (docs.isEmpty)
                return const Center(child: Text('لا توجد محادثات بعد'));

              // Already ordered by updatedAt from query; but guard just in case
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

              return ListView.separated(
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: docs.length,
                itemBuilder: (context, idx) {
                  final d = docs[idx];
                  final data = d.data();
                  final participants = List<String>.from(
                      (data['participants'] ?? []) as List<dynamic>);

                  // current admin uid (should be signed in)
                  final currentAdminUid = myUid.isNotEmpty
                      ? myUid
                      : (_adminUids.isNotEmpty ? _adminUids.first : '');

                  // اختر الطرف الآخر (غير الإدمن الحالي)
                  String otherUid = '';
                  if (currentAdminUid.isNotEmpty) {
                    otherUid = participants.firstWhere(
                        (u) => u != currentAdminUid,
                        orElse: () =>
                            participants.isNotEmpty ? participants.first : '');
                  } else {
                    otherUid =
                        participants.isNotEmpty ? participants.first : '';
                  }

                  if (otherUid.isNotEmpty &&
                      !_userNameCache.containsKey(otherUid)) {
                    _ensureUserName(otherUid);
                  }

                  final otherName = _userNameCache[otherUid] ??
                      (otherUid.isNotEmpty ? otherUid : 'مستخدم');
                  final chatLastPreview =
                      (data['lastMessage'] ?? '').toString();
                  final updated = data['updatedAt'];
                  String updatedLabel = '';
                  if (updated is Timestamp) {
                    final dt = updated.toDate();
                    updatedLabel =
                        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_showRawDocs)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Text(
                              'RAW: id=${d.id} participants=${participants.join(", ")}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.blueGrey)),
                        ),
                      InkWell(
                        onTap: otherUid.isNotEmpty
                            ? () => _openChatFromDoc(d)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 10.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                child: Text(
                                  otherName.isNotEmpty
                                      ? otherName.characters.first
                                      : '?',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                        otherName.isNotEmpty
                                            ? otherName
                                            : 'مستخدم',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text(chatLastPreview,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: Colors.grey.shade700)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                    maxWidth: 110, minWidth: 60),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
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
                                        onPressed: otherUid.isNotEmpty
                                            ? () => _openChatFromDoc(d)
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        }),
      ),
    );
  }
}
