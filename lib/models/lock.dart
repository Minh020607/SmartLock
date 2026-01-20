import 'package:cloud_firestore/cloud_firestore.dart';

class LockModel {
  final String id;
  final String name;
  final String ownerId;
  bool isLocked;
  bool isOnline;
  DateTime? lastUpdated;
  final List<String> sharedWith;
  final int battery;
  // ⭐ Bổ sung trường này
  final List<Map<String, dynamic>> rfidCards; 

  LockModel({
    required this.id,
    required this.name,
    required this.ownerId,
    this.isLocked = true,
    this.isOnline = false,
    this.lastUpdated,
    this.sharedWith = const [],
    required this.battery,
    this.rfidCards = const [], // Mặc định là danh sách rỗng
  });

  factory LockModel.fromJson(Map<String, dynamic> json, String id) {
    return LockModel(
      id: id,
      name: json['name'] ?? 'Không tên',
      ownerId: json['ownerId'] ?? '',
      isLocked: json['locked'] ?? json['isLocked'] ?? true,
      isOnline: json['online'] ?? json['isOnline'] ?? false,
      battery: json.containsKey('battery') ? (json['battery'] as num).toInt() : 100,
      lastUpdated: json['lastUpdated'] is Timestamp
          ? (json['lastUpdated'] as Timestamp).toDate()
          : null,
      sharedWith: List<String>.from(json['sharedWith'] ?? []),
      // ⭐ Bổ sung parse dữ liệu thẻ rfid
      rfidCards: List<Map<String, dynamic>>.from(json['rfidCards'] ?? []),
    );
  }

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
      'rfidCards': rfidCards, // ⭐ Bổ sung lưu vào Firestore
      'lastUpdated': lastUpdated != null
          ? Timestamp.fromDate(lastUpdated!)
          : FieldValue.serverTimestamp(),
    };
  }

  LockModel copyWith({
    String? name,
    bool? isLocked,
    bool? isOnline,
    int? battery,
    DateTime? lastUpdated,
    List<String>? sharedWith,
    List<Map<String, dynamic>>? rfidCards, // ⭐ Thêm vào đây
  }) {
    return LockModel(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      isLocked: isLocked ?? this.isLocked,
      isOnline: isOnline ?? this.isOnline,
      battery: battery ?? this.battery,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      sharedWith: sharedWith ?? this.sharedWith,
      rfidCards: rfidCards ?? this.rfidCards, // ⭐ Cập nhật giá trị
    );
  }
}