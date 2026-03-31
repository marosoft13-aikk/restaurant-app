import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart_item.dart';

enum OrderStatusLocal { preparing, ready, onTheWay }

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];
  String _customerNotes = '';
  String _deliveryMethod = 'delivery';
  String _paymentMethod = 'cod';

  // local order status (fallback)
  OrderStatusLocal _orderStatus = OrderStatusLocal.preparing;

  List<CartItem> get items => List.unmodifiable(_items);
  String get customerNotes => _customerNotes;
  String get deliveryMethod => _deliveryMethod;
  String get paymentMethod => _paymentMethod;
  OrderStatusLocal get orderStatus => _orderStatus;

  int get count => _items.fold(0, (s, it) => s + it.qty);
  double get totalAmount =>
      _items.fold(0.0, (s, it) => s + (it.price * it.qty));

  void setCustomerNotes(String notes) {
    _customerNotes = notes;
    notifyListeners();
  }

  void setDeliveryMethod(String val) {
    _deliveryMethod = val;
    notifyListeners();
  }

  void setPaymentMethod(String val) {
    _paymentMethod = val;
    notifyListeners();
  }

  void addItem(CartItem item) {
    // merge by menuItemId + selectedOption name
    final idx = _items.indexWhere((it) =>
        it.menuItemId == item.menuItemId &&
        (it.selectedOption?['name'] ?? '') ==
            (item.selectedOption?['name'] ?? ''));
    if (idx >= 0) {
      _items[idx].qty += item.qty;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void updateQty(String id, int qty) {
    final idx = _items.indexWhere((it) => it.id == id);
    if (idx >= 0) {
      if (qty <= 0) {
        _items.removeAt(idx);
      } else {
        _items[idx].qty = qty;
      }
      notifyListeners();
    }
  }

  void removeItem(String id) {
    _items.removeWhere((it) => it.id == id);
    notifyListeners();
  }

  void updateItemOption(String id, Map<String, dynamic> option) {
    final idx = _items.indexWhere((it) => it.id == id);
    if (idx >= 0) {
      _items[idx].selectedOption = option;
      final p = (option['price'] is num)
          ? (option['price'] as num).toDouble()
          : double.tryParse('${option['price']}') ?? _items[idx].price;
      _items[idx].price = p;
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _customerNotes = '';
    _deliveryMethod = 'delivery';
    _paymentMethod = 'cod';
    notifyListeners();
  }

  void setOrderStatus(OrderStatusLocal s) {
    _orderStatus = s;
    notifyListeners();
  }

  /// Create order doc in Firestore from current cart; returns orderId or null
  Future<String?> placeOrderToFirestore({required String userId}) async {
    if (_items.isEmpty) return null;
    try {
      final col = FirebaseFirestore.instance.collection('orders');
      final doc = col.doc();

      final itemsMap = _items.map((e) => e.toMap()).toList();
      final map = {
        'id': doc.id,
        'userId': userId,
        'items': itemsMap,
        'total': totalAmount,
        'deliveryMethod': _deliveryMethod,
        'paymentMethod': _paymentMethod,
        'customerNotes': _customerNotes,
        'status': 'preparing',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await doc.set(map);
      clear();
      return doc.id;
    } catch (e) {
      debugPrint('placeOrderToFirestore error: $e');
      return null;
    }
  }
}
