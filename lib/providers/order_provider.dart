import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../services/firebase_order_service.dart';

class OrderProvider with ChangeNotifier {
  final FirebaseOrderService _orderService = FirebaseOrderService();

  List<OrderModel> orders = [];
  bool isLoading = false;

  Stream<List<OrderModel>> get ordersStream => _orderService.getOrders();

  // تحميل الأوردرات بشكل مباشر
  Future<void> loadOrders() async {
    isLoading = true;
    notifyListeners();

    _orderService.getOrders().listen((data) {
      orders = data;
      isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addOrder(OrderModel order) async {
    await _orderService.addOrder(order);
  }

  Future<void> updateOrderStatus(String id, String status) async {
    await _orderService.updateOrderStatus(id, status);
  }

  Future<void> deleteOrder(String id) async {
    await _orderService.deleteOrder(id);
  }
}
