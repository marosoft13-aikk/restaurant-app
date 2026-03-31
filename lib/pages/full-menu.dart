import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:video_player/video_player.dart';

import '../models/menu_item_model.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import 'cart_page.dart';
import 'item_option_page.dart';
import '../pages/online_payment_page.dart';
import '../pages/order_tracking_page.dart';
import '../services/firebase_menu_service.dart';
import '../pages/offers_page.dart';

const Map<String, Map<String, String>> _L = {
  'en': {
    'menu': 'Menu',
    'offers': 'Offers',
    'meals': 'Meals',
    'sandwiches': 'Sandwiches',
    'fries': 'Fries',
    'sauces': 'Sauces',
    'additions': 'Additions',
    'add_note': 'Add a note...',
    'delivery': 'Delivery',
    'pickup': 'Pickup',
    'payment': 'Payment',
    'cod': 'Cash on delivery',
    'online': 'Online',
    'add_to_cart': 'Add to cart',
    'order': 'Order',
    'location': 'Location',
    'apply': 'Apply',
    'coupon': 'Coupon code',
    'rating': 'Rate this item',
    'review': 'Write a review',
    'use_location': 'Use current location',
    'tap_image': 'Tap image to view description',
    'close': 'Close',
    'hot': 'Hot',
    'cold': 'Cold',
    'mix': 'Mix',
    'view': 'View',
    'description': 'Description',
  },
  'ar': {
    'menu': 'المنيو',
    'offers': 'العروض',
    'meals': 'الوجبات',
    'sandwiches': 'السندوتشات',
    'fries': 'البطاطس',
    'sauces': 'الصوصات',
    'additions': 'الإضافات',
    'add_note': 'اكتب ملاحظة...',
    'delivery': 'دليفري',
    'pickup': 'استلام',
    'payment': 'الدفع',
    'cod': 'الدفع عند الاستلام',
    'online': 'دفع أونلاين',
    'add_to_cart': 'أضف للسلة',
    'order': 'اطلب',
    'location': 'موقع العميل',
    'apply': 'تطبيق',
    'coupon': 'كود الخصم',
    'rating': 'قيم هذا المنتج',
    'review': 'اكتب تقييمك',
    'use_location': 'استخدم موقعي الحالي',
    'tap_image': 'اضغط على الصورة لعرض الوصف',
    'close': 'إغلاق',
    'hot': 'سخن',
    'cold': 'بارد',
    'mix': 'مكس',
    'view': 'عرض',
    'description': 'الوصف',
  }
};

String _t(String key, String locale) => _L[locale]?[key] ?? key;

class CartItemData {
  final MenuItemModel? item; // nullable so offers can also return data
  final String type;
  final String note;
  final String deliveryMethod;
  final String paymentMethod;
  final int qty;
  final int? rating;
  final String? review;
  final String? couponCode;
  final double? discount;
  final String? customerLocation;

  CartItemData({
    this.item,
    required this.type,
    required this.note,
    required this.deliveryMethod,
    required this.paymentMethod,
    required this.qty,
    this.rating,
    this.review,
    this.couponCode,
    this.discount,
    this.customerLocation,
  });
}

// ItemOptionSheet supports either a MenuItemModel (item) or an offer Map (offerData).
class ItemOptionSheet extends StatefulWidget {
  final MenuItemModel? item;
  final Map<String, dynamic>? offerData;
  final String locale;
  final bool addToCartMode;
  final ScrollController? scrollController;

  const ItemOptionSheet({
    super.key,
    this.item,
    this.offerData,
    required this.locale,
    this.addToCartMode = false,
    this.scrollController,
  });

  @override
  State<ItemOptionSheet> createState() => _ItemOptionSheetState();
}

class _ItemOptionSheetState extends State<ItemOptionSheet> {
  String type = 'hot';
  String deliveryMethod = 'delivery';
  String paymentMethod = 'cod';
  int qty = 1;

  final TextEditingController noteCtrl = TextEditingController();
  final TextEditingController reviewCtrl = TextEditingController();
  final TextEditingController couponCtrl = TextEditingController();
  final TextEditingController locationCtrl = TextEditingController();

  int rating = 0;
  bool gettingLocation = false;
  final Location _locationService = Location();

