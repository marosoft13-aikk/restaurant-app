import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firebase_order_service.dart';
import '../models/order_model.dart';

final orderService = FirebaseOrderService();

class DashboardProvider with ChangeNotifier {
  Future<OrderModel?> getLatestOrder() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return OrderModel.fromMap(snapshot.docs.first.data());
  }

  int ordersToday = 0;
  double totalSales = 0.0;
  int menuItems = 0;
  int visitorsToday = 0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> fetchDashboardData() async {
    try {
      // عدد الطلبات اليوم
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      final end = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThanOrEqualTo: end)
          .get();

      ordersToday = ordersSnapshot.docs.length;

      // إجمالي المبيعات
      totalSales = ordersSnapshot.docs
          .fold(0.0, (sum, doc) => sum + (doc['totalPrice'] ?? 0.0));

      // عدد الأصناف
      final menuSnapshot = await _firestore.collection('menuItems').get();
      menuItems = menuSnapshot.docs.length;

      // الزوار اليوم (إذا عندك تتبع زي تسجيل دخول العملاء)
      visitorsToday = ordersToday; // مؤقتاً نفس عدد الطلبات

      notifyListeners();
    } catch (e) {
      print("Error fetching dashboard data: $e");
    }
  }
}
