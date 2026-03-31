import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'offers_page.dart';
//import 'settings_page.dart';
import 'package:broastaky_full/pages/settings_page.dart' hide ListTile;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> menuItems = [
    {
      "name": "Chicken Burger",
      "price": 70,
      "image": "assets/images/burger.png",
    },
    {
      "name": "Pizza Margherita",
      "price": 120,
      "image": "assets/images/pizza.png",
    },
    {
      "name": "Fried Chicken",
      "price": 90,
      "image": "assets/images/chicken.png",
    },
  ];

  List<Map<String, dynamic>> cart = [];
  String selectedPayment = "Cash";

  void addToCart(Map<String, dynamic> item) {
    setState(() {
      cart.add(item);
    });
  }

  void removeFromCart(int index) {
    setState(() {
      cart.removeAt(index);
    });
  }

  double get totalPrice =>
      cart.fold(0, (sum, item) => sum + (item["price"] as num).toDouble());

  void showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: StatefulBuilder(builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "🛒 سلة المشتريات",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (cart.isEmpty)
                  const Text("السلة فارغة 😅")
                else
                  Column(
                    children: cart.asMap().entries.map((entry) {
                      int index = entry.key;
                      var item = entry.value;
                      return ListTile(
                        leading: Image.asset(item["image"], height: 40),
                        title: Text(item["name"]),
                        subtitle: Text("${item["price"]} جنيه"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setModalState(() => removeFromCart(index));
                          },
                        ),
                      );
                    }).toList(),
                  ),
                const Divider(),
                Text(
                  "الإجمالي: ${totalPrice.toStringAsFixed(2)} جنيه",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 20),

                // اختيار وسيلة الدفع
                const Text(
                  "اختر وسيلة الدفع:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: [
                    paymentOption("Cash"),
                    paymentOption("Vodafone Cash"),
                    paymentOption("InstaPay"),
                  ],
                ),
                const SizedBox(height: 25),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 80, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text(
                    "تأكيد الطلب",
                    style: TextStyle(fontSize: 18),
                  ),
                  onPressed: cart.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          showOrderStatus();
                        },
                ),
                const SizedBox(height: 20),
              ],
            );
          }),
        );
      },
    );
  }

  Widget paymentOption(String name) {
    return ChoiceChip(
      label: Text(name),
      selected: selectedPayment == name,
      selectedColor: Colors.orange,
      onSelected: (_) {
        setState(() => selectedPayment = name);
      },
    );
  }

  void showOrderStatus() {
    showDialog(
      context: context,
      builder: (context) {
        String status = "جاري تحضير الطلب 🍳";
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future.delayed(const Duration(seconds: 3), () {
              setDialogState(() => status = "جاهز للتوصيل 🚗");
            });
            Future.delayed(const Duration(seconds: 6), () {
              setDialogState(() => status = "في الطريق 🛵");
            });
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text("حالة الطلب"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(status, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 15),
                  const LinearProgressIndicator(color: Colors.orange),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إغلاق"),
                )
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text(
          "Brostaky Menu 🍗",
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_offer),
            tooltip: "العروض",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OffersPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "الإعدادات",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: showCart,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orangeAccent, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            final item = menuItems[index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 5,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: ListTile(
                leading: Image.asset(item["image"], height: 60),
                title: Text(
                  item["name"],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text("${item["price"]} جنيه"),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => addToCart(item),
                  child: const Text("أضف"),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
