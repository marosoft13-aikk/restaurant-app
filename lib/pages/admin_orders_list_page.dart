import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import 'admin_order_details_page.dart';

class AdminOrdersListPage extends StatefulWidget {
  const AdminOrdersListPage({super.key});

  @override
  State<AdminOrdersListPage> createState() => _AdminOrdersListPageState();
}

class _AdminOrdersListPageState extends State<AdminOrdersListPage>
    with SingleTickerProviderStateMixin {
  String selectedFilter = "all";
  String searchText = "";

  List<String> filters = ["all", "Pending", "preparing", "ready", "on_the_way"];
  Map<String, String> labels = {
    "all": "الكل",
    "Pending": "قيد الانتظار",
    "preparing": "قيد التحضير",
    "ready": "جاهز للاستلام",
    "on_the_way": "في الطريق",
  };

  late AnimationController animCtrl;

  @override
  void initState() {
    super.initState();
    animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    animCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------
  Stream<QuerySnapshot> getOrdersStream() {
    final baseQuery = FirebaseFirestore.instance.collection("orders");

    if (selectedFilter == "all") {
      return baseQuery.snapshots();
    } else {
      return baseQuery.where("status", isEqualTo: selectedFilter).snapshots();
    }
  }

  // Mark an order as READY (this will be visible to drivers listening for status == "ready")
  Future<void> markOrderReady(String orderId) async {
    final docRef = FirebaseFirestore.instance.collection("orders").doc(orderId);
    await docRef.update({
      "status": "ready",
      "readyAt": FieldValue.serverTimestamp(),
    });

    // Optional: you can also create a lightweight "notifications" doc or send FCM message from Cloud Function
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f8f8),
      appBar: AppBar(
        title: const Text("الطلبات الحالية"),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
      ),
      body: Column(
        children: [
          // 🔍 البحث
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "ابحث عن عميل أو رقم الطلب...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onChanged: (value) {
                setState(() => searchText = value.trim());
              },
            ),
          ),

          // 🔘 الفلاتر
          SizedBox(
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: filters.map((f) {
                bool active = selectedFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(labels[f] ?? f,
                        style: const TextStyle(fontSize: 15)),
                    selected: active,
                    selectedColor: Colors.deepOrange,
                    backgroundColor: Colors.white,
                    labelStyle:
                        TextStyle(color: active ? Colors.white : Colors.black),
                    onSelected: (_) {
                      setState(() => selectedFilter = f);
                      animCtrl.forward(from: 0);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // 📦 قائمة الطلبات
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "لا توجد طلبات...",
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                // فلترة البحث
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data["customerName"] ?? "").toString();
                  final id = doc.id.toString();

                  return name.contains(searchText) || id.contains(searchText);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      "لا توجد نتائج...",
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    data["id"] = doc.id;
                    final order =
                        OrderModel.fromMap(Map<String, dynamic>.from(data));

                    return ScaleTransition(
                      scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animCtrl,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepOrange,
                            child: Text(
                              order.customerName.isNotEmpty
                                  ? order.customerName[0].toUpperCase()
                                  : "?",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            "طلب رقم: ${order.id}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("👤 العميل: ${order.customerName}"),
                              Text("💰 الإجمالي: ${order.totalPrice} جنيه"),
                              Text("📌 الحالة: ${order.status}"),
                            ],
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              if (order.status == "preparing" ||
                                  order.status == "Pending")
                                ElevatedButton(
                                  onPressed: () async {
                                    // تأكيد قبل تغيير الحالة
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text("تأكيد"),
                                        content: const Text(
                                            "هل تريد وسم الطلب كـ جاهز للاستلام؟"),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, false),
                                              child: const Text("لا")),
                                          ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, true),
                                              child: const Text("نعم")),
                                        ],
                                      ),
                                    );

                                    if (ok == true) {
                                      await markOrderReady(order.id);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text("تم وسم الطلب كجاهز")),
                                      );
                                    }
                                  },
                                  child: const Text("Mark Ready"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AdminOrderDetailsPage(order: order),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
