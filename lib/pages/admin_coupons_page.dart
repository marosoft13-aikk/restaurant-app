// صفحة إدارة الكوبونات (قائمة + إنشاء/تعديل/حذف بسيط)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_coupon_service.dart';
import 'package:intl/intl.dart';

class AdminCouponsPage extends StatefulWidget {
  const AdminCouponsPage({super.key});

  @override
  State<AdminCouponsPage> createState() => _AdminCouponsPageState();
}

class _AdminCouponsPageState extends State<AdminCouponsPage> {
  final _service = FirebaseCouponService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin — Coupons'),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('coupons')
            .orderBy('code')
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final id = docs[i].id;
              final code = d['code'] ?? '';
              final active = d['active'] == true;
              final type = d['type'] ?? 'fixed';
              final value = d['value'] ?? 0;
              final uses = d['uses'] ?? 0;
              final usageLimit = d['usageLimit'] ?? null;
              final expires = d['expiresAt'] != null
                  ? (d['expiresAt'] as Timestamp).toDate()
                  : null;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  title: Text(
                      '$code • ${type == 'percent' ? '$value%' : '$value ج.م'}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Active: $active • Uses: $uses ${usageLimit != null ? '/ $usageLimit' : ''}'),
                      if (expires != null)
                        Text(
                            'Expires: ${DateFormat.yMd().add_jm().format(expires)}'),
                    ],
                  ),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: Icon(
                          active ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('coupons')
                            .doc(id)
                            .update({'active': !active});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('coupons')
                            .doc(id)
                            .delete();
                      },
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepOrange,
        child: const Icon(Icons.add),
        onPressed: () => _showCreateDialog(),
      ),
    );
  }

  void _showCreateDialog() {
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    String type = 'fixed';
    final usageCtrl = TextEditingController();
    DateTime? expires;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create Coupon'),
          content: StatefulBuilder(builder: (ctx, st) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: 'Code')),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: valueCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Value'))),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                        value: type,
                        items: const [
                          DropdownMenuItem(value: 'fixed', child: Text('EGP')),
                          DropdownMenuItem(value: 'percent', child: Text('%')),
                        ],
                        onChanged: (v) => st(() => type = v ?? 'fixed')),
                  ]),
                  TextField(
                      controller: usageCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Usage limit (optional)')),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Expires:'),
                    const SizedBox(width: 8),
                    Text(expires == null ? 'never' : expires.toString()),
                    IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final dt = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100));
                          if (dt != null) {
                            final tm = await showTimePicker(
                                context: context, initialTime: TimeOfDay.now());
                            if (tm != null) {
                              expires = DateTime(dt.year, dt.month, dt.day,
                                  tm.hour, tm.minute);
                              st(() {});
                            }
                          }
                        })
                  ]),
                ],
              ),
            );
          }),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () async {
                  final code = codeCtrl.text.trim();
                  final value = double.tryParse(valueCtrl.text.trim()) ?? 0.0;
                  final usage = int.tryParse(usageCtrl.text.trim());
                  if (code.isEmpty) return;
                  await FirebaseFirestore.instance.collection('coupons').add({
                    'code': code,
                    'active': true,
                    'type': type,
                    'value': value,
                    'usageLimit': usage,
                    'uses': 0,
                    'expiresAt':
                        expires != null ? Timestamp.fromDate(expires!) : null,
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Create')),
          ],
        );
      },
    );
  }
}
