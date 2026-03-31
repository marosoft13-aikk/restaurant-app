// صفحة العملاء (متكاملة) مع شات بين المسؤول/العميل وميزة "التواصل مع الدعم".
// ضع هذا الملف في lib/pages/customers_page.dart ثم اربط الراوت المناسب.
//
// متطلبات:
// - Firebase مُهيأ في التطبيق (Firebase.initializeApp() سابقًا).
// - توجد collection "users" (حقول مقترحة: displayName, phone, isVIP (bool), role).
// - توجد collection "orders" (كل وثيقة تحتوي على userId).
// - collection "chats" ستُنشأ تلقائيًا عند بدء المحادثات، مع subcollection "messages".
//
// توجهات:
// - التصميم باللغة العربية (RTL).
// - مسؤول (role == 'admin') يمكنه وسم/إلغاء وسم VIP وفتح محادثة مع أي مستخدم.
// - المستخدم العادي يمكنه الضغط على زر "تواصل مع الدعم" لبدء محادثة مع أحد المشرفين (أول مشرف موجود).
// - الرسائل تُخزن بـ FieldValue.serverTimestamp() لضمان ترتيب السيرفر.
//
// ملاحظة أمان: تأكد من إعداد قواعد Firestore الملائمة للسماح بالقراءة/الكتابة
// فقط للمشاركين بالمحادثة أو للمسؤول كما يتطلب تطبيقك.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAdmin = false;
  String _search = '';
  String? _currentUserId;
  Map<String, dynamic>? _currentUserProfile;
  String? _adminUid; // cached admin uid

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
    _fetchAdminUid();
  }

  Future<void> _loadCurrentUser() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    _currentUserId = me.uid;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(me.uid)
          .get();
      final data = doc.data();
      setState(() {
        _currentUserProfile = data;
        _isAdmin = data != null && (data['role'] ?? '') == 'admin';
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Load current user failed: $e');
    }
  }

  // Find any admin user (first found). Cached in _adminUid.
  Future<void> _fetchAdminUid() async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        setState(() => _adminUid = q.docs.first.id);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchAdminUid failed: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _chatIdFor(String a, String b) {
    final list = [a, b]..sort();
    return '${list[0]}_${list[1]}';
  }

  Future<void> _openChat(String otherUid, String otherName) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب تسجيل الدخول لبدء المحادثة')));
      return;
    }
    final chatId = _chatIdFor(me.uid, otherUid);
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    try {
      final chatDoc = await chatRef.get();
      if (!chatDoc.exists) {
        await chatRef.set({
          'participants': [me.uid, otherUid],
          'updatedAt': FieldValue.serverTimestamp(),
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
            myUid: me.uid,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('openChat failed: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('فشل فتح المحادثة')));
    }
  }

  Future<void> _toggleVIP(String uid, bool current) async {
    if (!_isAdmin) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'isVIP': !current}, SetOptions(merge: true));
  }

  String _bucketForCount(int c) {
    if (c >= 10) return 'عالي';
    if (c >= 3) return 'متوسط';
    return 'منخفض';
  }

  // Helper for test/dev: create a test user (visible only in debug mode or on demand)
  Future<void> _createTestUser() async {
    final usersRef = FirebaseFirestore.instance.collection('users');
    final doc = usersRef.doc();
    await doc.set({
      'displayName': 'مستخدم تجريبي ${doc.id.substring(0, 6)}',
      'phone': '010${DateTime.now().millisecondsSinceEpoch % 100000}',
      'isVIP': false,
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم إنشاء مستخدم تجريبي')));
  }

  @override
  Widget build(BuildContext context) {
    final usersStream =
        FirebaseFirestore.instance.collection('users').snapshots();
    final ordersStream =
        FirebaseFirestore.instance.collection('orders').snapshots();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('العملاء'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'الكل'),
              Tab(text: 'المميزين'),
              Tab(text: 'حسب الطلبات'),
            ],
          ),
          actions: [
            if (_isAdmin)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                    child: Text(
                  'مسؤول',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                )),
              ),
            if (kDebugMode)
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'إنشاء مستخدم تجريبي',
                onPressed: _createTestUser,
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث عن عميل بالاسم أو الهاتف...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) =>
                    setState(() => _search = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ------ Tab "الكل" ------
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: usersStream,
                    builder: (context, usersSnap) {
                      if (usersSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (usersSnap.hasError) {
                        return Center(child: Text('خطأ: ${usersSnap.error}'));
                      }
                      final usersDocs = usersSnap.data?.docs ?? [];

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: ordersStream,
                        builder: (context, ordersSnap) {
                          final ordersDocs = ordersSnap.data?.docs ?? [];
                          final Map<String, int> counts = {};
                          for (final o in ordersDocs) {
                            final uid = (o.data()['userId'] ?? '').toString();
                            if (uid.isEmpty) continue;
                            counts[uid] = (counts[uid] ?? 0) + 1;
                          }

                          final filtered = usersDocs.where((d) {
                            final data = d.data();
                            final name = (data['displayName'] ?? '')
                                .toString()
                                .toLowerCase();
                            final phone =
                                (data['phone'] ?? '').toString().toLowerCase();
                            final q = _search;
                            if (q.isEmpty) return true;
                            return name.contains(q) ||
                                phone.contains(q) ||
                                d.id.contains(q);
                          }).toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('لا يوجد عملاء'),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _createTestUser,
                                    child: const Text('إنشاء مستخدم تجريبي'),
                                  )
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final doc = filtered[idx];
                              final u = doc.data();
                              final uid = doc.id;
                              final name =
                                  (u['displayName'] ?? 'عميل').toString();
                              final phone = (u['phone'] ?? '').toString();
                              final isVIP = (u['isVIP'] ?? false) as bool;
                              final orderCount = counts[uid] ?? 0;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      isVIP ? Colors.orange : Colors.blueGrey,
                                  child: Text((name.isNotEmpty ? name[0] : '?'),
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ),
                                title: Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle:
                                    Text('الطلبات: $orderCount — هاتف: $phone'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isAdmin)
                                      IconButton(
                                        icon: Icon(
                                            isVIP
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: isVIP
                                                ? Colors.amber
                                                : Colors.grey),
                                        tooltip: isVIP
                                            ? 'إلغاء تمييز'
                                            : 'تمييز كمميز',
                                        onPressed: () => _toggleVIP(uid, isVIP),
                                      ),
                                    IconButton(
                                      icon:
                                          const Icon(Icons.chat_bubble_outline),
                                      tooltip: 'محادثة',
                                      onPressed: () async {
                                        // If current user is admin -> open chat with this user.
                                        // If current user is not admin -> open chat with admin (support).
                                        if (_isAdmin) {
                                          _openChat(uid, name);
                                        } else {
                                          if (_adminUid == null) {
                                            await _fetchAdminUid();
                                          }
                                          if (_adminUid != null) {
                                            _openChat(_adminUid!, 'الدعم');
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'لا يوجد مسؤول متاح حالياً')));
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                            title: Text(name),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text('UID: $uid'),
                                                const SizedBox(height: 6),
                                                Text('الهاتف: $phone'),
                                                const SizedBox(height: 6),
                                                Text(
                                                    'عدد الطلبات: $orderCount'),
                                                const SizedBox(height: 6),
                                                Text(
                                                    'مميز: ${isVIP ? "نعم" : "لا"}'),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('إغلاق')),
                                              if (_isAdmin)
                                                TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _openChat(uid, name);
                                                    },
                                                    child:
                                                        const Text('محادثة')),
                                            ],
                                          ));
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),

                  // ------ Tab "المميزين" ------
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('isVIP', isEqualTo: true)
                        .snapshots(),
                    builder: (context, vipSnap) {
                      if (vipSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final vipDocs = vipSnap.data?.docs ?? [];

                      if (vipDocs.isEmpty) {
                        return const Center(
                            child: Text('لا يوجد عملاء مميزين'));
                      }

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: ordersStream,
                        builder: (context, ordersSnap) {
                          final ordersDocs = ordersSnap.data?.docs ?? [];
                          final Map<String, int> counts = {};
                          for (final o in ordersDocs) {
                            final uid = (o.data()['userId'] ?? '').toString();
                            if (uid.isEmpty) continue;
                            counts[uid] = (counts[uid] ?? 0) + 1;
                          }

                          final filtered = vipDocs.where((d) {
                            final data = d.data();
                            final name = (data['displayName'] ?? '')
                                .toString()
                                .toLowerCase();
                            final phone =
                                (data['phone'] ?? '').toString().toLowerCase();
                            final q = _search;
                            if (q.isEmpty) return true;
                            return name.contains(q) ||
                                phone.contains(q) ||
                                d.id.contains(q);
                          }).toList();

                          if (filtered.isEmpty)
                            return const Center(
                                child: Text('لا يوجد عملاء مميزين'));

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final doc = filtered[idx];
                              final u = doc.data();
                              final uid = doc.id;
                              final name =
                                  (u['displayName'] ?? 'عميل').toString();
                              final phone = (u['phone'] ?? '').toString();
                              final orderCount = counts[uid] ?? 0;

                              return ListTile(
                                leading: CircleAvatar(
                                    backgroundColor: Colors.orange,
                                    child: Text(name.isNotEmpty ? name[0] : '?',
                                        style: const TextStyle(
                                            color: Colors.white))),
                                title: Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle:
                                    Text('الطلبات: $orderCount — هاتف: $phone'),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_isAdmin)
                                        IconButton(
                                            icon: const Icon(Icons.star,
                                                color: Colors.amber),
                                            tooltip: 'إلغاء وسم كمميز',
                                            onPressed: () =>
                                                _toggleVIP(uid, true)),
                                      if (_isAdmin)
                                        IconButton(
                                            icon: const Icon(
                                                Icons.chat_bubble_outline),
                                            onPressed: () =>
                                                _openChat(uid, name)),
                                    ]),
                                onTap: () =>
                                    _showCustomerDetails(uid, u, orderCount),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),

                  // ------ Tab "حسب الطلبات" ------
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: usersStream,
                    builder: (context, usersSnap) {
                      if (usersSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final usersDocs = usersSnap.data?.docs ?? [];

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: ordersStream,
                        builder: (context, ordersSnap) {
                          final ordersDocs = ordersSnap.data?.docs ?? [];
                          final Map<String, int> counts = {};
                          for (final o in ordersDocs) {
                            final uid = (o.data()['userId'] ?? '').toString();
                            if (uid.isEmpty) continue;
                            counts[uid] = (counts[uid] ?? 0) + 1;
                          }

                          final Map<
                              String,
                              List<
                                  QueryDocumentSnapshot<
                                      Map<String, dynamic>>>> buckets = {
                            'عالي': [],
                            'متوسط': [],
                            'منخفض': [],
                          };

                          for (final d in usersDocs) {
                            final uid = d.id;
                            final c = counts[uid] ?? 0;
                            final bucket = _bucketForCount(c);
                            buckets[bucket]?.add(d);
                          }

                          return ListView(
                            children: [
                              _buildBucketSection(
                                  'عالي (10+ طلبات)', buckets['عالي']!, counts),
                              _buildBucketSection('متوسط (3-9 طلبات)',
                                  buckets['متوسط']!, counts),
                              _buildBucketSection('منخفض (0-2 طلبات)',
                                  buckets['منخفض']!, counts),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: !_isAdmin
            ? FloatingActionButton.extended(
                onPressed: () async {
                  // For non-admin users, open chat with admin support.
                  final me = FirebaseAuth.instance.currentUser;
                  if (me == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('يجب تسجيل الدخول أولاً')));
                    return;
                  }
                  if (_adminUid == null) await _fetchAdminUid();
                  if (_adminUid == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('لا يوجد مسؤول متاح حالياً')));
                    return;
                  }
                  _openChat(_adminUid!, 'الدعم');
                },
                label: const Text('تواصل مع الدعم'),
                icon: const Icon(Icons.chat),
              )
            : null,
      ),
    );
  }

  Widget _buildBucketSection(
      String title,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      Map<String, int> counts) {
    if (docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('لا يوجد عملاء في هذه الفئة'),
            const SizedBox(height: 12),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          ...docs.map((d) {
            final u = d.data();
            final uid = d.id;
            final name = (u['displayName'] ?? '').toString();
            final phone = (u['phone'] ?? '').toString();
            final orderCount = counts[uid] ?? 0;
            final isVIP = (u['isVIP'] ?? false) as bool;

            return ListTile(
              leading: CircleAvatar(
                  backgroundColor: isVIP ? Colors.orange : Colors.blueGrey,
                  child: Text(name.isNotEmpty ? name[0] : '?',
                      style: const TextStyle(color: Colors.white))),
              title: Text(name.isNotEmpty ? name : 'عميل'),
              subtitle: Text('الطلبات: $orderCount — هاتف: $phone'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_isAdmin)
                  IconButton(
                      icon: Icon(isVIP ? Icons.star : Icons.star_border,
                          color: isVIP ? Colors.amber : Colors.grey),
                      onPressed: () => _toggleVIP(uid, isVIP)),
                if (_isAdmin)
                  IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () => _openChat(uid, name)),
              ]),
              onTap: () => _showCustomerDetails(uid, u, orderCount),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showCustomerDetails(
      String uid, Map<String, dynamic> data, int orderCount) {
    final name = (data['displayName'] ?? '').toString();
    final phone = (data['phone'] ?? '').toString();
    final isVIP = (data['isVIP'] ?? false) as bool;

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(name.isNotEmpty ? name : 'عميل'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('UID: $uid'),
                  const SizedBox(height: 6),
                  Text('الهاتف: $phone'),
                  const SizedBox(height: 6),
                  Text('عدد الطلبات: $orderCount'),
                  const SizedBox(height: 6),
                  Text('مميز: ${isVIP ? "نعم" : "لا"}'),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق')),
                if (_isAdmin)
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openChat(uid, name);
                      },
                      child: const Text('محادثة')),
              ],
            ));
  }
}

/// صفحة المحادثة البسيطة.
class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUid;
  final String otherName;
  final String myUid;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.otherName,
    required this.myUid,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  Future<void> _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final msgRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc();
    try {
      await msgRef.set({
        'from': widget.myUid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // update chat doc updatedAt
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .set({
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _ctrl.clear();
      Future.delayed(const Duration(milliseconds: 120), () {
        if (_scroll.hasClients)
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('sendMessage failed: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('فشل إرسال الرسالة')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('محادثة مع ${widget.otherName}'),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('createdAt')
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty)
                    return const Center(child: Text('لا توجد رسائل بعد'));
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final m = docs[i].data();
                      final from = (m['from'] ?? '').toString();
                      final text = (m['text'] ?? '').toString();
                      final ts = m['createdAt'] is Timestamp
                          ? (m['createdAt'] as Timestamp).toDate()
                          : null;
                      final isMe = from == widget.myUid;
                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.deepOrange.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(text),
                              if (ts != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.black54),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالة...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        onPressed: _sendMessage, child: const Icon(Icons.send))
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
