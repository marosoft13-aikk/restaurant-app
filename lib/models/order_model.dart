import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String name;
  final int quantity;
  final double price;
  final String imagePath;
  final String category;
  final String description;
  final String titleEn;
  final String titleAr;
  final String image;

  final String order;
  final String id;
  final double deliveryLat;
  final double deliveryLng;
  final String customerName;
  final String status;

  final String phone;
  final String address;
  final DateTime date;
  final double total;
  final List<dynamic> items;
  final String driverId;

  OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.imagePath,
    required this.category,
    required this.description,
    required this.titleEn,
    required this.titleAr,
    required this.image,
    required this.order,
    required this.id,
    required this.date,
    required this.phone,
    required this.address,
    required this.total,
    required this.items,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.customerName,
    required this.status,
    required this.driverId,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
      imagePath: map['imagePath'] ?? '',
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      titleEn: map['titleEn'] ?? '',
      titleAr: map['titleAr'] ?? '',
      image: map['image'] ?? '',
      order: map['order'] ?? '',
      id: map['id'] ?? '',
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate()
          : DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      total: (map['total'] ?? 0).toDouble(),
      items: map['items'] ?? [],
      deliveryLat: map['deliveryLat']?.toDouble() ?? 0.0,
      deliveryLng: map['deliveryLng']?.toDouble() ?? 0.0,
      customerName: map['customerName'] ?? '',
      status: map['status'] ?? '',
      driverId: map['driverId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'imagePath': imagePath,
      'category': category,
      'description': description,
      'titleEn': titleEn,
      'titleAr': titleAr,
      'image': image,
      'order': order,
      'id': id,
      'date': date.toIso8601String(),
      'phone': phone,
      'address': address,
      'total': total,
      'items': items,
      'deliveryLat': deliveryLat,
      'deliveryLng': deliveryLng,
      'customerName': customerName,
      'status': status,
      'driverId': driverId,
    };
  }
}

// ---------------------------------------------------------------------------
// ORDER MODEL (MAIN MODEL USED IN DRIVER PAGE)
// ---------------------------------------------------------------------------

class OrderModel {
  final String id;
  final String customerName;
  final String phone;
  final String address;
  final String time;
  final DateTime date;

  final double totalPrice;
  final String status;
  final String paymentMethod;
  final double? deliveryLat;
  final double? deliveryLng;
  final List<OrderItem> items;
  final double rating;
  final DateTime createdAt;

  final String driverId; // ← تمت إضافته

  OrderModel({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.time,
    required this.date,
    required this.totalPrice,
    required this.status,
    required this.paymentMethod,
    required this.items,
    required this.rating,
    this.deliveryLat,
    this.deliveryLng,
    required this.createdAt,
    required this.driverId, // ← مهم جداً
  });

  String get userName => customerName;

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    DateTime created = map['createdAt'] is Timestamp
        ? (map['createdAt'] as Timestamp).toDate()
        : DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now();

    return OrderModel(
      id: map['id'] ?? '',
      customerName: map['customerName'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      time: map['time'] ?? "${created.hour}:${created.minute}",
      date: created,
      totalPrice: (map['totalPrice']?.toDouble() ?? 0.0),
      status: map['status'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      items: map['items'] != null
          ? (map['items'] as List).map((e) => OrderItem.fromMap(e)).toList()
          : [],
      rating: (map['rating']?.toDouble() ?? 0.0),
      deliveryLat: map['deliveryLat']?.toDouble(),
      deliveryLng: map['deliveryLng']?.toDouble(),
      createdAt: created,
      driverId: map['driverId'] ?? '', // ← هنا
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'phone': phone,
      'address': address,
      'time': time,
      'date': date.toIso8601String(),
      'totalPrice': totalPrice,
      'status': status,
      'paymentMethod': paymentMethod,
      'items': items.map((e) => e.toMap()).toList(),
      'rating': rating,
      'deliveryLat': deliveryLat,
      'deliveryLng': deliveryLng,
      'createdAt': createdAt.toIso8601String(),
      'driverId': driverId, // ← وهنا
    };
  }
}
