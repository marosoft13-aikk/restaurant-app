import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOffersPage extends StatelessWidget {
  const AdminOffersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text(
          "إدارة العروض",
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, "/add-offer");
            },
          )
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("offers")
            .orderBy("createdAt", descending: true) // ترتيب صحيح
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "لا توجد عروض مضافة بعد",
                style: GoogleFonts.cairo(fontSize: 16),
              ),
            );
          }

          final offers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final data = offers[index].data();
              final id = offers[index].id;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      // ----------------- IMAGE ------------------
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          data["image"],
                          height: 70,
                          width: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // ----------------- TEXT (EXPANDED → يمنع OF) ------------------
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data["title"],
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data["desc"],
                              style: GoogleFonts.cairo(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // ----------------- TRAILING (NO OVERFLOW) ------------------
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            data["discount"],
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          PopupMenuButton(
                            onSelected: (value) {
                              if (value == "edit") {
                                Navigator.pushNamed(
                                  context,
                                  "/edit-offer",
                                  arguments: {
                                    "id": id,
                                    "data": data,
                                  },
                                );
                              } else if (value == "delete") {
                                FirebaseFirestore.instance
                                    .collection("offers")
                                    .doc(id)
                                    .delete();
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: "edit",
                                child: Text("تعديل"),
                              ),
                              const PopupMenuItem(
                                value: "delete",
                                child: Text("حذف"),
                              ),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
