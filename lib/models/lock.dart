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
    this.rfidCards = const [],
  });

  factory LockModel.fromJson(Map<String, dynamic> json, String id) {
    // Xử lý chuyển đổi battery an toàn từ num (double/int) sang int
    int parsedBattery = 100;
    if (json['battery'] != null) {
      parsedBattery = (json['battery'] as num).toInt();
    }

    return LockModel(
      id: id,
      name: json['name'] ?? 'Không tên',
      ownerId: json['ownerId'] ?? '',
      // Hỗ trợ cả hai cách đặt tên key (locked hoặc isLocked) để đồng bộ với ESP32
      isLocked: json['isLocked'] ?? json['locked'] ?? true,
      isOnline: json['isOnline'] ?? json['online'] ?? false,
      battery: parsedBattery,
      lastUpdated: json['lastUpdated'] is Timestamp
          ? (json['lastUpdated'] as Timestamp).toDate()
          : null,
      sharedWith: (json['sharedWith'] as List?)?.map((e) => e.toString()).toList() ?? [],
      // Parse rfidCards an toàn, tránh lỗi khi trường này không tồn tại
      rfidCards: (json['rfidCards'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
    );
  }

  factory LockModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LockModel.fromJson(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ownerId': ownerId,
      'isLocked': isLocked,
      'isOnline': isOnline,
      'battery': battery, // Đừng quên lưu pin vào Firestore
      'sharedWith': sharedWith,
      'rfidCards': rfidCards,
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
    List<Map<String, dynamic>>? rfidCards,
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
      rfidCards: rfidCards ?? this.rfidCards,
    );
  }
}