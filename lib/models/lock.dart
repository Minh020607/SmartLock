import 'package:cloud_firestore/cloud_firestore.dart';

class LockModel {
  final String id;          // ID duy nhất của khóa (trùng với id trong Firestore)
  final String name;        // Tên hiển thị (Cửa chính, Cửa sau, v.v.)
  final String topic;       // Topic MQTT cho khóa này
  final String ownerId;     // ID user sở hữu khóa (Firebase UID)
  bool isLocked;            // Trạng thái khóa/mở
  bool isOnline;            // Trạng thái kết nối MQTT
  DateTime? lastUpdated;    // Thời gian cập nhật gần nhất
  final List<String> sharedWith; // Danh sách UID được chia sẻ quyền đọc

  LockModel({
    required this.id,
    required this.name,
    required this.topic,
    required this.ownerId,
    this.isLocked = true,
    this.isOnline = false,
    this.lastUpdated,
    this.sharedWith = const [],
  });

  /// 🔄 Chuyển từ JSON (Firestore) sang LockModel
  factory LockModel.fromJson(Map<String, dynamic> json, String id) {
    final dynamic lastUpdated = json['lastUpdated'];

    return LockModel(
      id: id,
      name: json['name'] ?? 'Không tên',
      topic: json['topic'] ?? '',
      ownerId: json['ownerId'] ?? '',
      isLocked: json['isLocked'] ?? true,
      isOnline: json['isOnline'] ?? false,
      lastUpdated: lastUpdated is Timestamp
          ? lastUpdated.toDate()
          : (lastUpdated is String ? DateTime.tryParse(lastUpdated) : null),
      sharedWith: List<String>.from(json['sharedWith'] ?? []), // 👈 thêm dòng này
    );
  }

  /// 🔄 Chuyển LockModel thành JSON (để lưu lên Firestore)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'topic': topic,
      'ownerId': ownerId,
      'isLocked': isLocked,
      'isOnline': isOnline,
      'sharedWith': sharedWith, // 👈 thêm dòng này
      'lastUpdated': lastUpdated != null
          ? Timestamp.fromDate(lastUpdated!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// ⚙️ Hàm copy để cập nhật nhanh trong provider
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
      topic: topic,
      ownerId: ownerId,
      isLocked: isLocked ?? this.isLocked,
      isOnline: isOnline ?? this.isOnline,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      sharedWith: sharedWith ?? this.sharedWith, // 👈 thêm dòng này
    );
  }
}
