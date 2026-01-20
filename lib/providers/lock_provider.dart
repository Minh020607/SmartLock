import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lock.dart';
import '../service.dart/mqtt_service.dart';
import '../service.dart/history_service.dart';
import 'dart:convert';

class LockNotifier extends StateNotifier<List<LockModel>> {
  LockNotifier() : super([]) {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _init();
      } else {
        _lockSub?.cancel();
        state = [];
      }
    });
  }

  final _db = FirebaseFirestore.instance.collection("locks");
  final _auth = FirebaseAuth.instance;
  String? pendingCardId;

  StreamSubscription? _lockSub;
  final Set<String> _mqttSubscribed = {};
  String _role = 'user';

  // ======================================================
  // KHỞI TẠO HỆ THỐNG
  // ======================================================
  Future<void> _init() async {
    await _lockSub?.cancel();
    _lockSub = null;
    state = [];
    _mqttSubscribed.clear();

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        _role = 'user';
      } else {
        _role = userDoc.data()?['role'] ?? 'user';
      }
      print("👤 USER ROLE = $_role");
    } catch (e) {
      _role = 'user';
    }

    if (_role == 'admin') {
      _lockSub = _db.snapshots().listen(_onSnapshot);
    } else {
      final email = user.email!.toLowerCase().trim();
      _lockSub = _db
          .where("sharedWith", arrayContains: email)
          .snapshots()
          .listen(_onSnapshot);
    }

    // Gán callback nhận tin nhắn từ MQTT
    mqttService.onMessage = _onMqttMessage;
  }

  bool get isAdmin => _role == 'admin';

  // Lắng nghe thay đổi từ Firestore
  void _onSnapshot(QuerySnapshot snapshot) {
    state = snapshot.docs
        .map((d) => LockModel.fromFirestore(d))
        .toList();

    for (final lock in state) {
      if (_mqttSubscribed.add(lock.id)) {
        mqttService.subscribeLock(lock.id);
      }
    }
  }

  // ======================================================
  // XỬ LÝ TIN NHẮN MQTT (ESP32 -> APP)
  // ======================================================
  Future<void> _onMqttMessage(String lockId, Map<String, dynamic> data) async {
    if (_auth.currentUser == null) return;

    // A. Phát hiện ID thẻ RFID mới (Chế độ học thẻ)
    if (data.containsKey("pending_id")) {
  pendingCardId = data["pending_id"].toString();
  // Kích hoạt cập nhật state để UI nhận biết có sự thay đổi
  state = [...state]; 
  return;
}

    // B. Cập nhật trạng thái Pin và Khóa
    if (!data.containsKey("locked") && !data.containsKey("battery")) return;

    await _db.doc(lockId).update({
      "isLocked": data["locked"] ?? true,
      "isOnline": data["online"] ?? true,
      "battery": data["battery"] ?? 100,
      "lastUpdated": FieldValue.serverTimestamp(),
    });

    // C. Lưu lịch sử hành động (Bỏ qua tin nhắn định kỳ)
    final String method = data["method"] ?? "unknown";
    final List<String> ignore = ["auto_lock", "periodic", "boot"];
    
    if (!ignore.contains(method)) {
      await historyService.save(
        lockId: lockId,
        action: data["locked"] ? "lock" : "unlock",
        method: method,
        by: data["by"] ?? "Hệ thống",
      );
    }
  }

  // ======================================================
  // QUẢN LÝ THẺ RFID
  // ======================================================
  
  // Gửi lệnh học thẻ xuống ESP32
  void publishStartLearning(String lockId) {
    final topic = "smartlock/$lockId/cmd";
    final payload = jsonEncode({"action": "START_LEARNING", "by": "Admin"});
    mqttService.publish(topic, payload); 
  }

  // Thêm thẻ mới vào danh sách và gửi xuống ESP32
  Future<void> addRfidCard(String lockId, String cardId, String cardName) async {
    // 1. Cập nhật Firestore
    await _db.doc(lockId).update({
      'rfidCards': FieldValue.arrayUnion([{
        'id': cardId,
        'name': cardName,
        'createdAt': DateTime.now().toIso8601String(),
      }])
    });

    // 2. Gửi lệnh ADD_CARD xuống ESP32 qua MQTT
    final topic = "smartlock/$lockId/cmd";
    final payload = jsonEncode({
      "action": "ADD_CARD",
      "id": cardId, // ESP32 sẽ dùng ID này để lưu vào Preferences
    });
    
    mqttService.publish(topic, payload);
    print("📡 Đã gửi lệnh ADD_CARD cho thẻ $cardId xuống khóa $lockId");
    
    // Reset pending ID sau khi đã xử lý xong
    pendingCardId = null;
    state = [...state];
  }

  // Xóa thẻ RFID khỏi Firestore và ESP32
  Future<void> removeRfidCard(String lockId, Map<String, dynamic> cardData) async {
    try {
      // 1. Xóa trên Firestore
      await _db.doc(lockId).update({
        'rfidCards': FieldValue.arrayRemove([cardData])
      });

      // 2. Gửi lệnh REMOVE_CARD xuống ESP32
      final topic = "smartlock/$lockId/cmd";
      final payload = jsonEncode({
        "action": "REMOVE_CARD",
        "id": cardData['id'].toString().toUpperCase(), // ID thẻ cần xóa
      });
      
      mqttService.publish(topic, payload);
      print("📡 Đã gửi lệnh REMOVE_CARD cho thẻ ${cardData['id']}");

    } catch (e) {
      print("❌ Lỗi xóa thẻ: $e");
    }
  }

  // ======================================================
  // HÀNH ĐỘNG NGƯỜI DÙNG & ADMIN
  // ======================================================

  // Đóng/Mở khóa nhanh
  Future<void> toggleLock(String lockId) async {
    final lock = state.firstWhere((l) => l.id == lockId);
    final email = _auth.currentUser?.email ?? "User";
    await mqttService.sendCommand(lockId, !lock.isLocked, email);
  }

  // Thêm khóa mới (Admin)
  Future<void> addLock(String id, String name) async {
    _requireAdmin();
    await _db.doc(id).set({
      "name": name,
      "ownerId": _auth.currentUser!.uid,
      "isLocked": true,
      "isOnline": false,
      "battery": 0,
      "sharedWith": [],
      "rfidCards": [],
      "lastUpdated": FieldValue.serverTimestamp(),
    });
  }

  // Xóa khóa (Admin)
  Future<void> removeLock(String lockId) async {
    _requireAdmin();
    await _db.doc(lockId).delete();
  }

  // Chia sẻ quyền truy cập
  Future<void> shareLock(String lockId, String email) async {
    _requireAdmin();
    final normalizedEmail = email.toLowerCase().trim();
    await _db.doc(lockId).update({
      "sharedWith": FieldValue.arrayUnion([normalizedEmail])
    });
  }

  // Gỡ quyền truy cập
  Future<void> unshareLock(String lockId, String email) async {
    _requireAdmin();
    final normalizedEmail = email.toLowerCase().trim();
    await _db.doc(lockId).update({
      "sharedWith": FieldValue.arrayRemove([normalizedEmail])
    });
  }

  // Cập nhật thông tin khóa (Tên, cấu hình...)
  Future<void> updateLock(String lockId, Map<String, dynamic> data) async {
    await _db.doc(lockId).update(data);
  }

  // Gửi lệnh JSON thô (Dùng cho các tính năng mở rộng)
  void publishRaw(String lockId, Map<String, dynamic> data) {
    final topic = "smartlock/$lockId/cmd";
    mqttService.publish(topic, jsonEncode(data));
  }

  // Tìm UID qua Email
  Future<String?> findUserUidByEmail(String email) async {
    final query = await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: email.toLowerCase().trim())
        .limit(1)
        .get();
    return query.docs.isEmpty ? null : query.docs.first.id;
  }

  void _requireAdmin() {
    if (!isAdmin) throw Exception("❌ Bạn không có quyền admin");
  }

  @override
  void dispose() {
    _lockSub?.cancel();
    mqttService.unsubscribeAll();
    super.dispose();
  }
}

// Provider khai báo theo chuẩn Riverpod mới
final lockProvider = StateNotifierProvider<LockNotifier, List<LockModel>>(
  (ref) => LockNotifier(),
);