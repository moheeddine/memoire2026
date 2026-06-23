import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final DateTime? createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    this.icon = '🏷️',
    this.createdAt,
  });

  factory CategoryModel.fromDocument(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return CategoryModel(
      id:        doc.id,
      name:      map['name'] as String? ?? '',
      icon:      map['icon'] as String? ?? '🏷️',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'icon': icon,
  };

  @override
  String toString() => 'CategoryModel(id: $id, name: $name)';
}
