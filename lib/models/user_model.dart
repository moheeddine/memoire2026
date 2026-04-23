import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { client, entreprise, admin, unknown }
enum UserStatus { active, pending, rejected, suspended, unknown }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final UserStatus status;
  final String? fcmToken;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.phone,
    this.fcmToken,
    this.createdAt,
  });

  // ─── FACTORY ─────────────────────────────────────────────────────────────

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid:       uid,
      name:      map['name'] as String? ?? '',
      email:     map['email'] as String? ?? '',
      phone:     map['phone'] as String?,
      role:      _parseRole(map['role'] as String?),
      status:    _parseStatus(map['status'] as String?),
      fcmToken:  map['fcmToken'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.fromDocument(DocumentSnapshot doc) {
    return UserModel.fromMap(
      doc.id,
      doc.data() as Map<String, dynamic>? ?? {},
    );
  }

  // ─── TO MAP ──────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'name':   name,
      'email':  email,
      'role':   role.name,
      'status': status.name,
      if (phone != null)    'phone':    phone,
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }

  // ─── COPY WITH ────────────────────────────────────────────────────────────

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    UserStatus? status,
    String? fcmToken,
  }) {
    return UserModel(
      uid:       uid,
      name:      name ?? this.name,
      email:     email ?? this.email,
      phone:     phone ?? this.phone,
      role:      role ?? this.role,
      status:    status ?? this.status,
      fcmToken:  fcmToken ?? this.fcmToken,
      createdAt: createdAt,
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  bool get isClient   => role == UserRole.client;
  bool get isBusiness => role == UserRole.entreprise;
  bool get isAdmin    => role == UserRole.admin;
  bool get isActive   => status == UserStatus.active;
  bool get isPending  => status == UserStatus.pending;

  static UserRole _parseRole(String? value) {
    switch (value) {
      case 'client':     return UserRole.client;
      case 'entreprise': return UserRole.entreprise;
      case 'admin':      return UserRole.admin;
      default:           return UserRole.unknown;
    }
  }

  static UserStatus _parseStatus(String? value) {
    switch (value) {
      case 'active':    return UserStatus.active;
      case 'pending':   return UserStatus.pending;
      case 'rejected':  return UserStatus.rejected;
      case 'suspended': return UserStatus.suspended;
      default:          return UserStatus.unknown;
    }
  }

  @override
  String toString() =>
      'UserModel(uid: $uid, name: $name, role: ${role.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}
