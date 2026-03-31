// محدث: CartItem يدعم الحقول الجديدة: rating, review, customerLocation,
// couponCode, discount, finalPrice. حافظت على أسلوبك (price و qty قابلان للتعديل).
import 'package:flutter/foundation.dart';

class CartItem {
  final String id;
  final String menuItemId;
  final String titleEn;
  final String titleAr;
  double price;
  int qty;
  Map<String, dynamic>? selectedOption; // {name, price, ...}
  final List<dynamic>? options;
  String type; // hot/cold/mix
  String note;
  final String imagePath;

  // New fields
  int? rating; // 1..5
  String? review;
  String? customerLocation; // plain text or "lat,lng"
  String? couponCode;
  double discount; // EGP applied to this item
  double finalPrice; // computed price*qty - discount

  CartItem({
    required this.id,
    required this.menuItemId,
    required this.titleEn,
    required this.titleAr,
    required this.price,
    required this.qty,
    this.selectedOption,
    this.options,
    this.type = 'hot',
    this.note = '',
    this.imagePath = '',
    this.rating,
    this.review,
    this.customerLocation,
    this.couponCode,
    this.discount = 0.0,
    double? finalPrice,
  }) : finalPrice = finalPrice ?? ((price * qty) - (discount));

  // update helper to recompute finalPrice after price/qty/discount changes
  void recomputeFinalPrice() {
    finalPrice = (price * qty) - discount;
    if (finalPrice < 0) finalPrice = 0.0;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'menuItemId': menuItemId,
        'titleEn': titleEn,
        'titleAr': titleAr,
        'price': price,
        'qty': qty,
        'selectedOption': selectedOption,
        'options': options,
        'type': type,
        'note': note,
        'imagePath': imagePath,
        // new fields
        'rating': rating,
        'review': review,
        'customerLocation': customerLocation,
        'couponCode': couponCode,
        'discount': discount,
        'finalPrice': finalPrice,
      };

  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
        id: m['id'] ?? '',
        menuItemId: m['menuItemId'] ?? '',
        titleEn: m['titleEn'] ?? '',
        titleAr: m['titleAr'] ?? '',
        price: (m['price'] is num) ? (m['price'] as num).toDouble() : double.tryParse('${m['price']}') ?? 0.0,
        qty: (m['qty'] is int) ? m['qty'] : int.tryParse('${m['qty']}') ?? 1,
        selectedOption: m['selectedOption'] != null ? Map<String, dynamic>.from(m['selectedOption']) : null,
        options: m['options'] != null ? List<dynamic>.from(m['options']) : null,
        type: m['type'] ?? 'hot',
        note: m['note'] ?? '',
        imagePath: m['imagePath'] ?? '',
        rating: m['rating'] != null ? (m['rating'] is int ? m['rating'] : int.tryParse('${m['rating']}')) : null,
        review: m['review'],
        customerLocation: m['customerLocation'],
        couponCode: m['couponCode'],
        discount: (m['discount'] is num) ? (m['discount'] as num).toDouble() : double.tryParse('${m['discount']}') ?? 0.0,
        finalPrice: (m['finalPrice'] is num) ? (m['finalPrice'] as num).toDouble() : double.tryParse('${m['finalPrice']}') ?? 0.0,
      );
}