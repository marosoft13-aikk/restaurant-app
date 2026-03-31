class ProductModel {
  final String id;
  final String titleAr;
  final String titleEn;
  final String category;
  final String description;
  final double price;
  final String imageUrl;

  ProductModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.category,
    required this.description,
    required this.price,
    required this.imageUrl,
  });

  factory ProductModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ProductModel(
      id: id,
      titleAr: data['titleAr'] ?? '',
      titleEn: data['titleEn'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] is int)
          ? (data['price'] as int).toDouble()
          : (data['price'] ?? 0.0),
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}
