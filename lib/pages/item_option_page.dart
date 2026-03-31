import 'package:flutter/material.dart';
import '../models/menu_item_model.dart';

class ItemOptionPage extends StatefulWidget {
  final MenuItemModel item;

  const ItemOptionPage({Key? key, required this.item}) : super(key: key);

  @override
  State<ItemOptionPage> createState() => _ItemOptionPageState();
}

class _ItemOptionPageState extends State<ItemOptionPage> {
  Map<String, dynamic>? selectedOption;
  double? currentPrice;

  @override
  void initState() {
    super.initState();
    // تحقق من وجود خيارات
    if (widget.item.options != null && widget.item.options!.isNotEmpty) {
      selectedOption = widget.item.options!.first;
      currentPrice = selectedOption!['price'];
    } else {
      // إذا مفيش خيارات نستخدم السعر الأساسي
      currentPrice = widget.item.price;
      selectedOption = {'name': 'افتراضي', 'price': currentPrice};
    }
  }

  void _changeOption(Map<String, dynamic> option) {
    setState(() {
      selectedOption = option;
      currentPrice = option['price'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          item.titleAr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepOrangeAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // صورة العنصر
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                item.imagePath,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),

            // السعر الحالي
            Text(
              "السعر: ${currentPrice?.toStringAsFixed(2) ?? item.price} ج.م",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 15),

            // خيارات الحجم أو النوع
            if (item.options != null && item.options!.isNotEmpty)
              Wrap(
                spacing: 10,
                children: item.options!.map((option) {
                  final isSelected = option['name'] == selectedOption?['name'];
                  return ChoiceChip(
                    label: Text(option['name']),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                    selected: isSelected,
                    selectedColor: Colors.deepOrangeAccent,
                    onSelected: (_) => _changeOption(option),
                  );
                }).toList(),
              )
            else
              const Text(
                "لا توجد خيارات متاحة لهذا العنصر",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),

            const Spacer(),

            // زر التأكيد
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.deepOrangeAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context, {
                    'selectedOption': selectedOption,
                    'price': currentPrice,
                  });
                },
                icon: const Icon(Icons.check, size: 26),
                label: const Text(
                  "تأكيد الاختيار",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
