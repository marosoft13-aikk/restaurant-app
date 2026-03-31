import 'package:flutter/material.dart';
import '../models/order_model.dart';

class OrderDetailsPage extends StatelessWidget {
  final OrderModel order;

  const OrderDetailsPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "تفاصيل الطلب",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🟢 معلومات العميل
            _buildCustomerCard(),

            const SizedBox(height: 20),

            // 🟠 حالة الطلب + زرار تغييرها
            _buildStatusCard(context),

            const SizedBox(height: 20),

            // 🔵 قائمة المنتجات
            _buildItemsList(),

            const Divider(height: 40),

            // 🟣 إجمالي السعر
            _buildTotalPrice(),

            const SizedBox(height: 20),

            // 🟡 معلومات إضافية
            _buildExtraInfo(),
          ],
        ),
      ),
    );
  }

  //───────────────────────────────
  // 🟢 كارت معلومات العميل
  Widget _buildCustomerCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.customerName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "رقم الطلب: ${order.id}",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  //───────────────────────────────
  // 🟠 حالة الطلب + زرار التغيير
  Widget _buildStatusCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "حالة الطلب",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.status,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _showChangeStatusDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("تغيير"),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  //───────────────────────────────
  // 🔵 قائمة المنتجات
  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "المنتجات",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...order.items.map((item) {
          return Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: item.imagePath.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        item.imagePath,
                        width: 55,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.fastfood, size: 40),
              title: Text(item.name),
              subtitle: Text("الكمية: ${item.quantity}"),
              trailing: Text(
                "${item.price} ج.م",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      ],
    );
  }

  //───────────────────────────────
  // 🟣 إجمالي السعر
  Widget _buildTotalPrice() {
    return Center(
      child: Text(
        "الإجمالي: ${order.totalPrice} ج.م",
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    );
  }

  //───────────────────────────────
  // 🟡 معلومات إضافية
  Widget _buildExtraInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("طريقة الدفع: ${order.paymentMethod}"),
        const SizedBox(height: 6),
        Text("وقت الطلب: ${order.createdAt}"),
      ],
    );
  }

  //───────────────────────────────
  // 🛑 Dialog تغيير حالة الطلب
  void _showChangeStatusDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String selectedStatus = order.status;

        return AlertDialog(
          title: const Text("تغيير حالة الطلب"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButton<String>(
                value: selectedStatus,
                items: const [
                  DropdownMenuItem(value: "pending", child: Text("Pending")),
                  DropdownMenuItem(
                      value: "preparing", child: Text("Preparing")),
                  DropdownMenuItem(value: "done", child: Text("Done")),
                  DropdownMenuItem(value: "cancel", child: Text("Canceled")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => selectedStatus = val);
                  }
                },
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text("إلغاء"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text("حفظ"),
              onPressed: () {
                // TODO: تحديث الحالة في Firestore
                Navigator.pop(context);
              },
            )
          ],
        );
      },
    );
  }
}
