// نسخة مُعدّلة كما في السورس الذي بعته
class MenuItemModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imagePath;
  final String category;
  final String titleEn;
  final String titleAr;
  final String image;
  final String descriptionEn;
  final String descriptionAr;
  final List<Map<String, dynamic>> options;
  final int order;
  final bool visible;

  MenuItemModel({
    String? id,
    String? name,
    String? description,
    double? price,
    String? imagePath,
    String? category,
    String? titleEn,
    String? titleAr,
    String? image,
    String? descriptionEn,
    String? descriptionAr,
    List<Map<String, dynamic>>? options,
    int? order,
    bool? visible,
  })  : id = id?.toString() ?? '',
        name = name ?? '',
        description = description ?? '',
        price = price ?? 0.0,
        imagePath = imagePath ?? '',
        category = (category ?? '').toLowerCase(),
        titleEn = titleEn ?? '',
        titleAr = titleAr ?? '',
        image = image ?? '',
        descriptionEn = descriptionEn ?? '',
        descriptionAr = descriptionAr ?? '',
        options = options ?? [],
        order = order ?? 0,
        visible = visible ?? true;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'imagePath': imagePath,
        'category': category,
        'titleEn': titleEn,
        'titleAr': titleAr,
        'image': image,
        'descriptionEn': descriptionEn,
        'descriptionAr': descriptionAr,
        'options': options,
        'order': order,
        'visible': visible,
      };

  factory MenuItemModel.fromMap(dynamic a, [Map<String, dynamic>? b]) {
    String id = '';
    Map<String, dynamic> map = <String, dynamic>{};

    if (a is String && b is Map<String, dynamic>) {
      id = a;
      map = b;
    } else if (a is Map<String, dynamic>) {
      map = a;
      if (map['id'] != null) {
        id = map['id'].toString();
      } else if (map['docId'] != null) {
        id = map['docId'].toString();
      }
    } else {
      map = <String, dynamic>{};
    }

    double parsePrice(dynamic p) {
      if (p == null) return 0.0;
      if (p is double) return p;
      if (p is int) return p.toDouble();
      if (p is String) return double.tryParse(p) ?? 0.0;
      return 0.0;
    }

    List<Map<String, dynamic>> parseOptions(dynamic o) {
      if (o == null) return [];
      try {
        return List<Map<String, dynamic>>.from(o);
      } catch (_) {
        try {
          final listStr = List<String>.from(o);
          return listStr.map((s) => {'value': s}).toList();
        } catch (_) {
          return [];
        }
      }
    }

    String parseString(dynamic s) => s?.toString() ?? '';

    return MenuItemModel(
      id: id,
      name: parseString(map['name'] ?? map['titleEn'] ?? map['title'] ?? ''),
      description: parseString(map['description'] ?? ''),
      price: parsePrice(map['price']),
      imagePath: parseString(map['imagePath'] ?? map['image'] ?? ''),
      category: parseString(map['category'] ?? '').toLowerCase(),
      titleEn: parseString(map['titleEn'] ?? map['name'] ?? ''),
      titleAr: parseString(map['titleAr'] ?? map['name'] ?? ''),
      image: parseString(map['image'] ?? map['imagePath'] ?? ''),
      descriptionEn: parseString(map['descriptionEn'] ?? ''),
      descriptionAr: parseString(map['descriptionAr'] ?? ''),
      options: parseOptions(map['options']),
      order: (map['order'] is int)
          ? map['order'] as int
          : (int.tryParse(map['order']?.toString() ?? '') ?? 0),
      visible: map['visible'] == null
          ? true
          : (map['visible'] == true || map['visible'] == 'true'),
    );
  }

  static MenuItemModel fromFirestore(dynamic doc) {
    try {
      final data = (doc.data() is Map<String, dynamic>)
          ? Map<String, dynamic>.from(doc.data())
          : <String, dynamic>{};
      if (doc.id != null) data['id'] = doc.id;
      return MenuItemModel.fromMap(data);
    } catch (_) {
      return MenuItemModel();
    }
  }

  factory MenuItemModel.fromJson(Map<String, dynamic> json) =>
      MenuItemModel.fromMap(json);

  String get imageUrl => imagePath.isNotEmpty ? imagePath : image;

  MenuItemModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? imagePath,
    String? category,
    String? titleEn,
    String? titleAr,
    String? image,
    String? descriptionEn,
    String? descriptionAr,
    List<Map<String, dynamic>>? options,
    int? order,
    bool? visible,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imagePath: imagePath ?? this.imagePath,
      category: category ?? this.category,
      titleEn: titleEn ?? this.titleEn,
      titleAr: titleAr ?? this.titleAr,
      image: image ?? this.image,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      options: options ?? this.options,
      order: order ?? this.order,
      visible: visible ?? this.visible,
    );
  }

  static List<Map<String, dynamic>> optionsFromStrings(List<String> s) {
    return s.map((e) => {"value": e}).toList();
  }

  static List<String> optionsToStrings(List<Map<String, dynamic>>? options) {
    if (options == null) return [];
    return options.map((m) => (m['value'] ?? '').toString()).toList();
  }
}
