// AdminReviewsPage - shows reviews stored on `orders` documents.
// - Uses orderBy('createdAt') and client-side filter rating>0 (avoids composite index).
// - Safe parsing for rating / timestamps.
// - Tap an item to see details and clear the review.
// - Avoid layout overflow on small screens by using Flexible/Expanded and ellipses.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({super.key});

  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  final _ordersCol = FirebaseFirestore.instance.collection('orders');

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    try {
      Timestamp t;
      if (ts is Timestamp) {
        t = ts;
      } else if (ts is Map && ts['_seconds'] != null) {
        t = Timestamp(ts['_seconds'] as int, ts['_nanoseconds'] as int? ?? 0);
      } else {
        return ts.toString();
      }
      final dt = t.toDate();
      return DateFormat.yMd().add_jm().format(dt);
    } catch (_) {
      return ts.toString();
    }
  }

  int _parseRating(dynamic r) {
    if (r == null) return 0;
    if (r is int) return r;
    if (r is double) return r.toInt();
    if (r is num) return r.toInt();
    if (r is String) return int.tryParse(r) ?? 0;
    return 0;
  }

  Future<void> _clearReview(String docId) async {
    try {
      await _ordersCol.doc(docId).update({
        'rating': 0,
        'review': FieldValue.delete(),
        'note': FieldValue.delete(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم مسح التقييم')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل مسح التقييم: $e')),
        );
      }
    }
  }

  void _showDetailsDialog(Map<String, dynamic> data, String docId) {
    final rating = _parseRating(data['rating']);
    final review = (data['review'] ?? data['note'] ?? '').toString();
    final userId = (data['userId'] ?? '').toString();
    final createdAt = _formatTimestamp(data['createdAt']);
    final location = (data['customerLocation'] ?? '').toString();
    final items = (data['items'] is List) ? List.from(data['items']) : [];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.reviews, color: Colors.deepOrange),
            const SizedBox(width: 8),
            Expanded(child: Text('Order: ${data['id'] ?? docId}')),
          ],
        ),
        content: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (createdAt.isNotEmpty) Text('تاريخ: $createdAt'),
            const SizedBox(height: 6),
            Text('المستخدم: ${userId.isNotEmpty ? userId : 'N/A'}'),
            const SizedBox(height: 8),
            Row(
                children: List.generate(
                    5,
                    (i) => Icon(i < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber, size: 20))),
            const SizedBox(height: 8),
            if (review.isNotEmpty) ...[
              const Text('التعليق:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(review),
              const SizedBox(height: 8),
            ],
            if (location.isNotEmpty) Text('الموقع: $location'),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            const Text('الأصناف:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (items.isEmpty) const Text('- لا توجد بيانات أصناف -'),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                    '- ${it is Map ? (it['titleEn'] ?? it['titleAr'] ?? it['itemId'] ?? it['id'] ?? it.toString()) : it.toString()}'),
              ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('تأكيد'),
                  content: const Text(
                      'هل تريد مسح هذا التقييم؟ لا يمكن التراجع عن ذلك.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('مسح',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) await _clearReview(docId);
            },
            child:
                const Text('مسح التقييم', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Optional: create a sample order with a rating for quick testing
  Future<void> _createSampleReview() async {
    try {
      final docRef = await _ordersCol.add({
        'createdAt': FieldValue.serverTimestamp(),
        'rating': 5,
        'review': 'تجربة — تقييم تجريبي',
        'userId': 'tester',
        'items': [
          {'itemId': 'test1', 'titleEn': 'Sample item'}
        ],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('تم إنشاء تقييم تجريبي (id: ${docRef.id})')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل إنشاء تقييم تجريبي: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ادارة التقييمات'),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ordersCol.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          final docs = snap.data?.docs ?? [];

          // filter client-side to avoid needing composite index
          final filtered = docs.where((d) {
            final data = d.data();
            return _parseRating(data['rating']) > 0;
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('لا توجد تقييمات حتى الآن',
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}), // refresh
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _createSampleReview,
                    icon: const Icon(Icons.add),
                    label: const Text('إنشاء تقييم تجريبي'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  ),
                ]),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final doc = filtered[i];
              final d = doc.data();
              final orderId = (d['id'] ?? doc.id).toString();
              final rating = _parseRating(d['rating']);
              final review = (d['review'] ?? d['note'] ?? '').toString();
              final userId = (d['userId'] ?? '').toString();
              final createdAt = _formatTimestamp(d['createdAt']);
              final location = (d['customerLocation'] ?? '').toString();
              final items = (d['items'] is List) ? List.from(d['items']) : [];

              final avatarText = (review.isNotEmpty
                      ? review.substring(0, 1)
                      : (userId.isNotEmpty ? userId.substring(0, 1) : '?'))
                  .toUpperCase();

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade700,
                  child: Text(avatarText,
                      style: const TextStyle(color: Colors.white)),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Order: $orderId',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // limited width for timestamp to avoid overflow
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        createdAt,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    // stars row - safe in a wrap to prevent overflow
                    Row(
                      children: List.generate(
                        5,
                        (k) => Icon(k < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber, size: 18),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // review text (max 2 lines)
                    if (review.isNotEmpty)
                      Text(
                        review,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // location: allow to take remaining space and wrap/ellipsis
                        if (location.isNotEmpty)
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // small gap
                        const SizedBox(width: 8),
                        // user id and items count in a fixed area to avoid pushing layout
                        ConstrainedBox(
                          constraints:
                              const BoxConstraints(minWidth: 80, maxWidth: 140),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  'User: ${userId.isNotEmpty ? userId : 'N/A'}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('Items: ${items.length}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showDetailsDialog(d, doc.id)),
                onTap: () => _showDetailsDialog(d, doc.id),
              );
            },
          );
        },
      ),
    );
  }
}
