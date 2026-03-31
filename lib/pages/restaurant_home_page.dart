import 'package:flutter/material.dart';

// صفحاتك
import 'admin_orders_list_page.dart'; // ← صفحة الطلبات الحالية
import '../pages/admin_order_details_page.dart'
    as ord; // ← صفحة الطلبات الحالية

import 'admin_order_details_page.dart'; // ← صفحة الطلبات الحالية
import 'admin_dashboard_page.dart'; // ← صفحة لوحة التحكم
import 'admin_pasword_page.dart' as pwd; // ← صفحة الباسورد

typedef _AdminPasswordPage = pwd.AdminPasswordPage;
typedef _AdminOrderDetailsPage = ord.AdminOrderDetailsPage;

class RestaurantHomePage extends StatelessWidget {
  const RestaurantHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("لوحة إدارة المطعم"),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),

            // ========= بطاقة إدارة الطلبات =========
            _buildCard(
              context: context,
              title: "إدارة الطلبات الحالية",
              subtitle: "عرض الطلبات • متابعة الحالة • تعديل الطلب",
              icon: Icons.receipt_long,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // builder: (_) => const AdminOrdersListPage(),
                    builder: (_) => const AdminOrdersListPage(),
                    // builder: (_) => const AdminOrderDetailsPage
                  ),
                );
              },
            ),

            const SizedBox(height: 25),

            // ========= بطاقة لوحة التحكم =========
            _buildCard(
              context: context,
              title: "لوحة التحكم",
              subtitle: "إدارة المنيو • إضافة منتجات • تقارير",
              icon: Icons.dashboard_customize,
              color: Colors.deepOrangeAccent,
              onTap: () {
                // صفحة الباسورد قبل الدخول للوحة التحكم
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _AdminPasswordPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Widget للكرت الاحترافي
  Widget _buildCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(.15),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  )
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}
