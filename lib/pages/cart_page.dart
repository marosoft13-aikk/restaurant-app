// Updated CartPage to:
// - show rating & review per cart item (if present)
// - add coupon input at cart level with validation against `coupons` collection
// - on pressing "اطلب الآن" creates the order document directly (includes new fields)
// NOTE: this file replaces your existing lib/pages/cart_page.dart (you pasted earlier).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/cart_provider.dart';
import '../models/cart_item.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _couponCtrl = TextEditingController();
  bool _validatingCoupon = false;
  double _couponDiscount = 0.0;
  String? _appliedCouponCode;
  String _couponInfoMessage = '';

  @override
  void dispose() {
    _notesCtrl.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<double?> _validateCoupon(String code, double total) async {
    // Simple validation logic against `coupons` collection
    // Document structure expected:
    // { code: string, active: bool, type: 'percent'|'fixed', value: number, usageLimit: int?, uses: int, expiresAt: Timestamp? }
    final col = FirebaseFirestore.instance.collection('coupons');
    final q = await col.where('code', isEqualTo: code).limit(1).get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first.data();
    final active = d['active'] == true;
    if (!active) return null;
    final Timestamp? expiresAt = d['expiresAt'] as Timestamp?;
    if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now()))
      return null;
    final int? usageLimit = d['usageLimit'];
    final int uses =
        (d['uses'] is int) ? d['uses'] : int.tryParse('${d['uses'] ?? 0}') ?? 0;
    if (usageLimit != null && uses >= usageLimit) return null;

    final String type = d['type'] ?? 'fixed';
    final double value = (d['value'] is num)
        ? (d['value'] as num).toDouble()
        : double.tryParse('${d['value']}') ?? 0.0;

    double discount = 0.0;
    if (type == 'percent') {
      discount = total * (value / 100.0);
    } else {
      discount = value;
    }
    if (discount > total) discount = total;
    return discount;
  }

  Future<void> _applyCoupon(CartProvider cart) async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) {
      setState(() {
        _couponInfoMessage = 'ادخل كود الخصم';
        _appliedCouponCode = null;
        _couponDiscount = 0.0;
      });
      return;
    }
    setState(() {
      _validatingCoupon = true;
      _couponInfoMessage = '';
    });
    try {
      final totalBefore = cart.totalAmount;
      final disc = await _validateCoupon(code, totalBefore);
      if (disc != null) {
        setState(() {
          _couponDiscount = disc;
          _appliedCouponCode = code;
          _couponInfoMessage =
              'تم تطبيق الكوبون: -${disc.toStringAsFixed(2)} ج.م';
        });
      } else {
        setState(() {
          _couponDiscount = 0.0;
          _appliedCouponCode = null;
          _couponInfoMessage = 'كود غير صالح أو منتهي';
        });
      }
    } catch (e) {
      setState(() {
        _couponInfoMessage = 'خطأ أثناء التحقق';
        _appliedCouponCode = null;
        _couponDiscount = 0.0;
      });
    } finally {
      setState(() => _validatingCoupon = false);
    }
  }

  Future<void> _createOrderDirectly(
      BuildContext context, CartProvider cart) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول')));
      return;
    }

    final ordersCol = FirebaseFirestore.instance.collection('orders');
    final doc = ordersCol.doc();

    // build items list including new fields
    final items = cart.items.map((CartItem it) {
      return {
        'id': it.id,
        'itemId': it.menuItemId,
        'titleEn': it.titleEn,
        'titleAr': it.titleAr,
        'price': it.price,
        'qty': it.qty,
        'selectedOption': it.selectedOption,
        'options': it.options,
        'type': it.type,
        'note': it.note,
        // new fields per item
        'rating': it.rating ?? 0,
        'review': it.review ?? '',
        'customerLocation': it.customerLocation ?? '',
        'couponCode': it.couponCode ?? '',
        'discount': it.discount,
        'finalPrice': it.finalPrice,
      };
    }).toList();

    final double totalBefore = cart.totalAmount;
    final double discount = _couponDiscount;
    final double totalAfter =
        (totalBefore - discount).clamp(0.0, double.infinity);

    final orderMap = {
      'id': doc.id,
      'userId': user.uid,
      'items': items,
      'totalBeforeDiscount': totalBefore,
      'discount': discount,
      'total': totalAfter,
      'deliveryMethod': cart.deliveryMethod,
      'paymentMethod': cart.paymentMethod,
      'customerNotes': _notesCtrl.text.trim(),
      'couponCode': _appliedCouponCode ?? '',
      'status': 'preparing',
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await doc.set(orderMap);

      // Optionally increment coupon usage (do it after successful order)
      if (_appliedCouponCode != null && _appliedCouponCode!.isNotEmpty) {
        final col = FirebaseFirestore.instance.collection('coupons');
        final q = await col
            .where('code', isEqualTo: _appliedCouponCode)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          await q.docs.first.reference
              .update({'uses': FieldValue.increment(1)});
        }
      }

      // Clear cart if provider supports it
      try {
        cart.clear(); // if CartProvider has clear()
      } catch (_) {}

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تم إرسال الطلب: ${doc.id}')));
      Navigator.pushNamed(context, '/tracking', arguments: {'orderId': doc.id});
    } catch (e) {
      debugPrint('Order creation failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('فشل إنشاء الطلب'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('السلة'),
        backgroundColor: Colors.orange,
      ),
      body: cart.items.isEmpty
          ? const Center(
              child: Text(
                'السلة فارغة',
                style: TextStyle(fontSize: 18),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: cart.items.length,
                    itemBuilder: (context, i) {
                      final item = cart.items[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (item.imagePath.isNotEmpty)
                                    Image.network(item.imagePath,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.fastfood))
                                  else
                                    const SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: Icon(Icons.fastfood)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            item.titleEn.isNotEmpty
                                                ? item.titleEn
                                                : item.titleAr,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        Text(
                                            '${item.type == 'hot' ? "حار" : item.type == 'cold' ? "بارد" : "ميكس"} - الكمية: ${item.qty}'),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                          '${(item.price * item.qty).toStringAsFixed(2)} ج.م',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          IconButton(
                                              icon: const Icon(
                                                  Icons.remove_circle),
                                              onPressed: () => cart.updateQty(
                                                  item.id, item.qty - 1)),
                                          Text('${item.qty}'),
                                          IconButton(
                                              icon:
                                                  const Icon(Icons.add_circle),
                                              onPressed: () => cart.updateQty(
                                                  item.id, item.qty + 1)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (item.options != null &&
                                  item.options!.isNotEmpty)
                                OptionSelectorWidget(
                                    cartItem: item, cartProvider: cart),
                              const SizedBox(height: 6),

                              // Show rating & review if available
                              if (item.rating != null)
                                Row(
                                  children: [
                                    const Text('التقييم: ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Row(
                                      children: List.generate(
                                          5,
                                          (k) => Icon(
                                                k < (item.rating ?? 0)
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                color: Colors.amber,
                                                size: 18,
                                              )),
                                    )
                                  ],
                                ),
                              if (item.review != null &&
                                  item.review!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text('تقييم المستخدم: ${item.review}'),
                                ),
                              if (item.customerLocation != null &&
                                  item.customerLocation!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                      'موقع الزبون: ${item.customerLocation}'),
                                ),
                              if (item.couponCode != null &&
                                  item.couponCode!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                      'كود خاص بالعنصر: ${item.couponCode}'),
                                ),

                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  onPressed: () => cart.removeItem(item.id),
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Notes
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                        labelText: 'أضف ملاحظة للطلب',
                        border: OutlineInputBorder()),
                    onChanged: (v) => cart.setCustomerNotes(v),
                  ),
                ),

                // Coupon row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _couponCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'كود الخصم',
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _validatingCoupon
                                ? null
                                : () => _applyCoupon(cart),
                            child: _validatingCoupon
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('تطبيق'),
                          )
                        ],
                      ),
                      if (_couponInfoMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(_couponInfoMessage,
                              style: TextStyle(
                                  color: _appliedCouponCode != null
                                      ? Colors.green
                                      : Colors.red)),
                        ),
                    ],
                  ),
                ),

                // Delivery & Payment
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: RadioListTile<String>(
                                  title: const Text('توصيل'),
                                  value: 'delivery',
                                  groupValue: cart.deliveryMethod,
                                  onChanged: (v) =>
                                      cart.setDeliveryMethod(v ?? 'delivery'))),
                          Expanded(
                              child: RadioListTile<String>(
                                  title: const Text('استلام'),
                                  value: 'pickup',
                                  groupValue: cart.deliveryMethod,
                                  onChanged: (v) =>
                                      cart.setDeliveryMethod(v ?? 'pickup'))),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                              child: RadioListTile<String>(
                                  title: const Text('دفع عند الاستلام'),
                                  value: 'cod',
                                  groupValue: cart.paymentMethod,
                                  onChanged: (v) =>
                                      cart.setPaymentMethod(v ?? 'cod'))),
                          Expanded(
                              child: RadioListTile<String>(
                                  title: const Text('دفع أونلاين'),
                                  value: 'online',
                                  groupValue: cart.paymentMethod,
                                  onChanged: (v) =>
                                      cart.setPaymentMethod(v ?? 'online'))),
                        ],
                      ),
                    ],
                  ),
                ),

                // Bottom summary and order button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                      color: Colors.orange,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20))),
                  child: Column(
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الإجمالي:',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            Text('${cart.totalAmount.toStringAsFixed(2)} ج.م',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ]),
                      if (_couponDiscount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('خصم الكوبون:',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 16)),
                                Text(
                                    '-${_couponDiscount.toStringAsFixed(2)} ج.م',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 16)),
                              ]),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white),
                          onPressed: () async {
                            await _createOrderDirectly(context, cart);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text('اطلب الآن',
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class OptionSelectorWidget extends StatefulWidget {
  final CartItem cartItem;
  final CartProvider cartProvider;

  const OptionSelectorWidget(
      {super.key, required this.cartItem, required this.cartProvider});

  @override
  State<OptionSelectorWidget> createState() => _OptionSelectorWidgetState();
}

class _OptionSelectorWidgetState extends State<OptionSelectorWidget> {
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.cartItem.selectedOption != null) {
      _selected = widget.cartItem.selectedOption;
    } else if (widget.cartItem.options != null &&
        widget.cartItem.options!.isNotEmpty) {
      _selected = Map<String, dynamic>.from(widget.cartItem.options!.first);
      try {
        widget.cartProvider.updateItemOption(widget.cartItem.id, _selected!);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.cartItem.options ?? [];
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 8, right: 8),
      child: Row(
        children: [
          const Text('الحجم:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          DropdownButton<Map<String, dynamic>>(
            value: _selected,
            items: options.map((opt) {
              final mapOpt = Map<String, dynamic>.from(opt);
              return DropdownMenuItem<Map<String, dynamic>>(
                  value: mapOpt,
                  child: Text('${mapOpt['name']} (${mapOpt['price']} ج.م)'));
            }).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _selected = v);
              widget.cartProvider.updateItemOption(widget.cartItem.id, v);
            },
          ),
        ],
      ),
    );
  }
}
