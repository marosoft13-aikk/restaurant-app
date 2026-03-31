import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import 'package:flutter/material.dart';

class FirestoreMenuProvider with ChangeNotifier {
  List<ProductModel> products = [];
  bool isLoading = false;

  Future<void> loadProducts() async {
    isLoading = true;
    notifyListeners();

    final snapshot =
        await FirebaseFirestore.instance.collection('products').get();

    products = snapshot.docs
        .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
        .toList();

    isLoading = false;
    notifyListeners();
  }
}
