import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lock.dart';
import '../service.dart/mqtt_service.dart';

class LockNotifier extends StateNotifier<List<LockModel>> {
  LockNotifier() : super([]) {
    _init();
  }

  final _db = FirebaseFirestore.instance.collection("locks");
  final _auth = FirebaseAuth.instance;

  StreamSubscription? _lockSub;
  final Set<String> _mqttSubscribed = {};

  // ======================================================
  // INIT
  // ======================================================
  Future<void> _init() async {
    await _lockSub?.cancel();
    _mqttSubscribed.clear();
    state = [];

    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    final role = userDoc.data()?['role'];

    // =========================
    // ADMIN → ALL LOCKS
    // =========================
    if (role == 'admin') {
      _lockSub = _db.snapshots().listen(_onSnapshot);
    }

    // =========================
    // USER → SHARED ONLY
    // =========================
    else {
      _lockSub = _db
          .where("sharedWith", arrayContains: user.email)
          .snapshots()
          .listen(_onSnapshot);
    }

    mqttService.onMessage = _onMqttMessage;
  }

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
  // MQTT
  // ======================================================
  Future<void> _onMqttMessage(
    String lockId,
    Map<String, dynamic> data,
  ) async {
    await updateLock(lockId, {
      "isLocked": data["locked"],
      "isOnline": data["online"],
      "lastUpdated": DateTime.now(),
    });

    await addHistory(
      lockId,
      data["locked"] ? "Đã khóa" : "Đã mở khóa",
    );
  }

  // ======================================================
  // CORE
  // ======================================================
  Future<void> updateLock(
    String lockId,
    Map<String, dynamic> update,
  ) async {
    await _db.doc(lockId).update(update);
  }

  Future<void> toggleLock(String lockId) async {
    final lock = state.firstWhere((l) => l.id == lockId);

    await mqttService.sendCommand(lockId, !lock.isLocked);

    await addHistory(
      lockId,
      !lock.isLocked ? "Yêu cầu khóa" : "Yêu cầu mở khóa",
    );
  }

  // ======================================================
  // ADMIN ONLY
  // ======================================================
  Future<void> addLock(String id, String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (userDoc.data()?['role'] != 'admin') {
      throw Exception("Không có quyền thêm khóa");
    }

    final ref = _db.doc(id);

    await ref.set({
      "name": name,
      "ownerId": user.uid,
      "isLocked": true,
      "isOnline": false,
      "lastUpdated": DateTime.now(),
      "sharedWith": [],
    });

    await ref.collection("history").add({
      "action": "Khởi tạo khóa",
      "timestamp": DateTime.now(),
      "by": user.email,
    });
  }

  Future<void> removeLock(String lockId) async {
    await _db.doc(lockId).delete();
  }

  // ======================================================
  // SHARE
  // ======================================================
  Future<void> shareLock(String lockId, String email) async {
    await _db.doc(lockId).update({
      "sharedWith": FieldValue.arrayUnion([email])
    });

    await addHistory(lockId, "Chia sẻ quyền cho $email");
  }

  Future<void> unshareLock(String lockId, String email) async {
    await _db.doc(lockId).update({
      "sharedWith": FieldValue.arrayRemove([email])
    });

    await addHistory(lockId, "Hủy chia sẻ quyền của $email");
  }

  // ======================================================
  // HISTORY
  // ======================================================
  Future<void> addHistory(String lockId, String action) async {
    final user = _auth.currentUser;

    await _db.doc(lockId).collection("history").add({
      "action": action,
      "timestamp": DateTime.now(),
      "by": user?.email,
    });
  }

  // ======================================================
  // CLEANUP
  // ======================================================
  // ======================================================
// 🔍 FIND USER UID BY EMAIL
// ======================================================
Future<String?> findUserUidByEmail(String email) async {
  final query = await FirebaseFirestore.instance
      .collection("users")
      .where("email", isEqualTo: email)
      .limit(1)
      .get();

  if (query.docs.isEmpty) return null;

  return query.docs.first.id;
}

  @override
  void dispose() {
    _lockSub?.cancel();
    super.dispose();
  }
}

// Provider
final lockProvider =
    StateNotifierProvider<LockNotifier, List<LockModel>>(
  (ref) => LockNotifier(),
);
