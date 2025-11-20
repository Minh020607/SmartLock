import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_lock/models/lock.dart';

class LockNotifier extends StateNotifier<List<LockModel>> {
  LockNotifier() : super([]) {
    _waitForUserAndListen();
  }

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  StreamSubscription? _subscription;
  StreamSubscription? _authSub;

  /// 🧩 Lắng nghe trạng thái đăng nhập
  Future<void> _waitForUserAndListen() async {
    _authSub = _auth.authStateChanges().listen((user) {
      _subscription?.cancel();
      if (user != null) {
        _listenToUserLocks(user.uid, user.email ?? "");
      } else {
        state = [];
      }
    });
  }

  /// 🔄 Lắng nghe danh sách khóa thuộc quyền người dùng (chủ hoặc được chia sẻ)
  void _listenToUserLocks(String userId, String userEmail) {
    _subscription = _firestore
        .collection('locks')
        .where(
          Filter.or(
            Filter('ownerId', isEqualTo: userId),
            Filter('sharedWith', arrayContains: userEmail),
          ),
        )
        .snapshots()
        .listen((snapshot) {
      final locks = snapshot.docs
          .map((doc) => LockModel.fromJson(doc.data(), doc.id))
          .toList();

      // Sắp xếp theo thời gian cập nhật mới nhất
      locks.sort((a, b) {
        final t1 = a.lastUpdated?.millisecondsSinceEpoch ?? 0;
        final t2 = b.lastUpdated?.millisecondsSinceEpoch ?? 0;
        return t2.compareTo(t1);
      });

      state = locks;
    });
  }

  /// check email được chia sẻ
  Future<String?> findUserUidByEmail(String email) async {
  final query = await FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: email)
      .limit(1)
      .get();

  if (query.docs.isEmpty) return null;
  return query.docs.first.id; // trả về UID
}


  /// 👥 Chia sẻ khóa với email người dùng
  Future<void> shareLockWithUser(String lockId, String userEmail) async {
    final docRef = _firestore.collection('locks').doc(lockId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final List<dynamic> current = data['sharedWith'] ?? [];

      if (!current.contains(userEmail)) {
        current.add(userEmail);
        transaction.update(docRef, {
          'sharedWith': current,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// 🚫 Hủy chia sẻ khóa với người dùng theo email
  Future<void> unshareLock(String lockId, String userEmail) async {
    final docRef = _firestore.collection('locks').doc(lockId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final List<dynamic> current = data['sharedWith'] ?? [];

      if (current.contains(userEmail)) {
        current.remove(userEmail);
        transaction.update(docRef, {
          'sharedWith': current,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// ➕ Thêm khóa mới
  Future<void> addLock(LockModel lock) async {
    await _firestore.collection('locks').doc(lock.id).set({
      ...lock.toJson(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

 /// ❌ Xóa khóa và lịch sử
Future<void> removeLock(String lockId) async {
  final lockRef = _firestore.collection('locks').doc(lockId);

  // 1. Lấy tất cả document trong subcollection history
  final historySnapshot = await lockRef.collection('history').get();

  final batch = _firestore.batch();

  // 2. Xóa tất cả document history
  for (var doc in historySnapshot.docs) {
    batch.delete(doc.reference);
  }

  // 3. Xóa document khóa
  batch.delete(lockRef);

  // 4. Commit batch
  await batch.commit();
}


  /// ✏️ Cập nhật thông tin khóa
  Future<void> updateLock(String id, Map<String, dynamic> data) async {
    await _firestore.collection('locks').doc(id).update(data);
  }

  /// 🔒 Bật/tắt trạng thái khóa
  Future<void> toggleLock(String id) async {
    final current = state.firstWhere((lock) => lock.id == id);
    final updated = current.copyWith(
      isLocked: !current.isLocked,
      lastUpdated: DateTime.now(),
    );
    final newStatus = !current.isLocked;
    final user = _auth.currentUser;

    await _firestore.collection('locks').doc(id).update(updated.toJson());

    // ➕ Ghi lịch sử
  await _firestore
      .collection('locks')
      .doc(id)
      .collection('history')
      .add({
    'action': newStatus ? 'lock' : 'unlock',
    'userId': user?.uid ?? 'unknown',
    'userName': user?.email ?? 'Ẩn danh',
    'timestamp': FieldValue.serverTimestamp(),
  });
  }

  /// 🧹 Hủy lắng nghe khi dispose
  @override
  void dispose() {
    _subscription?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}

/// 🔗 Provider Riverpod
final lockProvider =
    StateNotifierProvider<LockNotifier, List<LockModel>>((ref) {
  return LockNotifier();
});
