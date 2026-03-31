// خدمة بسيطة لإدارة و التحقق من الكوبونات في Firestore
import 'package:cloud_firestore/cloud_firestore.dart';

class CouponModel {
  String id;
  String code;
  bool active;
  String type; // 'percent' or 'fixed'
  double value; // percent like 10.0 or fixed like 20.0
  int? usageLimit; // nullable
  int uses; // current uses
  Timestamp? expiresAt;

  CouponModel({
    required this.id,
    required this.code,
    required this.active,
    required this.type,
    required this.value,
    this.usageLimit,
    this.uses = 0,
    this.expiresAt,
  });

  factory CouponModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CouponModel(
      id: doc.id,
      code: d['code'] ?? '',
      active: d['active'] == true,
      type: d['type'] ?? 'fixed',
      value: (d['value'] is num)
          ? (d['value'] as num).toDouble()
          : double.tryParse('${d['value']}') ?? 0.0,
      usageLimit: d['usageLimit'] != null ? (d['usageLimit'] as int) : null,
      uses: (d['uses'] is int)
          ? d['uses']
          : int.tryParse('${d['uses'] ?? 0}') ?? 0,
      expiresAt: d['expiresAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'active': active,
      'type': type,
      'value': value,
      'usageLimit': usageLimit,
      'uses': uses,
      'expiresAt': expiresAt,
    };
  }
}

class FirebaseCouponService {
  final _col = FirebaseFirestore.instance.collection('coupons');

  Future<List<CouponModel>> getAllCoupons() async {
    final snap = await _col.orderBy('code').get();
    return snap.docs.map((d) => CouponModel.fromDoc(d)).toList();
  }

  Future<DocumentReference> createCoupon(CouponModel c) {
    return _col.add(c.toMap());
  }

  Future<void> updateCoupon(CouponModel c) {
    return _col.doc(c.id).update(c.toMap());
  }

  Future<void> deleteCoupon(String id) {
    return _col.doc(id).delete();
  }

  Future<CouponModel?> findByCode(String code) async {
    final q = await _col.where('code', isEqualTo: code).limit(1).get();
    if (q.docs.isEmpty) return null;
    return CouponModel.fromDoc(q.docs.first);
  }

  /// Validate coupon for a given total amount.
  /// Returns discount amount (EGP) or null if invalid.
  Future<double?> validateCouponAmount(String code, double total) async {
    final coupon = await findByCode(code);
    if (coupon == null) return null;
    if (!coupon.active) return null;
    final now = Timestamp.now();
    if (coupon.expiresAt != null && coupon.expiresAt!.compareTo(now) < 0)
      return null;
    if (coupon.usageLimit != null && coupon.uses >= coupon.usageLimit!)
      return null;

    double discount = 0.0;
    if (coupon.type == 'percent') {
      discount = total * (coupon.value / 100.0);
    } else {
      discount = coupon.value;
    }
    // cap discount to total
    if (discount > total) discount = total;
    return discount;
  }

  /// Increments uses count atomically after successful application
  Future<void> incrementCouponUse(String code) async {
    final q = await _col.where('code', isEqualTo: code).limit(1).get();
    if (q.docs.isEmpty) return;
    final docRef = q.docs.first.reference;
    await docRef.update({'uses': FieldValue.increment(1)});
  }
}
