import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

class CategoryService {
  static final _db  = FirebaseFirestore.instance;
  static const _col = 'categories';

  static Stream<List<CategoryModel>> watchAll() {
    return _db
        .collection(_col)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(CategoryModel.fromDocument).toList());
  }

  static Future<List<CategoryModel>> getAll() async {
    try {
      final snap = await _db.collection(_col).orderBy('name').get();
      return snap.docs.map(CategoryModel.fromDocument).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> getNames() async {
    final cats = await getAll();
    return cats.map((c) => c.name).toList();
  }

  static Future<void> add(String name, {String icon = '🏷️'}) async {
    await _db.collection(_col).add({
      'name':      name.trim(),
      'icon':      icon,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String id) async {
    await _db.collection(_col).doc(id).delete();
  }
}
