import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminReceiptsPage extends StatelessWidget {
  const AdminReceiptsPage({super.key});

  /// تحديث حالة الإيصال + حالة الطلب
  Future<void> updateStatus(
      String receiptId, String orderId, bool isAccepted) async {
    await FirebaseFirestore.instance
        .collection("receipts")
        .doc(receiptId)
        .update({
      "status": isAccepted ? "accepted" : "rejected",
    });

    // حاول التحديث فقط لو مستند الطلب موجود
    final orderRef =
        FirebaseFirestore.instance.collection("orders").doc(orderId);
    final orderSnap = await orderRef.get();
    if (orderSnap.exists) {
      await orderRef.update({
        "paymentStatus": isAccepted ? "verified" : "rejected",
      });
    }
  }

  DateTime? safeTimestamp(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة إيصالات الدفع"),
        backgroundColor: Colors.orange,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('receipts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text('لا توجد إيصالات حتى الآن',
                  style: TextStyle(fontSize: 18)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final imageUrl = data["imageUrl"] as String?;
              final orderId = data["orderId"] ?? "غير معروف";
              final amount = data["amount"]?.toString() ?? "0";
              final method = data["method"] ?? "غير معروف";
              final merchantNumber = data["merchantNumber"] ?? "غير متوفر";
              final transactionNumber =
                  data["transactionNumber"] ?? "غير متوفر";
              final timestamp = safeTimestamp(data["timestamp"]);
              final status = data["status"] ?? "pending";

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        GestureDetector(
                          onTap: () async {
                            final uri = Uri.parse(imageUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, e, _) => Container(
                                height: 180,
                                color: Colors.grey[300],
                                alignment: Alignment.center,
                                child: const Text("تعذر تحميل الصورة"),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text("رقم الطلب: $orderId",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text("طريقة الدفع: $method",
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[800])),
                      const SizedBox(height: 4),
                      Text("رقم التاجر: $merchantNumber",
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      Text("رقم التحويل: $transactionNumber",
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      Text("المبلغ المدفوع: $amount جنيه",
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.green[900],
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        "التاريخ: ${timestamp != null ? timestamp.toString() : "غير متوفر"}",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: status == "pending"
                                  ? () async {
                                      await updateStatus(doc.id, orderId, true);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text("تم قبول الإيصال ✔")),
                                      );
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("قبول",
                                  style: TextStyle(fontSize: 18)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: status == "pending"
                                  ? () async {
                                      await updateStatus(
                                          doc.id, orderId, false);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text("تم رفض الإيصال ❌")),
                                      );
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("رفض",
                                  style: TextStyle(fontSize: 18)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          status == "pending"
                              ? "قيد المراجعة"
                              : status == "accepted"
                                  ? "✔ تم القبول"
                                  : "❌ مرفوض",
                          style: TextStyle(
                            fontSize: 16,
                            color: status == "pending"
                                ? Colors.orange
                                : status == "accepted"
                                    ? Colors.green
                                    : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }
}