  String get _title {
    if (widget.item != null) {
      return widget.locale == 'ar'
          ? (widget.item!.titleAr ?? '')
          : (widget.item!.titleEn ?? '');
    }
    return (widget.offerData?['title'] ?? '').toString();
  }

  double get _price {
    if (widget.item != null) return widget.item!.price ?? 0.0;
    final raw =
        widget.offerData?['price'] ?? widget.offerData?['price_str'] ?? '0';
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    reviewCtrl.dispose();
    couponCtrl.dispose();
    locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    try {
      setState(() => gettingLocation = true);
      bool enabled = await _location_service_requestServiceSafe();
      if (!enabled) enabled = await _locationService.requestService();
      PermissionStatus perm = await _location_service_hasPermissionSafe();
      if (perm == PermissionStatus.denied) {
        perm = await _locationService.requestPermission();
      }
      if (perm != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.locale == 'ar'
                ? 'يرجى منح صلاحية الموقع'
                : 'Please allow location permission')));
        setState(() => gettingLocation = false);
        return;
      }
      final loc = await _locationService.getLocation();
      if (loc.latitude != null && loc.longitude != null) {
        locationCtrl.text = '${loc.latitude},${loc.longitude}';
      }
    } catch (e) {
      debugPrint('Get location failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.locale == 'ar'
              ? 'فشل الحصول على الموقع'
              : 'Failed to get location')));
    } finally {
      setState(() => gettingLocation = false);
    }
  }

  Future<bool> _location_service_requestServiceSafe() async {
    try {
      return await _locationService.requestService();
    } catch (_) {
      return false;
    }
  }

  Future<PermissionStatus> _location_service_hasPermissionSafe() async {
    try {
      return await _locationService.hasPermission();
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  Widget _buildStar(int index) {
    return GestureDetector(
      onTap: () => setState(() => rating = index + 1),
      child: Icon(index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final isAddMode = widget.addToCartMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: widget.scrollController,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(_title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    ChoiceChip(
                        label: Text(_t('hot', locale)),
                        selected: type == 'hot',
                        onSelected: (_) => setState(() => type = 'hot')),
                    const SizedBox(width: 8),
                    ChoiceChip(
                        label: Text(_t('cold', locale)),
                        selected: type == 'cold',
                        onSelected: (_) => setState(() => type = 'cold')),
                    const SizedBox(width: 8),
                    ChoiceChip(
                        label: Text(_t('mix', locale)),
                        selected: type == 'mix',
                        onSelected: (_) => setState(() => type = 'mix')),
                    const Spacer(),
                    IconButton(
                        onPressed: () =>
                            setState(() => qty = qty > 1 ? qty - 1 : 1),
                        icon: const Icon(Icons.remove)),
                    Text('$qty'),
                    IconButton(
                        onPressed: () => setState(() => qty++),
                        icon: const Icon(Icons.add)),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                          hintText: _t('add_note', locale),
                          border: const OutlineInputBorder())),
                  const SizedBox(height: 12),
                  Text(_t('delivery', locale),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Row(children: [
                    Expanded(
                        child: RadioListTile(
                            value: 'delivery',
                            groupValue: deliveryMethod,
                            title: Text(_t('delivery', locale)),
                            onChanged: (v) =>
                                setState(() => deliveryMethod = v.toString()))),
                    Expanded(
                        child: RadioListTile(
                            value: 'pickup',
                            groupValue: deliveryMethod,
                            title: Text(_t('pickup', locale)),
                            onChanged: (v) =>
                                setState(() => deliveryMethod = v.toString()))),
                  ]),
                  const SizedBox(height: 8),
                  Text(_t('payment', locale),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  RadioListTile(
                      value: 'cod',
                      groupValue: paymentMethod,
                      title: Text(_t('cod', locale)),
                      onChanged: (v) =>
                          setState(() => paymentMethod = v.toString())),
                  RadioListTile(
                      value: 'online',
                      groupValue: paymentMethod,
                      title: Text(_t('online', locale)),
                      onChanged: (v) =>
                          setState(() => paymentMethod = v.toString())),
                  const SizedBox(height: 12),
                  Text(_t('rating', locale)),
                  const SizedBox(height: 6),
                  Row(children: List.generate(5, (i) => _buildStar(i))),
                  const SizedBox(height: 12),
                  TextField(
                      controller: reviewCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                          hintText: _t('review', locale),
                          border: const OutlineInputBorder())),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: couponCtrl,
                            decoration: InputDecoration(
                                labelText: _t('coupon', locale),
                                border: const OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                                content: Text(widget.locale == 'ar'
                                    ? 'تم حفظ كود الخصم مؤقتاً'
                                    : 'Coupon code saved (no validation)'))),
                        child: Text(_t('apply', locale))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                      controller: locationCtrl,
                      decoration: InputDecoration(
                          labelText: _t('location', locale),
                          hintText: widget.locale == 'ar'
                              ? 'اكتب موقعك (أو اضغط استخدم موقعي)'
                              : 'Type your location (or use current location)',
                          border: const OutlineInputBorder())),
                  const SizedBox(height: 6),
                  Row(children: [
                    ElevatedButton.icon(
                        onPressed: gettingLocation ? null : _useCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: Text(_t('use_location', locale))),
                    const SizedBox(width: 10),
                    if (gettingLocation)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                  ]),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: () {
                        final orderId =
                            DateTime.now().millisecondsSinceEpoch.toString();
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => OnlinePaymentPage(
                                    amount: _price * qty, orderId: orderId)));
                      },
                      child: const Text('💳 الدفع أونلاين')),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange),
                        onPressed: () {
                          final data = CartItemData(
                              item: widget.item,
                              type: type,
                              note: noteCtrl.text,
                              deliveryMethod: deliveryMethod,
                              paymentMethod: paymentMethod,
                              qty: qty,
                              rating: rating == 0 ? null : rating,
                              review: reviewCtrl.text.trim().isEmpty
                                  ? null
                                  : reviewCtrl.text.trim(),
                              couponCode: couponCtrl.text.trim().isEmpty
                                  ? null
                                  : couponCtrl.text.trim(),
                              discount: 0.0,
                              customerLocation: locationCtrl.text.trim().isEmpty
                                  ? null
                                  : locationCtrl.text.trim());
                          Navigator.pop(context, data);
                        },
                        child: Text(isAddMode
                            ? _t('add_to_cart', widget.locale)
                            : _t('order', widget.locale))),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// MAIN SCREEN
