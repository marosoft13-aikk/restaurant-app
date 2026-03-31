// lib/pages/admin_upload_menu.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/menu_item_model.dart';
import '../services/firebase_menu_service.dart';

class AdminUploadMenuPage extends StatefulWidget {
  const AdminUploadMenuPage({super.key});

  @override
  State<AdminUploadMenuPage> createState() => _AdminUploadMenuPageState();
}

class _AdminUploadMenuPageState extends State<AdminUploadMenuPage> {
  final FirebaseMenuService _service = FirebaseMenuService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin — Manage Menu'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<List<MenuItemModel>>(
        stream: _service.menuStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.orange));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(child: Text('Menu is empty'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = items[i];
              return Card(
                elevation: 3,
                child: ListTile(
                  leading: (item.imagePath.isNotEmpty)
                      ? SizedBox(
                          width: 56,
                          child: Image.network(
                            item.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image_not_supported),
                          ),
                        )
                      : const Icon(Icons.fastfood),
                  title:
                      Text(item.titleEn.isNotEmpty ? item.titleEn : item.name),
                  subtitle:
                      Text('${item.category} • ${item.price.toString()} ج.م'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _openItemForm(existing: item),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(item),
                      ),
                    ],
                  ),
                  onTap: () => _showItemDetails(item),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
        onPressed: () => _openItemForm(), // add new
      ),
    );
  }

  void _showItemDetails(MenuItemModel item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(item.titleEn.isNotEmpty ? item.titleEn : item.titleAr),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.imagePath.isNotEmpty)
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: Image.network(item.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image_not_supported)),
                  ),
                const SizedBox(height: 8),
                Text('Category: ${item.category}'),
                Text('Price: ${item.price.toString()} ج.م'),
                const SizedBox(height: 8),
                Text('Description (EN): ${item.descriptionEn}'),
                const SizedBox(height: 6),
                Text('Description (AR): ${item.descriptionAr}'),
                const SizedBox(height: 8),
                Text(
                    'Options: ${item.options.map((o) => o['value'] ?? o.toString()).join(', ')}'),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openItemForm(existing: item);
                },
                child: const Text('Edit')),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(MenuItemModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item'),
        content: Text(
            'Are you sure you want to delete "${item.titleEn.isNotEmpty ? item.titleEn : item.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _service.deleteItem(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Item deleted'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Delete failed: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _openItemForm({MenuItemModel? existing}) async {
    final isEdit = existing != null;
    // Generate id for new item
    final newId = _db.collection(_service.collectionName).doc().id;

    final TextEditingController titleEnCtrl =
        TextEditingController(text: existing?.titleEn ?? '');
    final TextEditingController titleArCtrl =
        TextEditingController(text: existing?.titleAr ?? '');
    final TextEditingController nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final TextEditingController priceCtrl = TextEditingController(
        text: existing != null ? existing.price.toString() : '');
    final TextEditingController categoryCtrl =
        TextEditingController(text: existing?.category ?? '');
    final TextEditingController imagePathCtrl =
        TextEditingController(text: existing?.imagePath ?? '');
    final TextEditingController descEnCtrl = TextEditingController(
        text: existing?.descriptionEn ?? existing?.description ?? '');
    final TextEditingController descArCtrl =
        TextEditingController(text: existing?.descriptionAr ?? '');
    final TextEditingController optionsCtrl = TextEditingController(
      text: existing != null
          ? existing.options
              .map((o) =>
                  (o['value'] ?? o['name'] ?? o['label'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .join(', ')
          : '',
    );
    bool visible = existing?.visible ?? true;

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(isEdit ? 'Edit item' : 'Add new item',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold))),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                      controller: titleEnCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Title (EN)')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: titleArCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Title (AR)')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Name (fallback)')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(labelText: 'Category')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: imagePathCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Image URL or Path')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: descEnCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Description (EN)')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: descArCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Description (AR)')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: optionsCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Options (comma separated)')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Visible'),
                      Switch(
                          value: visible,
                          onChanged: (v) {
                            setState(() {
                              visible = v;
                            });
                          }),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange),
                        onPressed: () async {
                          final price =
                              double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                          final id = isEdit ? existing!.id : newId;

                          // parse options (comma separated) -> List<Map<String,dynamic>>
                          List<Map<String, dynamic>> parsedOptions = [];
                          final rawOpts = optionsCtrl.text
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          for (final o in rawOpts) {
                            parsedOptions.add({'value': o});
                          }

                          final model = MenuItemModel.fromMap({
                            'id': id,
                            'name': nameCtrl.text.trim(),
                            'description': descEnCtrl.text.trim(),
                            'price': price,
                            'imagePath': imagePathCtrl.text.trim(),
                            'category': categoryCtrl.text.trim().toLowerCase(),
                            'titleEn': titleEnCtrl.text.trim(),
                            'titleAr': titleArCtrl.text.trim(),
                            'image': imagePathCtrl.text.trim(),
                            'descriptionEn': descEnCtrl.text.trim(),
                            'descriptionAr': descArCtrl.text.trim(),
                            'options': parsedOptions,
                            'order': existing?.order ?? 0,
                            'visible': visible,
                          });

                          try {
                            await _service.addOrUpdateItem2(model);
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text(isEdit ? 'Updated' : 'Created'),
                                      backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Save failed: $e'),
                                      backgroundColor: Colors.red));
                            }
                          }
                        },
                        child: Text(isEdit ? 'Update' : 'Create'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
