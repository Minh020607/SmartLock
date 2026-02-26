import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart'; // Giữ nguyên Legacy theo ý bạn
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

    mqttService.onMessage = _onMqttMessage;
  }

  bool get isAdmin => _role == 'admin';

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
  // XỬ LÝ TIN NHẮN MQTT (PHẦN SỬA CHÍNH)
  // ======================================================
  Future<void> _onMqttMessage(String lockId, Map<String, dynamic> data) async {
  if (_auth.currentUser == null) return;

  // ======================================================
  // A. PHÁT HIỆN ID THẺ RFID MỚI (CHẾ ĐỘ HỌC LỆNH)
  // ======================================================
  if (data.containsKey("pending_id")) {
    pendingCardId = data["pending_id"].toString();
    state = [...state]; 
    return;
  }

  // ======================================================
  // B. CẬP NHẬT TRẠNG THÁI HIỂN THỊ (PIN/KHÓA/ONLINE)
  // Luôn cập nhật trạng thái này lên Firestore để đổi màu icon App
  // ======================================================
  if (data.containsKey("locked") || data.containsKey("battery") || data.containsKey("online")) {
    await _db.doc(lockId).update({
      if (data.containsKey("locked")) "isLocked": data["locked"],
      if (data.containsKey("battery")) "battery": data["battery"],
      if (data.containsKey("online")) "isOnline": data["online"],
      "lastUpdated": FieldValue.serverTimestamp(),
    });
  }

  // ======================================================
  // C. XỬ LÝ LƯU LỊCH SỬ (CHỐT CHẶN CHỐNG LẶP & SAI MK)
  // ======================================================
  
  // 1. CHỐT CHẶN 1: Nếu ESP32 gửi save: false (như lệnh khóa tự động) -> THOÁT NGAY
  if (data["save"] != true) {
    print("ℹ️ MQTT: Chỉ cập nhật giao diện, không ghi lịch sử.");
    return;
  }

  final String method = data["method"] ?? "unknown";

  // 2. CHỐT CHẶN 2: Danh sách các loại tin nhắn "rác" không được ghi vào lịch sử
  // auto_lock: Chặn dòng thứ 2 khi cửa tự đóng
  // periodic/boot: Chặn tin nhắn cập nhật định kỳ hoặc khởi động lại
  final List<String> ignoreMethods = ["periodic", "boot", "auto_lock"];
  if (ignoreMethods.contains(method)) return;

  // 3. XÁC ĐỊNH NHÃN HÀNH ĐỘNG (Để HistoryScreen hiện đúng màu/biểu tượng)
  String actionLabel = (data["locked"] == true) ? "lock" : "unlock";

  if (method == "change_password") {
    actionLabel = "change_password"; // Màu Tím
  } else if (method == "warning") {
    actionLabel = "warning";         // Màu Đỏ (Dành cho Sai mật khẩu)
  }

  // 4. LƯU VÀO FIRESTORE
  try {
    await historyService.save(
      lockId: lockId,
      action: actionLabel,
      method: method,
      by: data["by"] ?? "Hệ thống",
    );
    print("✅ Đã ghi lịch sử: $actionLabel bởi $method");
  } catch (e) {
    print("❌ Lỗi Firestore: $e");
  }
}

  // --- CÁC HÀM CÒN LẠI GIỮ NGUYÊN HOÀN TOÀN ---

  void publishStartLearning(String lockId) {
    final topic = "smartlock/$lockId/cmd";
    final payload = jsonEncode({"action": "START_LEARNING", "by": "Admin"});
    mqttService.publish(topic, payload); 
  }

  Future<void> addRfidCard(String lockId, String cardId, String cardName) async {
    await _db.doc(lockId).update({
      'rfidCards': FieldValue.arrayUnion([{
        'id': cardId,
        'name': cardName,
        'createdAt': DateTime.now().toIso8601String(),
      }])
    });

    final topic = "smartlock/$lockId/cmd";
    final payload = jsonEncode({"action": "ADD_CARD", "id": cardId});
    mqttService.publish(topic, payload);
    
    pendingCardId = null;
    state = [...state];
  }

  Future<void> removeRfidCard(String lockId, Map<String, dynamic> cardData) async {
    try {
      await _db.doc(lockId).update({
        'rfidCards': FieldValue.arrayRemove([cardData])
      });
      final topic = "smartlock/$lockId/cmd";
      final payload = jsonEncode({
        "action": "REMOVE_CARD",
        "id": cardData['id'].toString().toUpperCase(),
      });
      mqttService.publish(topic, payload);
    } catch (e) {
      print("❌ Lỗi xóa thẻ: $e");
    }
  }

  Future<void> toggleLock(String lockId) async {
    final lock = state.firstWhere((l) => l.id == lockId);
    final email = _auth.currentUser?.email ?? "User";
    await mqttService.sendCommand(lockId, !lock.isLocked, email);
  }

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

  Future<void> removeLock(String lockId) async {
    _requireAdmin();
    await _db.doc(lockId).delete();
  }

  Future<void> shareLock(String lockId, String email) async {
    _requireAdmin();
    final normalizedEmail = email.toLowerCase().trim();
    await _db.doc(lockId).update({
      "sharedWith": FieldValue.arrayUnion([normalizedEmail])
    });
  }

  Future<void> unshareLock(String lockId, String email) async {
    _requireAdmin();
    final normalizedEmail = email.toLowerCase().trim();
    await _db.doc(lockId).update({
      "sharedWith": FieldValue.arrayRemove([normalizedEmail])
    });
  }

  Future<void> updateLock(String lockId, Map<String, dynamic> data) async {
    await _db.doc(lockId).update(data);
  }

  void publishRaw(String lockId, Map<String, dynamic> data) {
    final topic = "smartlock/$lockId/cmd";
    mqttService.publish(topic, jsonEncode(data));
  }

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

final lockProvider = StateNotifierProvider<LockNotifier, List<LockModel>>(
  (ref) => LockNotifier(),
);