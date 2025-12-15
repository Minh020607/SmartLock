import 'package:cloud_firestore/cloud_firestore.dart';

class LockModel {
  final String id;               
  final String name;             
  final String ownerId;          
  bool isLocked;                 
  bool isOnline;                 
  DateTime? lastUpdated;         
  final List<String> sharedWith;

  LockModel({
    required this.id,
    required this.name,
    required this.ownerId,
    this.isLocked = true,
    this.isOnline = false,
    this.lastUpdated,
    this.sharedWith = const [],
  });

  factory LockModel.fromJson(Map<String, dynamic> json, String id) {
    return LockModel(
      id: id,
      name: json['name'] ?? 'Không tên',
      ownerId: json['ownerId'] ?? '',
      isLocked: json['isLocked'] ?? true,
      isOnline: json['isOnline'] ?? false,
      lastUpdated: json['lastUpdated'] is Timestamp
          ? (json['lastUpdated'] as Timestamp).toDate()
          : null,
      sharedWith: List<String>.from(json['sharedWith'] ?? []),
    );
  }

  /// ⭐ Thêm hàm này để dùng trong Firestore
  factory LockModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LockModel.fromJson(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ownerId': ownerId,
      'isLocked': isLocked,
      'isOnline': isOnline,
      'sharedWith': sharedWith,
      'lastUpdated': lastUpdated != null
          ? Timestamp.fromDate(lastUpdated!)
          : FieldValue.serverTimestamp(),
    };
  }
  

  LockModel copyWith({
    String? name,
    bool? isLocked,
    bool? isOnline,
    DateTime? lastUpdated,
    List<String>? sharedWith,
  }) {
    return LockModel(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      isLocked: isLocked ?? this.isLocked,
      isOnline: isOnline ?? this.isOnline,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      sharedWith: sharedWith ?? this.sharedWith,
    );
  }
}
