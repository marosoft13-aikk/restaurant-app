// Updated AdminDashboardPage: adds quick action buttons for
// - إدارة التقييمات (AdminReviewsPage)
// - إدارة الكوبونات (AdminCouponsPage)
// - إدارة الفيديو الترحيبي (AdminVideoPage)
//
// Make sure AdminReviewsPage, AdminCouponsPage and AdminVideoPage exist in these paths.
import 'package:broastaky_full/pages/customers_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_receipts_page.dart';
import 'delivery_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_menu_page.dart';
import 'admin_offers_page.dart';
import 'sales_chart_page.dart';
import '../models/order_model.dart';
import '../pages/admin_order_page.dart';
import '../pages/admin_settings_page.dart';

// New admin pages imports
import '../pages/admin_reviews_page.dart';
import '../pages/admin_coupons_page.dart';
import '../pages/admin_vedio_page.dart';
import '../pages/admin_customers_page.dart';
import '../pages/admin_sales_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text(
          "لوحة التحكم",
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminReceiptsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delivery_dining),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeliveryPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminMenuPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (context, orderSnapshot) {
          return FutureBuilder(
            future: Future.wait([
              FirebaseFirestore.instance.collection('menu').get(),
              FirebaseFirestore.instance.collection('visitors').get(),
            ]),
            builder: (context, asyncSnapshot) {
              int totalOrders = 0;
              double totalSales = 0.0;
              int totalItems = 0;
              int visitorsToday = 0;

              if (orderSnapshot.hasData) {
                totalOrders = orderSnapshot.data!.docs.length;

                totalSales = orderSnapshot.data!.docs.fold(0.0, (sum, doc) {
                  final order =
                      OrderModel.fromMap(doc.data() as Map<String, dynamic>);
                  return sum + order.totalPrice;
                });
              }

              if (asyncSnapshot.hasData) {
                totalItems = asyncSnapshot.data![0].docs.length;
                visitorsToday = asyncSnapshot.data![1].docs.length;
              }

              final stats = [
                {
                  "title": "عدد الطلبات",
                  "value": "$totalOrders",
                  "icon": Icons.shopping_bag
                },
                {
                  "title": "إجمالي المبيعات",
                  "value": "$totalSales جنيه",
                  "icon": Icons.attach_money
                },
                {
                  "title": "عدد الأصناف",
                  "value": "$totalItems",
                  "icon": Icons.fastfood
                },
                {
                  "title": "الزوار اليوم",
                  "value": "$visitorsToday",
                  "icon": Icons.people_alt
                },
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.restaurant,
                              color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "أهلاً بك في لوحة إدارة المطعم 👋",
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "تحكم في كل تفاصيل تطبيقك بسهولة",
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // 🔥 الأزرار بعد الحذف
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _QuickActionButton(
                          title: "إدارة الطلبات",
                          icon: Icons.list_alt,
                          onTap: () async {
                            final snapshot = await FirebaseFirestore.instance
                                .collection('orders')
                                .orderBy('createdAt', descending: true)
                                .get();

                            if (snapshot.docs.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("لا يوجد طلبات حالياً")),
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminOrdersPage(),
                              ),
                            );
                          },
                        ),
                        _QuickActionButton(
                          title: "ادارة العروض",
                          icon: Icons.local_offer,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminOffersPage()),
                            );
                          },
                        ),
                        _QuickActionButton(
                          title: "الإعدادات",
                          icon: Icons.settings,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminSettingsPage()),
                            );
                          },
                        ),

                        // New admin action buttons requested
                        _QuickActionButton(
                          title: "ادارة التقييمات",
                          icon: Icons.reviews,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminReviewsPage()),
                            );
                          },
                        ),
                        _QuickActionButton(
                          title: "ادارة كود الخصم",
                          icon: Icons.discount,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminCouponsPage()),
                            );
                          },
                        ),
                        _QuickActionButton(
                          title: " ادارة العملاء",
                          icon: Icons.people,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminCustomersPage()),
                            );
                          },
                        ),

                        _QuickActionButton(
                          title: "ادارة الفيديو الترحيبي",
                          icon: Icons.video_settings,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminVideoPage()),
                            );
                          },
                        ),
                        _QuickActionButton(
                          title: "ادارة المبيعات",
                          icon: Icons.bar_chart,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminSalesPage()),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: stats.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                      ),
                      itemBuilder: (_, i) {
                        final item = stats[i];
                        return _DashboardCard(
                          title: item["title"] as String,
                          value: item["value"] as String,
                          icon: item["icon"] as IconData,
                        );
                      },
                    ),

                    const SizedBox(height: 25),

                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SalesChartPage()),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.show_chart,
                                size: 40, color: Colors.orange[700]),
                            const SizedBox(height: 10),
                            Text(
                              "عرض تقرير المبيعات",
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// QUICK ACTION BUTTON
class _QuickActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 155,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withOpacity(.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.cairo(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// DASHBOARD CARD
class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.orange, size: 28),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                value,
                style: GoogleFonts.cairo(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                title,
                style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
