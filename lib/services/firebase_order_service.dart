import 'package:cloud_firestore/cloud_firestore.dart';

//import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../services/firebase_order_service.dart';

class FirebaseOrderService {
  final CollectionReference ordersRef =
      FirebaseFirestore.instance.collection('orders');

  // 🔥 جلب جميع الطلبات بشكل Stream
  Stream<List<OrderModel>> getOrders() {
    return ordersRef
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return OrderModel.fromMap(data);
            }).toList());
  }

  // 🔥 إضافة طلب جديد
  Future<void> addOrder(OrderModel order) async {
    try {
      await ordersRef.doc(order.id).set(order.toMap());
    } catch (e) {
      print("Error adding order: $e");
      rethrow;
    }
  }

  // 🔥 تحديث حالة الطلب
  Future<void> updateOrderStatus(String id, String status) async {
    try {
      await ordersRef.doc(id).update({'status': status});
    } catch (e) {
      print("Error updating order status: $e");
      rethrow;
    }
  }

  // 🔥 حذف الطلب
  Future<void> deleteOrder(String id) async {
    try {
      await ordersRef.doc(id).delete();
    } catch (e) {
      print("Error deleting order: $e");
      rethrow;
    }
  }

  // 🔥 جلب آخر طلب
  Future<OrderModel?> getLatestOrder() async {
    final snapshot =
        await ordersRef.orderBy('createdAt', descending: true).limit(1).get();

    if (snapshot.docs.isEmpty) return null;

    return OrderModel.fromMap(
        snapshot.docs.first.data() as Map<String, dynamic>);
  }
}
