import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lock.dart';
import '../service.dart/mqtt_service.dart';
import '../service.dart/history_service.dart';

class LockNotifier extends StateNotifier<List<LockModel>> {
 LockNotifier() : super([]) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _init();
      }
    });
  }

  final _db = FirebaseFirestore.instance.collection("locks");
  final _auth = FirebaseAuth.instance;

  StreamSubscription? _lockSub;
  final Set<String> _mqttSubscribed = {};
  String _role = 'user';

  // ======================================================
  // INIT
  // ======================================================
  Future<void> _init() async {
  if (!mounted) return;

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
      return;
    }

    _role = userDoc.data()?['role'] ?? 'user';

    print("👤 USER ROLE = $_role");

  } catch (e) {
    print("❌ LOAD ROLE FAILED: $e");
    _role = 'user';
    return;
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


  // ======================================================
  // SNAPSHOT
  // ======================================================
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
  // MQTT CONFIRM (ESP32 → APP)
  // ======================================================
  Future<void> _onMqttMessage(String lockId, Map<String, dynamic> data) async {
    if (_auth.currentUser == null) return;
    // Kiểm tra thêm cả phím battery để đảm bảo dữ liệu hợp lệ
    if (!data.containsKey("locked") && !data.containsKey("battery")) return;

    print("📡 Cập nhật Firestore từ MQTT: Pin = ${data["battery"]}%");

    // Cập nhật trạng thái khóa VÀ PIN lên Firestore
    await _db.doc(lockId).update({
      "isLocked": data["locked"] ?? true,
      "isOnline": data["online"] ?? true,
      "battery": data["battery"] ?? 100, // 🔥 THÊM DÒNG NÀY
      "lastUpdated": FieldValue.serverTimestamp(),
    });

    // Chỉ lưu lịch sử khi KHÔNG PHẢI là tự động khóa (auto_lock)
    if (data["method"] != "auto_lock") {
      await historyService.save(
        lockId: lockId,
        action: data["locked"] ? "lock" : "unlock",
        method: data["method"] ?? "unknown",
        by: data["by"] ?? "Người dùng ẩn danh",
      );
    }
  }

  // ======================================================
  // USER ACTION (SEND REQUEST ONLY)
  // ======================================================
  Future<void> toggleLock(String lockId) async {
  final lock = state.firstWhere((l) => l.id == lockId);
  final user = _auth.currentUser;
  if (user == null) return;

  final email = user.email!.toLowerCase().trim();

  if (!isAdmin && !lock.sharedWith.contains(email)) {
    throw Exception("❌ Bạn không có quyền mở khóa này");
  }

  await mqttService.sendCommand(
    lockId,
    !lock.isLocked,
    email,
  );
}


  // ======================================================
  // ADMIN ONLY
  // ======================================================
  void _requireAdmin() {
    if (!isAdmin) {
      throw Exception("❌ Bạn không có quyền admin");
    }
  }

  Future<void> addLock(String id, String name) async {
    _requireAdmin();

    final user = _auth.currentUser!;
    final ref = _db.doc(id);

    await ref.set({
      "name": name,
      "ownerId": user.uid,
      "isLocked": true,
      "isOnline": false,
      "battery": 0,
      "sharedWith": [],
      "lastUpdated": FieldValue.serverTimestamp(),
    });

    await historyService.save(
      lockId: id,
      action: "lock",
      method: "system",
      by: user.email!,
    );
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

  await historyService.save(
    lockId: lockId,
    action: "share",
    method: "system",
    by: normalizedEmail,
  );
}



  Future<void> unshareLock(String lockId, String email) async {
  _requireAdmin();

  final normalizedEmail = email.toLowerCase().trim();

  await _db.doc(lockId).update({
    "sharedWith": FieldValue.arrayRemove([normalizedEmail])
  });

  await historyService.save(
    lockId: lockId,
    action: "unshare",
    method: "system",
    by: normalizedEmail,
  );
}



  Future<void> updateLock(
  String lockId,
  Map<String, dynamic> update,
) async {
  await _db.doc(lockId).update(update);
}

  // ======================================================
  // FIND USER
  // ======================================================
  Future<String?> findUserUidByEmail(String email) async {
  final normalizedEmail = email.toLowerCase().trim();

  final query = await FirebaseFirestore.instance
      .collection("users")
      .where("email", isEqualTo: normalizedEmail)
      .limit(1)
      .get();

  return query.docs.isEmpty ? null : query.docs.first.id;
}


  @override
void dispose() {
  _lockSub?.cancel();
  _lockSub = null;
  mqttService.unsubscribeAll(); 
  super.dispose();
}
}

// Provider
final lockProvider =
    StateNotifierProvider<LockNotifier, List<LockModel>>(
  (ref) => LockNotifier(),
);
