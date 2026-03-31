import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'chat_page.dart';
import 'admin_chats_page.dart';

class AdminCustomersPage extends StatefulWidget {
  const AdminCustomersPage({super.key});

  @override
  State<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends State<AdminCustomersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';
  String? _currentAdminUid;
  Timer? _debounce;
  bool _checkingRole = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _ensureAdmin();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _search = v.trim().toLowerCase();
      });
    });
  }

  Future<void> _ensureAdmin() async {
    setState(() {
      _checkingRole = true;
      _isAdmin = false;
    });
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      if (mounted) {
        setState(() {
          _checkingRole = false;
          _isAdmin = false;
          _currentAdminUid = null;
        });
      }
      return;
    }
    _currentAdminUid = me.uid;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(me.uid)
          .get();
      final roleRaw = doc.data()?['role'];
      final role = roleRaw?.toString() ?? '';

      if (kDebugMode) {
        debugPrint('ensureAdmin: uid=${me.uid} role="$role"');
      }

      // تحقق فعلي من الحقل role
      final isAdminRole = role == 'admin' || role == 'روسورنت';

      if (mounted) {
        setState(() {
          _isAdmin = isAdminRole;
          _checkingRole = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ensureAdmin error: $e');
      if (mounted) setState(() => _checkingRole = false);
    }
  }

  String chatIdFor(String a, String b) {
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
    final chatId = chatIdFor(me.uid, otherUid);
    if (kDebugMode) {
      debugPrint(
          'AdminCustomersPage: OpenChat chatId=$chatId me=${me.uid} other=$otherUid');
    }
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    // اضمن participants كقائمة صريحة حتى يعمل arrayContains على كلا الطرفين
    try {
      await chatRef.set({
        'participants': [me.uid, otherUid],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('ensure chat doc failed: $e');
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
            chatId: chatId,
            otherUid: otherUid,
            otherName: otherName,
            myUid: me.uid),
      ),
    );
  }

  Future<void> _toggleVIP(String uid, bool current) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('${current ? 'إزالة' : 'إضافة'} تمييز VIP للعميل؟'),
            content: const Text('هل أنت متأكد من تغيير حالة العميل؟'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('موافق')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'isVIP': !current}, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('تم ${!current ? 'إضافة' : 'إزالة'} تمييز VIP بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  String _bucketForCount(int c) {
    if (c >= 10) return 'عالي';
    if (c >= 3) return 'متوسط';
    return 'منخفض';
  }

  Widget _emptyState(String text, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.grey.shade600)),
        ]),
      ),
    );
  }

  // New: use a Row-based layout to control overflow better than ListTile.
  Widget _buildCustomerTile({
    required String uid,
    required String name,
    required String phone,
    required bool isVIP,
    required int orderCount,
  }) {
    final color = isVIP ? Colors.orange.shade700 : Colors.blueGrey;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16))),
              builder: (_) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Wrap(children: [
                        ListTile(
                          leading: CircleAvatar(
                              backgroundColor: color,
                              child: Text(name.isNotEmpty ? name[0] : '?',
                                  style: const TextStyle(color: Colors.white))),
                          title:
                              Text(name, style: const TextStyle(fontSize: 18)),
                          subtitle: Text('UID: $uid'),
                        ),
                        const Divider(),
                        ListTile(
                            leading: const Icon(Icons.phone),
                            title: Text(
                                'الهاتف: ${phone.isNotEmpty ? phone : 'غير متوفر'}')),
                        ListTile(
                            leading: const Icon(Icons.shopping_cart),
                            title: Text('عدد الطلبات: $orderCount')),
                        const SizedBox(height: 6),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('إغلاق')),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _openChat(uid, name);
                                  },
                                  icon: const Icon(Icons.chat),
                                  label: const Text('محادثة')),
                            ])
                      ]),
                    ),
                  ),
                );
              });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: color,
                child: Text(name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
              ),
              const SizedBox(width: 12),
              // Main column (title + subtitle) — expands
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title (name)
                    Text(
                      name.isNotEmpty ? name : 'عميل',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    // Phone + chips; use Wrap so chips wrap to next line instead of causing overflow
                    DefaultTextStyle(
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            phone.isNotEmpty
                                ? 'هاتف: $phone'
                                : 'هاتف غير متوفر',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Chip(
                                backgroundColor: Colors.grey.shade100,
                                label: Text('الطلبات: $orderCount'),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              if (isVIP)
                                Chip(
                                  avatar: const Icon(Icons.star,
                                      color: Colors.amber, size: 18),
                                  label: const Text('مميز'),
                                  backgroundColor: Colors.orange.shade50,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Trailing actions (chat / vip) — constrained so they don't push content
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, maxWidth: 84),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(isVIP ? Icons.star : Icons.star_border,
                            color: isVIP ? Colors.amber : Colors.grey),
                        onPressed: () => _toggleVIP(uid, isVIP),
                        tooltip: isVIP ? 'إزالة ميزة VIP' : 'تمييز كـ VIP',
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      height: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.chat_bubble_outline),
                        onPressed: () => _openChat(uid, name),
                        tooltip: 'محادثة',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Streams
    final usersStream =
        FirebaseFirestore.instance.collection('users').snapshots();
    final ordersStream =
        FirebaseFirestore.instance.collection('orders').snapshots();

    // Add an AnimatedPadding that reacts to keyboard (viewInsets) to avoid overflow.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('لوحة المسؤول — إدارة العملاء'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'الكل'),
              Tab(text: 'المميزين'),
              Tab(text: 'حسب الطلبات'),
            ],
          ),
          actions: [
            IconButton(
                tooltip: 'محادثات الإدارة',
                icon: const Icon(Icons.forum_outlined),
                onPressed: () {
                  final me = FirebaseAuth.instance.currentUser;
                  if (me == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يجب تسجيل الدخول')));
                    return;
                  }
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminChatsPage()));
                }),
            IconButton(
                tooltip: 'تحديث',
                icon: const Icon(Icons.refresh),
                onPressed: _ensureAdmin),
            if (_checkingRole)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))),
              )
          ],
        ),
        floatingActionButton: !_isAdmin
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.info_outline),
                label: const Text('حالة مسؤول'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('يجب أن يكون حسابك مسؤولاً لرؤية كل الميزات')));
                },
              )
            : null,
        body: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: Column(
              children: [
                // Search field (fixed height, won't expand)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  child: SizedBox(
                    height: 52,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'ابحث عن عميل بالاسم أو الهاتف أو UID...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _onSearchChanged('');
                                  setState(() => _search = '');
                                })
                            : null,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                ),

                // Main content: TabBarView must be inside Expanded to avoid overflow
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: All users
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: usersStream,
                        builder: (context, usersSnap) {
                          if (usersSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final usersDocs = usersSnap.data?.docs ?? [];
                          if (usersDocs.isEmpty)
                            return _emptyState(
                                'لا يوجد عملاء', Icons.people_outline);

                          return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                            stream: ordersStream,
                            builder: (context, ordersSnap) {
                              final ordersDocs = ordersSnap.data?.docs ?? [];
                              final Map<String, int> counts = {};
                              for (final o in ordersDocs) {
                                final uid =
                                    (o.data()['userId'] ?? '').toString();
                                if (uid.isEmpty) continue;
                                counts[uid] = (counts[uid] ?? 0) + 1;
                              }
                              final filtered = usersDocs.where((d) {
                                final data = d.data();
                                final name = (data['displayName'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final phone = (data['phone'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final q = _search;
                                if (q.isEmpty) return true;
                                return name.contains(q) ||
                                    phone.contains(q) ||
                                    d.id.contains(q);
                              }).toList();
                              if (filtered.isEmpty)
                                return _emptyState('لا يوجد عملاء لهذه النتيجة',
                                    Icons.search_off);

                              return RefreshIndicator(
                                onRefresh: () async {
                                  await _ensureAdmin();
                                  setState(() {});
                                },
                                // Primary list view: occupies remaining space and scrolls naturally.
                                child: ListView.builder(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, idx) {
                                    final doc = filtered[idx];
                                    final u = doc.data();
                                    final uid = doc.id;
                                    final name =
                                        (u['displayName'] ?? 'عميل').toString();
                                    final phone = (u['phone'] ?? '').toString();
                                    final isVIP = (u['isVIP'] ?? false) as bool;
                                    final orderCount = counts[uid] ?? 0;
                                    return _buildCustomerTile(
                                        uid: uid,
                                        name: name,
                                        phone: phone,
                                        isVIP: isVIP,
                                        orderCount: orderCount);
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // Tab 2: VIPs
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('isVIP', isEqualTo: true)
                            .snapshots(),
                        builder: (context, vipSnap) {
                          if (vipSnap.connectionState ==
                              ConnectionState.waiting)
                            return const Center(
                                child: CircularProgressIndicator());
                          final vipDocs = vipSnap.data?.docs ?? [];
                          if (vipDocs.isEmpty)
                            return _emptyState(
                                'لا يوجد عملاء مميزين', Icons.star_outline);

                          return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                            stream: ordersStream,
                            builder: (context, ordersSnap) {
                              final ordersDocs = ordersSnap.data?.docs ?? [];
                              final Map<String, int> counts = {};
                              for (final o in ordersDocs) {
                                final uid =
                                    (o.data()['userId'] ?? '').toString();
                                if (uid.isEmpty) continue;
                                counts[uid] = (counts[uid] ?? 0) + 1;
                              }
                              final filtered = vipDocs.where((d) {
                                final data = d.data();
                                final name = (data['displayName'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final phone = (data['phone'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final q = _search;
                                if (q.isEmpty) return true;
                                return name.contains(q) ||
                                    phone.contains(q) ||
                                    d.id.contains(q);
                              }).toList();
                              if (filtered.isEmpty)
                                return _emptyState(
                                    'لا يوجد عملاء مميزين لهذه النتيجة',
                                    Icons.star_half);

                              return ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                itemCount: filtered.length,
                                itemBuilder: (context, idx) {
                                  final doc = filtered[idx];
                                  final u = doc.data();
                                  final uid = doc.id;
                                  final name =
                                      (u['displayName'] ?? 'عميل').toString();
                                  final phone = (u['phone'] ?? '').toString();
                                  final orderCount = counts[uid] ?? 0;
                                  return _buildCustomerTile(
                                      uid: uid,
                                      name: name,
                                      phone: phone,
                                      isVIP: true,
                                      orderCount: orderCount);
                                },
                              );
                            },
                          );
                        },
                      ),

                      // Tab 3: By orders (buckets)
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: usersStream,
                        builder: (context, usersSnap) {
                          if (usersSnap.connectionState ==
                              ConnectionState.waiting)
                            return const Center(
                                child: CircularProgressIndicator());
                          final usersDocs = usersSnap.data?.docs ?? [];
                          if (usersDocs.isEmpty)
                            return _emptyState(
                                'لا يوجد عملاء', Icons.people_outline);

                          return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                            stream: ordersStream,
                            builder: (context, ordersSnap) {
                              final ordersDocs = ordersSnap.data?.docs ?? [];
                              final Map<String, int> counts = {};
                              for (final o in ordersDocs) {
                                final uid =
                                    (o.data()['userId'] ?? '').toString();
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

                              Widget section(
                                  String title,
                                  List<
                                          QueryDocumentSnapshot<
                                              Map<String, dynamic>>>
                                      docs) {
                                if (docs.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(title,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          const Text(
                                              'لا يوجد عملاء في هذه الفئة'),
                                        ]),
                                  );
                                }
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            child: Text(title,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        ...docs.map((d) {
                                          final u = d.data();
                                          final uid = d.id;
                                          final name = (u['displayName'] ?? '')
                                              .toString();
                                          final phone =
                                              (u['phone'] ?? '').toString();
                                          final orderCount = counts[uid] ?? 0;
                                          final isVIP =
                                              (u['isVIP'] ?? false) as bool;
                                          return _buildCustomerTile(
                                              uid: uid,
                                              name: name,
                                              phone: phone,
                                              isVIP: isVIP,
                                              orderCount: orderCount);
                                        }).toList(),
                                      ]),
                                );
                              }

                              // Use ListView so it can scroll if content large (avoids overflow)
                              return ListView(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                children: [
                                  section('عالي (10+ طلبات)', buckets['عالي']!),
                                  section(
                                      'متوسط (3-9 طلبات)', buckets['متوسط']!),
                                  section(
                                      'منخفض (0-2 طلبات)', buckets['منخفض']!),
                                  const SizedBox(height: 24),
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
          ),
        ),
      ),
    );
  }
}
