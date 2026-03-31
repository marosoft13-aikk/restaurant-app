import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/menu_item_model.dart';
import '../services/firebase_menu_service.dart';

class MenuProvider extends ChangeNotifier {
  final FirebaseMenuService _service = FirebaseMenuService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<MenuItemModel> _items = [];
  List<MenuItemModel> get items => List.unmodifiable(_items);

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  StreamSubscription<List<MenuItemModel>>? _sub;

  MenuProvider() {
    _subscribeStream();
  }

  void _subscribeStream() {
    _loading = true;
    notifyListeners();
    _sub = _service.menuStream().listen((list) {
      _items = list;
      _loading = false;
      _error = null;
      notifyListeners();
    }, onError: (e, st) {
      _error = e?.toString() ?? 'unknown';
      _loading = false;
      notifyListeners();
      if (kDebugMode) {
        debugPrint('MenuProvider stream error: $e\n$st');
      }
    });
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      final list = await _service.getMenu(removeOrderBy: true);
      _items = list;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addOrUpdateItem(MenuItemModel item) async {
    await _service.addOrUpdateItem2(item);
    // stream will update items automatically
  }

  Future<void> deleteItem(String id) async {
    await _service.deleteItem(id);
    // stream will update items automatically
  }

  Future<void> clearAll() async {
    await _service.clearAll();
  }

  /// Import a local list of MenuItemModel.
  /// If overwrite==false, existing doc ids are kept (skipped).
  Future<void> importLocalMenuFromList(List<MenuItemModel> localList,
      {required bool overwrite}) async {
    final col = _db.collection(_service.collectionName);
    final snap = await col.get();
    final existingIds = snap.docs.map((d) => d.id).toSet();
    final batch = _db.batch();

    for (final localItem in localList) {
      final id = localItem.id;
      final docRef = col.doc(id);
      if (!overwrite && existingIds.contains(id)) continue;
      final map = localItem.toMap();
      map['createdAt'] = map['createdAt'] ?? FieldValue.serverTimestamp();
      batch.set(docRef, map, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Reorder items by providing list of ids in the desired order.
  Future<void> reorderCategoryItems(List<MenuItemModel> orderedItems) async {
    final updates = <Map<String, dynamic>>[];
    for (var i = 0; i < orderedItems.length; i++) {
      updates.add({'id': orderedItems[i].id, 'order': i});
    }
    await _service.batchUpdateItems(updates);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final List<MenuItemModel> fullMenuItems = [
  MenuItemModel(
      id: 'meal_2pcs',
      name: 'وجبة التوفير',
      description: "قطعة دبوس+قطعة استربس +2خبز+بطاطس+تومية او كول سلو",
      price: 85.0,
      imagePath: 'assets/images/eltawfir.png',
      category: 'meal',
      titleEn: "Value Meal",
      titleAr: "وجبة التوفير",
      image: 'assets/images/eltawfir.png',
      descriptionAr:
          'وجبة اقتصادية تحتوي على قطعة دبوس وقطعة استربس مع 2 خبز، بطاطس، وتومية أو كول سلو.',
      descriptionEn:
          ' An economical meal featuring one drumstick and one strip, served with 2 breads, fries, and your choice of toum or coleslaw.'),

  MenuItemModel(
    id: 'meal_3',
    name: "وجبة فلاي وينجز",
    description: " 3 قطع اجنحة+2 خبز+ بطاطس+ تومية او كول سلو",
    price: 90.0,
    imagePath: 'assets/images/wings.png',
    category: 'meal',
    titleEn: "Flywings Meal",
    titleAr: "وجبة فلاي وينجز",
    image: 'assets/images/wings.png',
    descriptionAr:
        'وجبة مميزة تحتوي على 3 قطع من الأجنحة المقرمشة، مع 2 خبز، بطاطس، وتومية أو كول سلو.',
    descriptionEn:
        ' A special meal featuring 3 crispy wing pieces, served with 2 breads, fries, and your choice of toum or coleslaw.',
  ),

  MenuItemModel(
      id: 'meal_2pcs',
      name: 'وجبة قطعتين',
      description: "2 قطعة بروست +2 خبز + بطاطس + تومية او كول سلو",
      price: 110.0,
      imagePath: 'assets/images/ktetin.png',
      category: 'meal',
      titleEn: '2 Pcs Meal',
      titleAr: 'وجبة قطعتين',
      image: 'assets/images/ktetin.png',
      descriptionAr:
          '2 قطع من البروست المقرمشة مع 2 خبز، بطاطس، وتومية أو كول سلو.',
      descriptionEn:
          '2 crispy fried chicken pieces served with 2 breads, fries, and your choice of toum or coleslaw.'),

  MenuItemModel(
    id: 'meal_3pcs',
    name: 'وجبة 3 قطع',
    description: "3 قطع بروست+ 2 خبز +بطاطس + تومية او كولسلو",
    price: 155.0,
    imagePath: 'assets/images/3pcs.png',
    category: 'meal',
    titleEn: '3 Pcs Meal',
    titleAr: 'وجبة 3 قطع',
    image: 'assets/images/3pcs.png',
    descriptionAr:
        '3 قطع من البروست المقرمشة مع 2 خبز، بطاطس، وتومية أو كول سلو.',
    descriptionEn:
        '3 crispy fried chicken pieces served with 2 breads, fries, and your choice of toum or coleslaw.',
  ),
  MenuItemModel(
    id: 'meal_4pcs',
    name: 'وجبة 4 قطع',
    description: " 4قطع بروست+2خبز +بطاطس+تومية+كول سلو",
    price: 195.0,
    imagePath: 'assets/images/4pcs.png',
    category: 'meal',
    titleEn: '4 Pcs Meal',
    titleAr: 'وجبة 4 قطع',
    image: 'assets/images/4pcs.png',
    descriptionAr:
        '4 قطع من البروست المقرمشة مع 2 خبز، بطاطس، وتومية أو كول سلو.',
    descriptionEn:
        '4 crispy fried chicken pieces served with 2 breads, fries, and your choice of toum or coleslaw.',
  ),

  MenuItemModel(
    id: 'meal_prostaki',
    name: 'وجبة بروستاكي',
    description: "2قطع بروست+2استربس+ارز+2خبز+بطاطس+تومية او كول سلو",
    price: 185.0,
    imagePath: 'assets/images/prostaki.png',
    category: 'meal',
    titleEn: 'Prostaki Meal',
    titleAr: 'وجبة بروستاكي',
    image: 'assets/images/prostaki.png',
    descriptionAr:
        'وجبة مميزة تحتوي على 2 قطعة من البروست، 2 استربس، أرز، 2 خبز، بطاطس، وتومية أو كول سلو.',
    descriptionEn:
        'A special meal featuring 2 pieces of fried chicken, 2 strips, rice, 2 breads, fries, and your choice of toum or coleslaw.',
  ),

  MenuItemModel(
      id: 'meal_5pcs',
      name: 'وجبة 5 قطع',
      description: "٥قطع بروست+٣خبز +بطاطس+تومية+كول سلو",
      price: 235.0,
      imagePath: 'assets/images/5pcs.png',
      category: 'meal',
      titleEn: '5 Pcs Meal',
      titleAr: 'وجبة 5 قطع',
      image: 'assets/images/5pcs.png',
      descriptionAr:
          '٥ قطع من البروست المقرمشة مع ٣ خبز، بطاطس، وتومية أو كول سلو.',
      descriptionEn:
          '5 crispy fried chicken pieces served with 3 breads, fries, and your choice of toum or coleslaw.'),

  MenuItemModel(
      id: 'meal_6pcs',
      name: 'وجبة 6 قطع',
      description: '6 قطع دجاج مقلي + بطاطس + مشروب',
      price: 275.0,
      imagePath: 'assets/images/6pcs.png',
      category: 'meal',
      titleEn: '6 Pcs Meal',
      titleAr: 'وجبة 6 قطع',
      image: 'assets/images/6pcs.png',
      descriptionAr: '6 قطع من الدجاج المقلي مع بطاطس ومشروب.',
      descriptionEn:
          '6 crispy fried chicken pieces served with fries and a drink.'),

  // 🍗 وجبات ستربس
  MenuItemModel(
      id: 'strips_3',
      name: 'وجبة استربس 3 قطع',
      description: "٣ استربس+٢خبز +تومية او كول سلو +بطاطس",
      price: 105.0,
      imagePath: 'assets/images/strips_3.png',
      category: 'boneless',
      titleEn: 'Strips 3 pcs',
      titleAr: 'استربس 3 قطع',
      image: 'assets/images/strips_3.png',
      descriptionAr:
          'وجبة تحتوي على 3 قطع استربس مع 2 خبز، بطاطس، وتومية أو كول سلو.',
      descriptionEn:
          'A meal featuring 3 strips served with 2 breads, fries, and your choice of toum or coleslaw.'),
  MenuItemModel(
      id: 'strips_5',
      name: 'وجبة استربس 5 قطع',
      description: "٥ استربس +٣خبز +تومية +كولسلو +بطاطس",
      price: 160.0,
      imagePath: 'assets/images/strips_5.png',
      category: 'boneless',
      titleEn: 'Strips 5 pcs',
      titleAr: 'استربس 5 قطع',
      image: 'assets/images/strips_5.png',
      descriptionAr:
          'وجبة تحتوي على 5 قطع استربس مع 3 خبز، بطاطس، وتومية أو كول سلو.',
      descriptionEn:
          'A meal featuring 5 strips served with 3 breads, fries, and your choice of toum or coleslaw.'),
  MenuItemModel(
      id: 'strips_9',
      name: 'وجبة استربس 9 قطع',
      description: "٩استربس+٥خبز +بطاطس + تومية كبيرة +كول سلو كبير",
      price: 240.0,
      imagePath: 'assets/images/strips_9.png',
      category: 'boneless',
      titleEn: 'Strips 9 pcs',
      titleAr: 'استربس 9 قطع',
      image: 'assets/images/strips_9.png',
      descriptionAr:
          'وجبة تحتوي على 9 قطع استربس مع 5 خبز، بطاطس، وتومية كبيرة أو كول سلو كبير.',
      descriptionEn:
          'A meal featuring 9 strips served with 5 breads, fries, and your choice of large toum or large coleslaw.'),
  MenuItemModel(
      id: 'strips_12',
      name: 'وجبة ستربس 12 قطع',
      description: "١٢ استربس +٧خبز+بطاطس+كول سلو كبير +تومية كبير",
      price: 355.0,
      imagePath: 'assets/images/strips_12.png',
      category: 'boneless',
      titleEn: 'Strips 12 pcs',
      titleAr: 'استربس 12 قطع',
      image: 'assets/images/strips_12.png',
      descriptionAr:
          'وجبة تحتوي على 12 قطعة استربس مع 7 خبز، بطاطس، وكول سلو كبير أو تومية كبيرة.',
      descriptionEn:
          'A meal featuring 12 strips served with 7 breads, fries, and your choice of large toum or large coleslaw.'),
  MenuItemModel(
      id: 'strips_16',
      name: 'وجبة ستربس 16 قطع',
      description: "١٦ استربس +١٠خبز+بطاطس+٢كول سلو كبير +٢تومية كبير",
      price: 460.0,
      imagePath: 'assets/images/strips_16.png',
      category: 'boneless',
      titleEn: 'Strips 16 pcs',
      titleAr: 'استربس 16 قطع',
      image: 'assets/images/strips_16.png',
      descriptionAr:
          'وجبة تحتوي على 16 قطعة استربس مع 10 خبز، بطاطس، و2 كول سلو كبير أو 2 تومية كبيرة.',
      descriptionEn:
          'A meal featuring 16 strips served with 10 breads, fries, and your choice of 2 large toum or 2 large coleslaw.'),
  MenuItemModel(
      id: 'strips_20',
      name: 'وجبة ستربس 20 قطع',
      description: "٢٠ استربس +١٢خبز+بطاطس+٢كول سلو كبير +٢تومية كبير",
      price: 500.0,
      imagePath: 'assets/images/strips_20.png',
      category: 'boneless',
      titleEn: 'Strips 20 pcs',
      titleAr: 'استربس 20 قطع',
      image: 'assets/images/strips_20.png',
      descriptionAr:
          'وجبة تحتوي على 20 قطعة استربس مع 12 خبز، بطاطس، و2 كول سلو كبير أو 2 تومية كبيرة.',
      descriptionEn:
          'A meal featuring 20 strips served with 12 breads, fries, and your choice of 2 large toum or 2 large coleslaw.'),

  // 👨‍👩‍👧‍👦 وجبات عائلية

  MenuItemModel(
      id: 'fam_7pcs',
      name: 'وجبة 7 قطع',
      description: '7 قطع فراخ + بطاطس + كول سلو + تومية + كايزر',
      price: 315.0,
      imagePath: 'assets/images/fam_7pcs.png',
      category: 'family',
      titleEn: 'Family Meal 7 pcs',
      titleAr: 'وجبة 7 قطع',
      image: 'assets/images/fam_7pcs.png',
      descriptionAr:
          'وجبة تحتوي على 7 قطع فراخ مع بطاطس، كول سلو، تومية، وكايزر.',
      descriptionEn:
          'A meal featuring 7 pieces of chicken served with fries, coleslaw, toum, and a Kaiser roll.'),

  MenuItemModel(
      id: 'fam_family',
      name: 'وجبة فاميلي',
      description: '9 قطع فراخ + بطاطس + كول سلو + تومية + كايزر',
      price: 380.0,
      imagePath: 'assets/images/fam_family.png',
      category: 'family',
      titleEn: 'Family Meal',
      titleAr: 'وجبة فاميلي',
      image: 'assets/images/fam_family.png',
      descriptionAr:
          'وجبة تحتوي على 9 قطع فراخ مع بطاطس، كول سلو، تومية، وكايزر.',
      descriptionEn:
          'A meal featuring 9 pieces of chicken served with fries, coleslaw, toum, and a Kaiser roll.'),

  MenuItemModel(
      id: 'fam_elshela',
      name: "وجبة الشلة",
      description: '12 قطعة فراخ + بطاطس + 2 كول سلو + تومية + كايزر',
      price: 460.0,
      imagePath: 'assets/images/fam_elshela.png',
      category: 'family',
      titleEn: 'El Shela Meal',
      titleAr: "وجبة الشلة",
      image: 'assets/images/fam_elshela.png',
      descriptionAr:
          'وجبة تحتوي على 12 قطعة فراخ مع بطاطس، 2 كول سلو، تومية، وكايزر.',
      descriptionEn:
          'A meal featuring 12 pieces of chicken served with fries, 2 coleslaw, toum, and a Kaiser roll.'),

  MenuItemModel(
      id: 'fam_superfamily',
      name: 'سوبر فاميلي',
      description: '15 قطعة فراخ + بطاطس + 2 كول سلو + تومية + كايزر',
      price: 520.0,
      imagePath: 'assets/images/fam_superfamily.png',
      category: 'family',
      titleEn: 'Super Family Meal',
      titleAr: 'سوبر فاميلي',
      image: 'assets/images/fam_superfamily.png',
      descriptionAr:
          'وجبة تحتوي على 15 قطعة فراخ مع بطاطس، 2 كول سلو، تومية، وكايزر.',
      descriptionEn:
          'A meal featuring 15 pieces of chicken served with fries, 2 coleslaw, toum, and a Kaiser roll.'),

  MenuItemModel(
      id: 'fam_ellama',
      name: 'وجبة اللمة',
      description: '16 قطعة فراخ + بطاطس وسط + كول سلو + تومية + كايزر + أرز',
      price: 650.0,
      imagePath: 'assets/images/fam_ellama.png',
      category: 'family',
      titleEn: 'Family Meal ElLama',
      titleAr: 'وجبة العيلة',
      image: 'assets/images/fam_ellama.png',
      descriptionAr:
          'وجبة تحتوي على 16 قطعة فراخ مع بطاطس وسط، كول سلو، تومية، وكايزر، وأرز.',
      descriptionEn:
          'A meal featuring 16 pieces of chicken served with medium fries, coleslaw, toum, a Kaiser roll, and rice.'),

  MenuItemModel(
      id: 'fam_elgamo',
      name: 'وجبة الجامبو',
      description: '20 قطعة فراخ + بطاطس وسط + كول سلو + تومية + كايزر + أرز',
      price: 850.0,
      imagePath: 'assets/images/fam_elgamo.png',
      category: 'family',
      titleEn: 'Jumbo Family Meal',
      titleAr: 'وجبة الجامبو',
      image: 'assets/images/fam_elgamo.png',
      descriptionAr:
          'وجبة تحتوي على 20 قطعة فراخ مع بطاطس وسط، كول سلو، تومية، وكايزر، وأرز.',
      descriptionEn:
          'A meal featuring 20 pieces of chicken served with medium fries, coleslaw, toum, a Kaiser roll, and rice.'),

  //مسحب
  MenuItemModel(
      id: 'mesahab_3pcs',
      name: 'مسحب 3 قطع',
      description: '3 قطع مسحب + بطاطس + كول سلو + تومية + كايزر',
      price: 150.0,
      imagePath: 'assets/images/mesahab_3pcs.png',
      category: 'mesahab',
      titleEn: 'Mesahab 3 pcs',
      titleAr: 'مسحب 3 قطع',
      image: 'assets/images/mesahab_3pcs.png',
      descriptionAr:
          'وجبة تحتوي على 3 قطع مسحب مع بطاطس، كول سلو، تومية، وكايزر.',
      descriptionEn:
          'A meal featuring 3 pieces of mesahab served with fries, coleslaw, toum, and a Kaiser roll.'),
  MenuItemModel(
      id: 'mesahab_5pcs',
      name: 'مسحب 5 قطع',
      description: '5 قطع مسحب + بطاطس + كول سلو + تومية + كايزر',
      price: 180.0,
      imagePath: 'assets/images/mesahab_5pcs.png',
      category: 'mesahab',
      titleEn: 'Mesahab 5 pcs',
      titleAr: 'مسحب 5 قطع',
      image: 'assets/images/mesahab_5pcs.png',
      descriptionAr:
          'وجبة تحتوي على 5 قطع مسحب مع بطاطس، كول سلو، تومية، وكايزر.',
      descriptionEn:
          'A meal featuring 5 pieces of mesahab served with fries, coleslaw, toum, and a Kaiser roll.'),
  MenuItemModel(
      id: 'mesahab_8pcs',
      name: 'مسحب 8 قطع',
      description: '8 قطع مسحب + بطاطس + كول سلو + تومية + كايزر',
      price: 280.0,
      imagePath: 'assets/images/mesahab_8pcs.png',
      category: 'mesahab',
      titleEn: 'Mesahab 8 pcs',
      titleAr: 'مسحب 8 قطع',
      image: 'assets/images/mesahab_8pcs.png',
      descriptionAr:
          'وجبة تحتوي على 8 قطع مسحب مع بطاطس، كول سلو، تومية، وكايزر.',
      descriptionEn:
          'A meal featuring 8 pieces of mesahab served with fries, coleslaw, toum, and a Kaiser roll.'),
  MenuItemModel(
      id: 'mesahab_16pcs',
      name: 'مسحب 16 قطع',
      description: '16 قطعة مسحب + بطاطس + كول سلو + تومية + كايزر',
      price: 460.0,
      imagePath: 'assets/images/mesahab_16pcs.png',
      category: 'mesahab',
      titleEn: 'Mesahab 16 pcs',
      titleAr: 'مسحب 16 قطع',
      image: 'assets/images/mesahab_16pcs.png',
      descriptionAr:
          'وجبة تحتوي على 16 قطعة مسحب مع بطاطس، كول سلو، تومية، وكايزر.',
      descriptionEn:
          'A meal featuring 16 pieces of mesahab served with fries, coleslaw, toum, and a Kaiser roll.'),

  // 🥪 ساندوتشات فرايد تشيكن
// 🍔 سندوتشات فرايد تشيكن

  // ✅ أضف الخيارات
  // 🥪 ساندوتشات فرايد تشيكن
  MenuItemModel(
    id: 'sandwich_classico',
    name: 'كلاسيكو',
    description: 'استربس + خس + صوص بروستكي + خيار',
    price: 80.0,
    imagePath: 'assets/images/sandwich_classico.png',
    category: 'fried',
    titleEn: 'Classico',
    titleAr: 'كلاسيكو',
    image: 'assets/images/sandwich_classico.png',
    descriptionAr: 'استربس دجاج مع خس وصوص بروستكي وخيار.',
    descriptionEn: 'Chicken strips with lettuce, broasted sauce, and cucumber.',
    options: [
      {'name': 'سنجل', 'price': 80.0},
      {'name': 'دبل', 'price': 145.0},
    ],
  ),

  MenuItemModel(
    id: 'sandwich_abo_elgben',
    name: 'أبو الجبن',
    description: 'استربس + شيدر + صوص موتزاريلا + خيار + صوص بروستكي',
    price: 85.0,
    imagePath: 'assets/images/sandwich_abo_elgben.png',
    category: 'fried',
    titleEn: 'Abo El Gben',
    titleAr: 'أبو الجبن',
    image: 'assets/images/sandwich_abo_elgben.png',
    descriptionAr: 'استربس دجاج مع شيدر وصوص موتزاريلا وخيار وصوص بروستكي.',
    descriptionEn:
        'Chicken strips with cheddar, mozzarella sauce, cucumber, and broasted sauce.',
    options: [
      {'name': 'سنجل', 'price': 85.0},
      {'name': 'دبل', 'price': 149.0},
    ],
  ),

  MenuItemModel(
    id: 'sandwich_pro',
    name: 'برو',
    description: 'استربس + حلقة بصل + صوص شيدر + خيار + صوص باربيكيو تركي',
    price: 110.0,
    imagePath: 'assets/images/sandwich_pro.png',
    category: 'fried',
    titleEn: 'Pro',
    titleAr: 'برو',
    image: 'assets/images/sandwich_pro.png',
    descriptionAr:
        'استربس دجاج مع حلقة بصل وصوص شيدر وخيار وصوص باربيكيو تركي.',
    descriptionEn:
        'Chicken strips with onion rings, cheddar sauce, cucumber, and Turkish barbecue sauce.',
    options: [
      {'name': 'سنجل', 'price': 110.0},
      {'name': 'دبل', 'price': 165.0},
    ],
  ),

  MenuItemModel(
    id: 'sandwich_mambo',
    name: 'مامبو',
    description: 'استربس + اسموك بيف + صوص شيدر + صوص تشيلي سويت',
    price: 95.0,
    imagePath: 'assets/images/sandwich_mambo.png',
    category: 'fried',
    titleEn: 'Mambo',
    titleAr: 'مامبو',
    image: 'assets/images/sandwich_mambo.png',
    descriptionAr: 'استربس دجاج مع اسموك بيف وصوص شيدر وصوص تشيلي سويت.',
    descriptionEn:
        'Chicken strips with smoked beef, cheddar sauce, and sweet chili sauce.',
    options: [
      {'name': 'سنجل', 'price': 95.0},
      {'name': 'دبل', 'price': 160.0},
    ],
  ),

  MenuItemModel(
    id: 'sandwich_ranch',
    name: 'رانش',
    description: 'استربس + خس + صوص رانش + خيار + صوص بروستكي',
    price: 85.0,
    imagePath: 'assets/images/sandwich_ranch.png',
    category: 'fried',
    titleEn: 'Ranch',
    titleAr: 'رانش',
    image: 'assets/images/sandwich_ranch.png',
    descriptionAr: 'استربس دجاج مع خس وصوص رانش وخيار وصوص بروستكي.',
    descriptionEn:
        'Chicken strips with lettuce, ranch sauce, cucumber, and broasted sauce.',
    options: [
      {'name': 'سنجل', 'price': 85.0},
      {'name': 'دبل', 'price': 149.0},
    ],
  ),

  MenuItemModel(
    id: 'sandwich_lion',
    name: 'لايون',
    description:
        'باربيكيو + شرايح استربس + صوص تشيلي + خيار + فلفل + اسموك بيف + خس',
    price: 120.0,
    imagePath: 'assets/images/sandwich_lion.png',
    category: 'fried',
    titleEn: 'Lion',
    titleAr: 'لايون',
    image: 'assets/images/sandwich_lion.png',
    descriptionAr:
        'استربس دجاج مع باربيكيو وخس وصوص تشيلي وخيار وفلفل واسموك بيف.',
    descriptionEn:
        'Chicken strips with barbecue sauce, lettuce, chili sauce, cucumber, pepper, and smoked beef.',
  ),

  MenuItemModel(
    id: 'sandwich_zinger_super',
    name: 'زينجر سوبر',
    description: 'استربس + خس + خيار + صوص باربيكيو + صوص بروستكي',
    price: 90.0,
    imagePath: 'assets/images/sandwich_zinger_super.png',
    category: 'fried',
    titleEn: 'Zinger Super',
    titleAr: 'زينجر سوبر',
    image: 'assets/images/sandwich_zinger_super.png',
    descriptionAr: 'استربس دجاج مع خس وصوص باربيكيو وخيار وصوص بروستكي.',
    descriptionEn:
        'Chicken strips with lettuce, barbecue sauce, cucumber, and broasted sauce.',
  ),
  // 🥪 سندوتشات ناشفيل
  MenuItemModel(
    id: 'sand_nash_zlzal',
    name: 'زلزال',
    description:
        'شريحة تندر - خيار - هالبينو - مخلل - تومية - كول سلو - صوص ناشفيل',
    price: 105.0,
    imagePath: 'assets/images/sand_nash_zlzal.png',
    category: 'nashville',
    titleEn: 'Zlzal',
    titleAr: 'زلزال',
    image: 'assets/images/sand_nash_zlzal.png',
    descriptionAr:
        'استربس دجاج مع خيار وهالبينو ومخلل وتومية وكول سلو وصوص ناشفيل.',
    descriptionEn:
        'Chicken strips with cucumber, jalapeño, pickles, garlic sauce, coleslaw, and Nashville sauce.',
  ),

  MenuItemModel(
    id: 'sand_nash_volt',
    name: 'فولت',
    description:
        'شريحة تندر - هالبينو - خيار مخلل - صوص تومية - كول سلو - صوص حار',
    price: 115.0,
    imagePath: 'assets/images/sand_nash_volt.png',
    category: 'nashville',
    titleEn: 'Volt',
    titleAr: 'فولت',
    image: 'assets/images/sand_nash_volt.png',
    descriptionAr:
        'استربس دجاج مع هالبينو وخيار مخلل وصوص تومية وكول سلو وصوص حار.',
    descriptionEn:
        'Chicken strips with jalapeño, pickles, garlic sauce, coleslaw, and hot sauce.',
  ),

  MenuItemModel(
    id: 'sand_nash_dynamite',
    name: 'ديناميت',
    description:
        'شريحة تندر - خيار مخلل - تومية - هالبينو - سويس شيدر - كول سلو - صوص ديناميت',
    price: 135.0,
    imagePath: 'assets/images/sand_nash_dynamite.png',
    category: 'nashville',
    titleEn: 'Dynamite',
    titleAr: 'ديناميت',
    image: 'assets/images/sand_nash_dynamite.png',
    descriptionAr:
        'استربس دجاج مع خيار مخلل وتومية وهالبينو وسويس شيدر وكول سلو وصوص ديناميت.',
    descriptionEn:
        'Chicken strips with pickles, garlic sauce, jalapeño, Swiss cheddar, coleslaw, and dynamite sauce.',
  ),

// 🌯 سندوتشات رول
  MenuItemModel(
      id: 'sand_roll_syrian',
      name: 'بطاطس سوري',
      description: 'بطاطس - خبز تورتيلا - ثومية - مخلل - كاتشب',
      price: 50.0,
      imagePath: 'assets/images/sand_roll_syrian.png',
      category: 'sandwich_roll',
      titleEn: 'Syrian Fries Roll',
      titleAr: 'بطاطس سوري',
      image: 'assets/images/sand_roll_syrian.png',
      descriptionAr: 'بطاطس مقلية مع ثومية ومخلل وكاتشب.',
      descriptionEn: 'Fried potatoes with garlic sauce, pickles, and ketchup.'),

  MenuItemModel(
      id: 'sand_roll_twister',
      name: 'توستـر',
      description: 'استربس - خبز تورتيلا - مايونيز - خيار - خس - طماطم',
      price: 50.0,
      imagePath: 'assets/images/sand_roll_twister.png',
      category: 'sandwich_roll',
      titleEn: 'Twister Roll',
      titleAr: 'توستـر',
      image: 'assets/images/sand_roll_twister.png',
      descriptionAr: 'استربس دجاج مع مايونيز وخيار وخس وطماطم.',
      descriptionEn:
          'Chicken strips with mayonnaise, cucumber, lettuce, and tomatoes.'),

  MenuItemModel(
      id: 'sand_roll_prostaki',
      name: 'بروستاكي رول',
      description: 'استربس - خبز تورتيلا - صوص حار - ثومية - خس - طماطم',
      price: 75.0,
      imagePath: 'assets/images/sand_roll_prostaki.png',
      category: 'sandwich_roll',
      titleEn: 'Prostaki Roll',
      titleAr: 'بروستاكي رول',
      image: 'assets/images/sand_roll_prostaki.png',
      descriptionAr: 'استربس دجاج مع صوص حار وثومية وخس وطماطم.',
      descriptionEn:
          'Chicken strips with hot sauce, garlic sauce, lettuce, and tomatoes.'),

  MenuItemModel(
      id: 'sand_roll_ranch',
      name: 'رانش رول',
      description: 'استربس - خبز تورتيلا - صوص رانش - خس - طماطم',
      price: 75.0,
      imagePath: 'assets/images/sand_roll_ranch.png',
      category: 'sandwich_roll',
      titleEn: 'Ranch Roll',
      titleAr: 'رانش رول',
      image: 'assets/images/sand_roll_ranch.png',
      descriptionAr: 'استربس دجاج مع صوص رانش وخس وطماطم.',
      descriptionEn: 'Chicken strips with ranch sauce, lettuce, and tomatoes.'),

  MenuItemModel(
    id: 'sand_roll_big_twister',
    name: 'بيج توستـر',
    description: 'استربس - خبز تورتيلا - صوص بروستكي - طماطم - خس - صوص مطاعم',
    price: 90.0,
    imagePath: 'assets/images/sand_roll_big_twister.png',
    category: 'sandwich_roll',
    titleEn: 'Big Twister Roll',
    titleAr: 'بيج توستـر',
    image: 'assets/images/sand_roll_big_twister.png',
    descriptionAr: 'استربس دجاج مع صوص بروستكي وطماطم وخس وصوص مطاعم.',
    descriptionEn:
        'Chicken strips with prostaki sauce, tomatoes, lettuce, and restaurant sauce.',
  ),

  MenuItemModel(
      id: 'sand_roll_texas',
      name: 'تكساس راب',
      description:
          'خيار مخلل - 2 استربس - صوص جبنة - خس - كول سلو - صوص باربكيو',
      price: 95.0,
      imagePath: 'assets/images/sand_roll_texas.png',
      category: 'sandwich_roll',
      titleEn: 'Texas Wrap',
      titleAr: 'تكساس راب',
      image: 'assets/images/sand_roll_texas.png',
      descriptionAr:
          'خيار مخلل - 2 استربس - صوص جبنة - خس - كول سلو - صوص باربكيو',
      descriptionEn:
          'Pickles - 2 strips - cheese sauce - lettuce - coleslaw - barbecue sauce'),

// 🍟 قسم البطاطس
  MenuItemModel(
    id: 'fries_plain',
    name: 'باكيت بطاطس',
    description: 'بطاطس مقلية مقرمشة',
    price: 15.0,
    imagePath: 'assets/images/fries_plain.png',
    category: 'fries',
    titleEn: 'Plain Fries',
    titleAr: 'باكيت بطاطس',
    image: 'assets/images/fries_plain.png',
    descriptionAr: 'بطاطس مقلية مقرمشة',
    descriptionEn: 'Crispy fried potatoes',
    options: [
      {'name': 'صغير', 'price': 15.0},
      {'name': 'كبير', 'price': 35.0},
    ],
  ),

  MenuItemModel(
    id: 'fries_cheese',
    name: 'بطاطس شيدر',
    description: 'بطاطس مقلية بصوص الجبنة الشيدر',
    price: 20.0,
    imagePath: 'assets/images/fries_cheese.png',
    category: 'fries',
    titleEn: 'Cheese Fries',
    titleAr: 'بطاطس شيدر',
    image: 'assets/images/fries_cheese.png',
    descriptionAr: 'بطاطس مقلية بصوص الجبنة الشيدر',
    descriptionEn: 'Fried potatoes with cheddar cheese sauce',
    options: [
      {'name': 'صغير', 'price': 20.0},
      {'name': 'كبير', 'price': 35.0},
    ],
  ),

  MenuItemModel(
    id: 'fries_cheese_jalapeno',
    name: 'بطاطس شيدر و هالابينو',
    description: 'بطاطس مقلية مع صوص شيدر وهالابينو حار',
    price: 25.0,
    imagePath: 'assets/images/fries_cheese_jalapeno.png',
    category: 'fries',
    titleEn: 'Cheese & Jalapeno Fries',
    titleAr: 'بطاطس شيدر و هالابينو',
    image: 'assets/images/fries_cheese_jalapeno.png',
    descriptionAr: 'بطاطس مقلية مع صوص شيدر وهالابينو حار',
    descriptionEn: 'Fried potatoes with cheddar cheese and spicy jalapenos',
    options: [
      {'name': 'صغير', 'price': 25.0},
      {'name': 'كبير', 'price': 35.0},
    ],
  ),

  MenuItemModel(
    id: 'fries_broastay',
    name: 'بطاطس بروستاكي',
    description: 'بطاطس مع تركي و شيدر و خيار مخلل',
    price: 30.0,
    imagePath: 'assets/images/fries_broastay.png',
    category: 'fries',
    titleEn: 'Broastkay Fries',
    titleAr: 'بطاطس بروستاكي',
    image: 'assets/images/fries_broastay.png',
    descriptionAr: 'بطاطس مقلية مع صوص بروستاكي وشرائح الخيار المخلل.',
    descriptionEn: 'Fried potatoes with broastaki sauce and pickles.',
    options: [
      {'name': 'صغير', 'price': 30.0},
      {'name': 'كبير', 'price': 40.0},
    ],
  ),

  MenuItemModel(
    id: 'fries_maragragh',
    name: 'المرجرجة',
    description: 'بطاطس + استربس + تركي + ميكس صوصات',
    price: 30.0,
    imagePath: 'assets/images/fries_maragha.png',
    category: 'fries',
    titleEn: 'Maragragh Fries',
    titleAr: 'المرجرجة',
    image: 'assets/images/fries_maragha.png',
    descriptionAr: 'بطاطس مقلية مع استربس دجاج وشرائح تركي وميكس صوصات.',
    descriptionEn:
        'Fried potatoes with chicken strips, turkey slices, and a mix of sauces.',
    options: [
      {'name': 'صغير', 'price': 30.0},
      {'name': 'كبير', 'price': 60.0},
    ],
  ),
// 🧂 قسم الصوصات
  MenuItemModel(
    id: 'sauce_toumia',
    name: 'تومية',
    description: 'صوص تومية لذيذ بنكهة الثوم',
    price: 10.0,
    imagePath: 'assets/images/sauce_toumia.png',
    category: 'sauces',
    titleEn: 'Toumia Sauce',
    titleAr: 'تومية',
    image: 'assets/images/sauce_toumia.png',
    descriptionAr: 'صوص تومية لذيذ بنكهة الثوم',
    descriptionEn: 'Delicious garlic-flavored toumia sauce',
    options: [
      {'name': 'صغير', 'price': 10.0},
      {'name': 'كبير', 'price': 15.0},
    ],
  ),

  MenuItemModel(
    id: 'sauce_coleslaw',
    name: 'كول سلو',
    description: 'سلطة كول سلو كريمية وطازجة',
    price: 10.0,
    imagePath: 'assets/images/sauce_coleslaw.png',
    category: 'sauces',
    titleEn: 'Coleslaw',
    titleAr: 'كول سلو',
    image: 'assets/images/sauce_coleslaw.png',
    descriptionAr: 'سلطة كول سلو كريمية وطازجة',
    descriptionEn: 'Creamy and fresh coleslaw salad',
    options: [
      {'name': 'صغير', 'price': 10.0},
      {'name': 'كبير', 'price': 15.0},
    ],
  ),

  MenuItemModel(
    id: 'sauce_bbq',
    name: 'باربكيو',
    description: 'صوص باربكيو مدخن بطعم مميز',
    price: 15.0,
    imagePath: 'assets/images/sauce_bbq.png',
    category: 'sauces',
    titleEn: 'BBQ Sauce',
    titleAr: 'باربكيو',
    image: 'assets/images/sauce_bbq.png',
    descriptionAr: 'صوص باربكيو مدخن بطعم مميز',
    descriptionEn: 'Smoky BBQ sauce with a distinctive flavor',
    options: [
      {'name': 'صغير', 'price': 15.0},
      {'name': 'كبير', 'price': 25.0},
    ],
  ),

  MenuItemModel(
    id: 'sauce_cheddar',
    name: 'شيدر',
    description: 'صوص جبنة شيدر غني وكريمي',
    price: 15.0,
    imagePath: 'assets/images/sauce_cheddar.png',
    category: 'sauces',
    titleEn: 'Cheddar Sauce',
    titleAr: 'شيدر',
    image: 'assets/images/sauce_cheddar.png',
    descriptionAr: 'صوص جبنة شيدر غني وكريمي',
    descriptionEn: 'Rich and creamy cheddar cheese sauce',
    options: [
      {'name': 'صغير', 'price': 15.0},
      {'name': 'كبير', 'price': 25.0},
    ],
  ),

  MenuItemModel(
    id: 'sauce_ranch',
    name: 'رانش',
    description: 'صوص رانش بالكريمة والأعشاب',
    price: 15.0,
    imagePath: 'assets/images/sauce_ranch.png',
    category: 'sauces',
    titleEn: 'Ranch Sauce',
    titleAr: 'رانش',
    image: 'assets/images/sauce_ranch.png',
    descriptionAr: 'صوص رانش بالكريمة والأعشاب',
    descriptionEn: 'Creamy ranch sauce with herbs',
    options: [
      {'name': 'صغير', 'price': 15.0},
      {'name': 'كبير', 'price': 25.0},
    ],
  ),

  MenuItemModel(
    id: 'sauce_sweetchili',
    name: 'سويت تشيلي',
    description: 'صوص حلو حار بطعم التشيلي اللذيذ',
    price: 15.0,
    imagePath: 'assets/images/sauce_sweetchili.png',
    category: 'sauces',
    titleEn: 'Sweet Chili Sauce',
    titleAr: 'سويت تشيلي',
    image: 'assets/images/sauce_sweetchili.png',
    descriptionAr: 'صوص حلو حار بطعم التشيلي اللذيذ',
    descriptionEn: 'Delicious sweet and spicy chili sauce',
    options: [
      {'name': 'صغير', 'price': 15.0},
      {'name': 'كبير', 'price': 25.0},
    ],
  ),

  MenuItemModel(
    id: 'sauce_texas',
    name: 'تكساس',
    description: 'صوص تكساس الغني بالنكهة المدخنة',
    price: 15.0,
    imagePath: 'assets/images/sauce_texas.png',
    category: 'sauces',
    titleEn: 'Texas Sauce',
    titleAr: 'تكساس',
    image: 'assets/images/sauce_texas.png',
    descriptionAr: 'صوص تكساس الغني بالنكهة المدخنة',
    descriptionEn: 'Rich and smoky Texas-style sauce',
    options: [
      {'name': 'صغير', 'price': 15.0},
      {'name': 'كبير', 'price': 25.0},
    ],
  ),

  MenuItemModel(
    id: 'sauce_spicyharissa',
    name: 'هريسة حارة',
    description: 'صوص هريسة تونسية حارة ولاذعة',
    price: 15.0,
    imagePath: 'assets/images/sauce_spicyharissa.png',
    category: 'sauces',
    titleEn: 'Spicy Harissa Sauce',
    titleAr: 'هريسة حارة',
    image: 'assets/images/sauce_spicyharissa.png',
    descriptionAr: 'صوص هريسة تونسية حارة ولاذعة',
    descriptionEn: 'Tunisian spicy harissa sauce with a kick',
    options: [
      {'name': 'صغير', 'price': 15.0},
      {'name': 'كبير', 'price': 25.0},
    ],
  ),

  // 🍹 مشروبات
  MenuItemModel(
      id: 'drink_pepsi',
      name: 'بيبسي',
      description: 'علبة بيبسي باردة',
      price: 15.0,
      imagePath: 'assets/images/pepsi.png',
      category: 'drink',
      titleEn: 'Pepsi',
      titleAr: 'بيبسي',
      image: 'assets/images/pepsi.png',
      descriptionAr: 'علبة بيبسي باردة',
      descriptionEn: 'Cold can of Pepsi'),
  MenuItemModel(
    id: 'drink_water',
    name: 'مياه معدنية',
    description: 'زجاجة مياه معدنية صغيرة',
    price: 10.0,
    imagePath: 'assets/images/water.png',
    category: 'drink',
    titleEn: 'Water',
    titleAr: 'مياه',
    image: 'assets/images/water.png',
    descriptionAr: 'زجاجة مياه معدنية صغيرة',
    descriptionEn: 'Small bottle of mineral water',
  ),
// 🍗 قسم التسوية | Settlement

// ملاحظة: الصورة هتتعرض في واجهة المنيو مرة واحدة فوق القسم
// باستخدام المسار ده في الواجهة:

// العناصر (بدون أي صور داخلها)
  MenuItemModel(
      id: 'settlement_full_chicken_prep',
      name: 'الفرخة كاملة',
      description: '(تجهيز - تسوية)',
      price: 100.0,
      category: 'settlement',
      titleEn: 'Full Chicken (Preparation & Cooking)',
      titleAr: 'الفرخة كاملة',
      imagePath: 'assets/images/placeholder.png',
      image: 'assets/images/placeholder.png',
      descriptionAr: 'تجهيز وتسوية الفرخة كاملة',
      descriptionEn: 'Preparation and cooking of the whole chicken'),

  MenuItemModel(
      id: 'settlement_full_chicken_meal',
      name: 'الفرخة كاملة',
      description: 'تجهيز وتسوية + فرايز عائلي + 2 تومية + 1 كولسلو',
      price: 150.0,
      category: 'settlement',
      titleEn: 'Full Chicken with Add-ons',
      titleAr: "الفرخة كاملة مع اضافات",
      imagePath: 'assets/images/placeholder0.png',
      image: 'assets/images/placeholder0.png',
      descriptionAr: 'تجهيز وتسوية الفرخة كاملة مع اضافات',
      descriptionEn:
          'Preparation and cooking of the whole chicken with add-ons'),

  // ➕ إضافات
  // --- أرز ---
  MenuItemModel(
    id: 'side_rice',
    name: 'أرز',
    description: 'أرز أبيض مطهو بعناية',
    price: 25.0,
    imagePath: 'assets/images/side_rice.png',
    category: 'addon',
    titleEn: 'Rice',
    titleAr: 'أرز',
    image: 'assets/images/side_rice.png',
    descriptionAr: 'أرز أبيض مطهو بعناية',
    descriptionEn: 'Carefully cooked white rice',
    options: [
      {'name': 'صغير', 'price': 25.0},
      {'name': 'كبير', 'price': 50.0},
    ],
  ),

// --- ريزو ---
  MenuItemModel(
    id: 'side_rizo',
    name: 'ريزو',
    description: 'أرز ريزو متبل بالنكهة المميزة',
    price: 30.0,
    imagePath: 'assets/images/side_rizo.png',
    category: 'addon',
    titleEn: 'Rizo',
    titleAr: 'ريزو',
    image: 'assets/images/side_rizo.png',
    descriptionAr: 'أرز ريزو متبل بالنكهة المميزة',
    descriptionEn: 'Flavorful seasoned Rizo rice',
    options: [
      {'name': 'صغير', 'price': 30.0},
      {'name': 'كبير', 'price': 60.0},
    ],
  ),

// --- حلقات بصل ---
  MenuItemModel(
    id: 'side_onionrings',
    name: 'حلقات بصل',
    description: 'حلقات بصل مقلية ومقرمشة',
    price: 25.0,
    imagePath: 'assets/images/side_onionrings.png',
    category: 'addon',
    titleEn: 'Onion Rings',
    titleAr: 'حلقات بصل',
    image: 'assets/images/side_onionrings.png',
    descriptionAr: 'حلقات بصل مقلية ومقرمشة',
    descriptionEn: 'Crispy fried onion rings',
    options: [
      {'name': 'صغير', 'price': 25.0},
      {'name': 'كبير', 'price': 50.0},
    ],
  ),

// --- صوابع جبنة ---
  MenuItemModel(
    id: 'side_cheesesticks',
    name: 'صوابع جبنة',
    description: 'صوابع جبنة موزاريلا مقرمشة ولذيذة',
    price: 30.0,
    imagePath: 'assets/images/side_cheesesticks.png',
    category: 'addon',
    titleEn: 'Cheese Sticks',
    titleAr: 'صوابع جبنة',
    image: 'assets/images/side_cheesesticks.png',
    descriptionAr: 'صوابع جبنة موزاريلا مقرمشة ولذيذة',
    descriptionEn: 'Crispy and delicious mozzarella cheese sticks',
    options: [
      {'name': 'صغير', 'price': 30.0},
      {'name': 'كبير', 'price': 60.0},
    ],
  ),
  MenuItemModel(
    id: 'V-Cola',
    name: 'في كولا',
    description: 'مشروب غازي في كولا بارد ومنعش',
    price: 20.0,
    imagePath: 'assets/images/V-Cola.png',
    category: 'addon',
    titleEn: 'V-Cola',
    titleAr: 'في كولا',
    image: 'assets/images/V-Cola.png',
    descriptionAr: 'مشروب غازي في كولا بارد ومنعش',
    descriptionEn: 'Cold and refreshing V-Cola soft drink',
  ),
  MenuItemModel(
    id: 'مياه-معدنية',
    name: 'مياه معدنية',
    description: 'مياه معدنية نقية ومنعشة',
    price: 10.0,
    imagePath: 'assets/images/mineral_water.png',
    category: 'addon',
    titleEn: 'Mineral Water',
    titleAr: 'مياه معدنية',
    image: 'assets/images/mineral_water.png',
    descriptionAr: 'مياه معدنية نقية ومنعشة',
    descriptionEn: 'Pure and refreshing mineral water',
  ),
  MenuItemModel(
    id: 'mc',
    name: 'ام سي لتر',
    description: '',
    price: 30.0,
    imagePath: 'assets/images/mc.png',
    category: 'addon',
    titleEn: 'mc',
    titleAr: 'ام سي',
    image: 'assets/images/mc.png',
    descriptionAr: '',
    descriptionEn: '',
  ),
  MenuItemModel(
    id: 'بيج',
    name: 'بيج',
    description: '',
    price: 10.0,
    imagePath: 'assets/images/big.png',
    category: 'addon',
    titleEn: 'big',
    titleAr: 'بيج',
    image: 'assets/images/big.png',
    descriptionAr: '',
    descriptionEn: '',
  ),
];