class MenuHomeScreen extends StatefulWidget {
  final String locale;
  final VoidCallback onToggleLocale;
  const MenuHomeScreen(
      {super.key, required this.locale, required this.onToggleLocale});

  @override
  State<MenuHomeScreen> createState() => _MenuHomeScreenState();
}

class _MenuHomeScreenState extends State<MenuHomeScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _offersBgController;

  List<MenuItemModel> _fullMenuList = [];
  List<MenuItemModel> offers = [];
  List<MenuItemModel> meals = [];
  List<MenuItemModel> sandwiches = [];
  List<MenuItemModel> mesahab = [];
  List<MenuItemModel> fries = [];
  List<MenuItemModel> sauces = [];
  List<MenuItemModel> drinks = [];
  List<MenuItemModel> familyMeals = [];
  List<MenuItemModel> singleMeals = [];
  List<MenuItemModel> addons = [];
  List<MenuItemModel> sanfr = [];
  List<MenuItemModel> nashville = [];

  final Location _locationService = Location();
  String _locale = 'ar';

  VideoPlayerController? _offersVideoController;
  bool _videoInitialized = false;
  bool _useNetworkVideoFallback = false;

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
    _tabController = TabController(length: 6, vsync: this);
    _offersBgController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat(reverse: true);
    _initOffersVideo();
    loadMenu();
  }

  @override
  void dispose() {
    _offersVideoController?.dispose();
    _tabController.dispose();
    _offersBgController.dispose();
    super.dispose();
  }

  Future<void> _initOffersVideo() async {
    try {
      _offersVideoController =
          VideoPlayerController.asset('assets/videos/fried_chicken.mp4');
      await _offersVideoController!.initialize();
      _offersVideoController!
        ..setLooping(true)
        ..setVolume(0.0)
        ..play();
      setState(() => _videoInitialized = true);
    } catch (e) {
      debugPrint('Asset video init failed: $e — trying network fallback');
      try {
        _useNetworkVideoFallback = true;
        _offersVideoController = VideoPlayerController.network(
            'https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4');
        await _offersVideoController!.initialize();
        _offersVideoController!
          ..setLooping(true)
          ..setVolume(0.0)
          ..play();
        setState(() => _videoInitialized = true);
      } catch (e2) {
        debugPrint('Network video init failed: $e2');
        setState(() => _videoInitialized = false);
      }
    }
  }

  Future<void> loadMenu() async {
    try {
      final data = await FirebaseMenuService().getMenu();
      setState(() {
        _fullMenuList = data;
        offers = data
            .where((i) => ((i.category ?? '').toLowerCase().contains('offer') ||
                (i.category ?? '').toLowerCase().contains('offers')))
            .toList();
        meals = data
            .where((i) =>
                ['meal', 'family'].contains((i.category ?? '').toLowerCase()))
            .toList();
        sandwiches = data
            .where((i) => (i.category ?? '').toLowerCase() == 'sandwiches')
            .toList();
        fries = data
            .where((i) => (i.category ?? '').toLowerCase() == 'fries')
            .toList();
        sauces = data
            .where((i) =>
                ['sauces', 'sauce'].contains((i.category ?? '').toLowerCase()))
            .toList();
        drinks = data
            .where((i) => (i.category ?? '').toLowerCase() == 'drinks')
            .toList();
        familyMeals = data
            .where((i) => (i.category ?? '').toLowerCase() == 'family')
            .toList();
        singleMeals = data
            .where((i) => (i.category ?? '').toLowerCase() == 'meal')
            .toList();
        addons = data
            .where((i) =>
                ['addon', 'addons'].contains((i.category ?? '').toLowerCase()))
            .toList();
        mesahab = data
            .where((i) => (i.category ?? '').toLowerCase() == 'mesahab')
            .toList();
        sanfr = data
            .where((i) => (i.category ?? '').toLowerCase() == 'fried')
            .toList();
        nashville = data
            .where((i) => (i.category ?? '').toLowerCase() == 'nashville')
            .toList();
      });
    } catch (e) {
      debugPrint('ERROR LOADING MENU: $e');
      setState(() {
        _fullMenuList = [];
        offers = [];
        meals = [];
        sandwiches = [];
        fries = [];
        sauces = [];
        drinks = [];
        familyMeals = [];
        singleMeals = [];
        addons = [];
        mesahab = [];
        sanfr = [];
        nashville = [];
      });
    }
  }

  void _addOfferToCartDirect(Map<String, dynamic> data, {int qty = 1}) {
    final prov = Provider.of<CartProvider>(context, listen: false);
    final title = (data['title'] ?? '').toString();
    final price = double.tryParse(
            (data['price'] ?? data['price_str'] ?? '0').toString()) ??
        0.0;
    final image = (data['image'] ?? '').toString();
    final id = (data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString())
        .toString();

    final cartItem = CartItem(
      id: 'offer_$id',
      menuItemId: 'offer_$id',
      titleEn: title,
      titleAr: title,
      price: price,
      qty: qty,
      selectedOption: null,
      options: [],
      type: 'offer',
      note: '',
      imagePath: image,
    );
    prov.addItem(cartItem);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t('add_to_cart', _locale)} • $title')));
  }

  Future<void> _openOfferOptions(Map<String, dynamic> data) async {
    final locale = widget.locale;
    final result = await showModalBottomSheet<CartItemData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.25,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: ItemOptionSheet(
              offerData: data,
              locale: locale,
              addToCartMode: true,
              scrollController: controller,
            ),
          ),
        ),
      ),
    );

    if (result == null) return;

    final prov = Provider.of<CartProvider>(context, listen: false);
    final title = (data['title'] ?? '').toString();
    final price = double.tryParse(
            (data['price'] ?? data['price_str'] ?? '0').toString()) ??
        0.0;
    final image = (data['image'] ?? '').toString();
    final id = (data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString())
        .toString();

    final combinedNote = (result.note ?? '') +
        ((result.rating != null || (result.review ?? '').isNotEmpty)
            ? '\n'
            : '');
    final cartItem = CartItem(
      id: 'offer_$id',
      menuItemId: 'offer_$id',
      titleEn: title,
      titleAr: title,
      price: price,
      qty: result.qty,
      selectedOption: null,
      options: [],
      type: 'offer',
      note: combinedNote +
          (result.rating != null ? 'Rating: ${result.rating}\n' : '') +
          ((result.review ?? '').isNotEmpty
              ? 'Review: ${result.review}\n'
              : '') +
          ((result.customerLocation ?? '').isNotEmpty
              ? 'Location: ${result.customerLocation}\n'
              : '') +
          ((result.couponCode ?? '').isNotEmpty
              ? 'Coupon: ${result.couponCode}\n'
              : ''),
      imagePath: image,
    );
    prov.addItem(cartItem);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${_t('add_to_cart', widget.locale)} • ${widget.locale == 'ar' ? title : title}')));
  }

  Future<void> _placeOrderNow(BuildContext context, MenuItemModel item) async {
    final locale = widget.locale;
    final result = await showModalBottomSheet<CartItemData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.25,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: ItemOptionSheet(
                item: item,
                locale: locale,
                addToCartMode: false,
                scrollController: controller),
          ),
        ),
      ),
    );

    if (result == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              widget.locale == 'ar' ? 'يرجى تسجيل الدخول' : 'Please sign in')));
      return;
    }

    try {
      final ordersCol = FirebaseFirestore.instance.collection('orders');
      final doc = ordersCol.doc();
      final orderItem = {
        'itemId': item.id ?? '',
        'titleEn': item.titleEn ?? '',
        'titleAr': item.titleAr ?? '',
        'price': (item.price ?? 0.0),
        'qty': result.qty,
        'note': result.note ?? '',
        'type': result.type,
      };
      final double totalBefore = (item.price ?? 0.0) * result.qty;
      final double discount =
          result.couponCode != null ? (result.discount ?? 0.0) : 0.0;
      final double totalAfter =
          (totalBefore - discount).clamp(0.0, double.infinity);
      final orderMap = {
        'id': doc.id,
        'userId': user.uid,
        'items': [orderItem],
        'totalBeforeDiscount': totalBefore,
        'discount': discount,
        'total': totalAfter,
        'deliveryMethod': result.deliveryMethod,
        'paymentMethod': result.paymentMethod,
        'status': 'preparing',
        'createdAt': FieldValue.serverTimestamp(),
        'rating': result.rating,
        'review': result.review ?? '',
        'customerLocation': result.customerLocation ?? '',
        'couponCode': result.couponCode ?? '',
      };
      await doc.set(orderMap);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.locale == 'ar'
              ? 'تم الطلب بنجاح'
              : 'Order placed successfully'),
          backgroundColor: Colors.green));
      if (mounted)
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => OrderTrackingPage(orderId: doc.id)));
    } catch (e) {
      debugPrint('Order creation failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.locale == 'ar'
              ? 'فشل إنشاء الطلب'
              : 'Failed to create order'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _openItemOptions(MenuItemModel item) async {
    final locale = widget.locale;
    final result = await showModalBottomSheet<CartItemData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.25,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: ItemOptionSheet(
                  item: item,
                  locale: locale,
                  addToCartMode: true,
                  scrollController: controller)),
        ),
      ),
    );

    if (result == null) return;

    final prov = Provider.of<CartProvider>(context, listen: false);
    String extraInfo = '';
    if (result.rating != null) extraInfo += 'Rating: ${result.rating}\n';
    if ((result.review ?? '').isNotEmpty)
      extraInfo += 'Review: ${result.review}\n';
    if ((result.customerLocation ?? '').isNotEmpty)
      extraInfo += 'Location: ${result.customerLocation}\n';
    if ((result.couponCode ?? '').isNotEmpty)
      extraInfo += 'Coupon: ${result.couponCode}\n';
    final combinedNote =
        (result.note ?? '') + (extraInfo.isNotEmpty ? '\n$extraInfo' : '');
    final cartItem = CartItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      menuItemId: item.id ?? '',
      titleEn: item.titleEn ?? '',
      titleAr: item.titleAr ?? '',
      price: (item.price ?? 0.0),
      qty: result.qty,
      selectedOption: null,
      options: item.options,
      type: result.type,
      note: combinedNote,
      imagePath: (item.imagePath?.isNotEmpty == true)
          ? item.imagePath!
          : (item.image ?? ''),
    );
    prov.addItem(cartItem);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${_t('add_to_cart', widget.locale)} • ${widget.locale == 'ar' ? (item.titleAr ?? '') : (item.titleEn ?? '')}')));
  }

  void _showDescriptionDialog(BuildContext context, MenuItemModel? item,
      {Map<String, dynamic>? offerData}) {
    final locale = widget.locale;
    final title = item != null
        ? (locale == 'ar' ? (item.titleAr ?? '') : (item.titleEn ?? ''))
        : (offerData?['title'] ?? '');
    final desc = item != null
        ? (locale == 'ar'
            ? (item.descriptionAr ?? 'لا يوجد وصف')
            : (item.descriptionEn ?? 'No description'))
        : (offerData?['desc'] ?? '');
    final imagePath = item != null
        ? (item.imagePath ?? item.image)
        : (offerData?['image'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((imagePath ?? '').toString().isNotEmpty)
                  SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: (imagePath!).toString().startsWith('http')
                          ? Image.network(imagePath, fit: BoxFit.contain)
                          : Image.asset(imagePath, fit: BoxFit.contain)),
                const SizedBox(height: 12),
                Text(desc),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('close', widget.locale)))
        ],
      ),
    );
  }

  void _showOfferDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(data['title'] ?? ''),
        content: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((data['image'] ?? '').toString().isNotEmpty)
                  SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: (data['image'] ?? '').toString().startsWith('http')
                          ? Image.network(data['image'], fit: BoxFit.contain)
                          : Image.asset(data['image'], fit: BoxFit.contain)),
                const SizedBox(height: 12),
                Text(data['desc'] ?? ''),
                const SizedBox(height: 12),
                if ((data['discount'] ?? '').toString().isNotEmpty)
                  Text('Discount: ${data['discount']}',
                      style: const TextStyle(color: Colors.red)),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('close', _locale))),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const OffersPage()));
              },
              child: Text(_t('offers', _locale))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openOfferOptions(data);
            },
            child: Text(widget.locale == 'ar' ? 'اطلب العرض' : 'Order Offer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final cartProv = Provider.of<CartProvider>(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: null,
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.white, Color.fromARGB(255, 255, 152, 0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.max, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                const SizedBox(width: 6),
                Text(_t('menu', locale),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const Spacer(),
                IconButton(
                    onPressed: widget.onToggleLocale,
                    icon: const Icon(Icons.language, color: Colors.black87)),
                IconButton(
                    onPressed: () => Navigator.pushNamed(context, '/offers'),
                    icon: const Icon(Icons.local_offer, color: Colors.black87)),
                Stack(children: [
                  IconButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const CartPage())),
                      icon: const Icon(Icons.shopping_cart,
                          color: Colors.black87)),
                  Positioned(
                      right: 4,
                      top: 4,
                      child: CircleAvatar(
                          radius: 9,
                          backgroundColor: Colors.red,
                          child: Text('${cartProv.count}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10))))
                ]),
                IconButton(
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                    icon: const Icon(Icons.settings, color: Colors.black87)),
              ]),
            ),
            TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.deepOrange,
                labelColor: Colors.deepOrange,
                unselectedLabelColor: Colors.black54,
                tabs: [
                  Tab(text: _t('offers', locale)),
                  Tab(text: _t('meals', locale)),
                  Tab(text: _t('sandwiches', locale)),
                  Tab(text: _t('fries', locale)),
                  Tab(text: _t('sauces', locale)),
                  Tab(text: _t('additions', locale)),
                ]),
            Expanded(
              child: _fullMenuList.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.orange))
                  : TabBarView(controller: _tabController, children: [
                      _buildOffersTab(),
                      _buildMealsWithSubTabs(),
                      _buildSandwichesWithSubTabs(),
                      _buildGrid(fries),
                      _buildGrid(sauces),
                      _buildGrid(addons),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildOffersTab() {
    return Stack(fit: StackFit.expand, children: [
      if (_videoInitialized && _offersVideoController != null)
        Positioned.fill(
            child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                    width: _offersVideoController!.value.size.width,
                    height: _offersVideoController!.value.size.height,
                    child: VideoPlayer(_offersVideoController!))))
      else
        Positioned.fill(
            child: Container(
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
          Colors.orange.shade200,
          Colors.deepOrange.shade400
        ])))),
      Positioned.fill(child: Container(color: Colors.black.withOpacity(0.32))),
      SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.0, 10.0, 12.0,
              12.0 + MediaQuery.of(context).viewPadding.bottom),
          child: Column(mainAxisSize: MainAxisSize.max, children: [
            // keep top spacing for balance
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('offers')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.white));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildOffersHighlighted();
                  }

                  final docs = snapshot.data!.docs;
                  final display = docs.take(8).toList();

                  const crossCount = 2;
                  final childAspect = 0.68; // a bit taller cards

                  return GridView.builder(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewPadding.bottom + 16,
                        left: 12,
                        right: 12,
                        top: 4),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      childAspectRatio: childAspect,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: display.length,
                    itemBuilder: (context, i) {
                      final doc = display[i];
                      final data = doc.data();
                      final image = (data['image'] ?? '').toString();
                      final title = (data['title'] ?? '').toString();
                      final desc = (data['desc'] ?? '').toString();
                      final discount = (data['discount'] ?? '').toString();
                      final priceRaw =
                          (data['price'] ?? data['price_str'] ?? '').toString();
                      final price = priceRaw.isNotEmpty ? priceRaw : null;

                      return Card(
                        color: Colors.white.withOpacity(0.95),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 8,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Image area: show full image (contain), clickable to view description
                              Expanded(
                                flex: 6,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12)),
                                  child: Stack(fit: StackFit.expand, children: [
                                    InkWell(
                                      onTap: () => _showDescriptionDialog(
                                          context, null,
                                          offerData: data),
                                      child: Container(
                                        color: Colors.grey[50],
                                        child: (image.isNotEmpty &&
                                                image.startsWith('http'))
                                            ? Image.network(image,
                                                fit: BoxFit.contain,
                                                width: double.infinity,
                                                height: double.infinity)
                                            : (image.isNotEmpty
                                                ? Image.asset(image,
                                                    fit: BoxFit.contain,
                                                    width: double.infinity,
                                                    height: double.infinity)
                                                : const SizedBox.shrink()),
                                      ),
                                    ),
                                    // discount ribbon
                                    if (discount.isNotEmpty)
                                      Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  color: Colors.redAccent,
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              child: Text(discount,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12)))),
                                    // subtle bottom gradient for title legibility
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black26
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                              // Info area (robust: title Expanded, price constrained)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15)),
                                          ),
                                          const SizedBox(width: 8),
                                          if (price != null)
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                minWidth: 0,
                                                maxWidth: 96,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color:
                                                      Colors.deepOrange.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '$price ج.م',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      color: Colors.deepOrange,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(desc,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54)),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 38,
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _openOfferOptions(data),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.deepOrange,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                    Icons.add_shopping_cart,
                                                    size: 16),
                                                const SizedBox(width: 8),
                                                Text(_t('add_to_cart',
                                                    widget.locale)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ]),
                              ),
                            ]),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildOffersHighlighted() {
    final t = _offersBgController.value;
    final c1 =
        Color.lerp(Colors.orange.shade200, Colors.deepOrange.shade700, t)!
            .withOpacity(0.95);
    final c2 = Color.lerp(Colors.yellow.shade200, Colors.orange.shade200, t)!
        .withOpacity(0.95);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [c1, c2],
              begin: Alignment(-1.0 + t, -1.0),
              end: Alignment(1.0 - t, 1.0))),
      child: Center(
        child: SingleChildScrollView(
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                    height: 160,
                    child: Image.asset(
                        'assets/images/fried_chicken_placeholder.png',
                        fit: BoxFit.contain)),
                const SizedBox(height: 12),
                Text(
                    widget.locale == 'ar'
                        ? 'عرض فرايد تشيكن مميز'
                        : 'Special Fried Chicken Offer',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                Text(
                    widget.locale == 'ar'
                        ? 'عرض خاص لفترة محدودة — خصومات ووجبات عائلية'
                        : 'Limited time offer — family packs & discounts',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 14),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const OffersPage())),
                      child: Text(widget.locale == 'ar'
                          ? 'شاهد العروض'
                          : 'View Offers')),
                  const SizedBox(width: 12),
                  OutlinedButton(
                      onPressed: () => _tabController.animateTo(1),
                      child: Text(widget.locale == 'ar'
                          ? 'اذهب للمنيو'
                          : 'Go to Menu')),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<MenuItemModel> list) {
    const crossCount = 2;
    final childAspect = 0.78;

    return GridView.builder(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom + 12,
          left: 12,
          right: 12,
          top: 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          childAspectRatio: childAspect,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final it = list[index];
        return Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Expanded(
              flex: 6,
              child: InkWell(
                onTap: () => _showDescriptionDialog(context, it),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Stack(fit: StackFit.expand, children: [
                    Container(
                        color: Colors.white,
                        child: (it.imagePath?.isNotEmpty ?? false)
                            ? (it.imagePath!.startsWith('http')
                                ? Image.network(it.imagePath!,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity)
                                : Image.asset(it.imagePath!,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity))
                            : ((it.image?.isNotEmpty ?? false)
                                ? Image.asset(it.image!,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity)
                                : const SizedBox.shrink())),
                    Positioned.fill(
                        child: Container(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [
                          Colors.transparent,
                          Colors.black26
                        ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter)))),
                    // "View" badge removed as requested — tapping image opens the description
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            widget.locale == 'ar'
                                ? (it.titleAr ?? '')
                                : (it.titleEn ?? ''),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text('${(it.price ?? 0).toString()} ج.م',
                            style: const TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: () => _openItemOptions(it),
                        icon: const Icon(Icons.add_shopping_cart, size: 14),
                        label: Text(_t('add_to_cart', widget.locale),
                            style: const TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            minimumSize: const Size.fromHeight(36)),
                      ),
                    ),
                  ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildSandwichesWithSubTabs() {
    final sandwichesFriedChicken = _fullMenuList
        .where((item) => (item.category ?? '').toLowerCase() == 'fried')
        .toList();
    final nashvilleSandwiches = _fullMenuList
        .where((item) => (item.category ?? '').toLowerCase() == 'nashville')
        .toList();
    final sandwichesRoll = _fullMenuList
        .where((item) => (item.category ?? '').toLowerCase() == 'sandwich_roll')
        .toList();

    return DefaultTabController(
      length: 3,
      child: Column(mainAxisSize: MainAxisSize.max, children: [
        TabBar(
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.deepOrange,
            tabs: [
              Tab(
                  text: widget.locale == 'ar'
                      ? "سندوتشات فرايد تشيكن"
                      : 'Sandwiches Fried Chicken'),
              Tab(
                  text: widget.locale == 'ar'
                      ? "سندوتشات ناشفيل"
                      : 'Nashville Sandwiches'),
              Tab(
                  text: widget.locale == 'ar'
                      ? "سندوتشات رول"
                      : 'Sandwiches Roll'),
            ]),
        Expanded(
            child: TabBarView(children: [
          _buildGrid(sandwichesFriedChicken),
          _buildGrid(nashvilleSandwiches),
          _buildGrid(sandwichesRoll)
        ])),
      ]),
    );
  }

  Widget _buildMealsWithSubTabs() {
    final single = _fullMenuList
        .where((item) => (item.category ?? '').toLowerCase() == 'meal')
        .toList();
    final family = _fullMenuList
        .where((item) => (item.category ?? '').toLowerCase() == 'family')
        .toList();
    final boneless = _fullMenuList
        .where((item) => (item.category ?? '').toLowerCase() == 'boneless')
        .toList();
    final mesahabList = _fullMenuList
        .where((item) => (item.category ?? '').toLowerCase() == 'mesahab')
        .toList();

    return DefaultTabController(
      length: 4,
      child: Column(mainAxisSize: MainAxisSize.max, children: [
        TabBar(
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.deepOrange,
            tabs: [
              Tab(text: widget.locale == 'ar' ? 'فردية' : 'Single'),
              Tab(text: widget.locale == 'ar' ? 'مخلية' : 'Boneless'),
              Tab(text: widget.locale == 'ar' ? 'عائلية' : 'Family'),
              Tab(text: widget.locale == 'ar' ? "مسحب" : 'mesahab'),
            ]),
        Expanded(
            child: TabBarView(children: [
          _buildGrid(single),
          _buildGrid(boneless),
          _buildGrid(family),
          _buildGrid(mesahabList)
        ])),
      ]),
    );
  }
}
