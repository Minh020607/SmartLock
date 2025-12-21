import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> save({
    required String lockId,
    required String action,   // lock | unlock | share | unshare
    required String method,   // app | rfid | password | system
    required String by,       // email | device
  }) async {
    await _firestore
        .collection("locks")
        .doc(lockId)
        .collection("history")
        .add({
      "action": action,
      "method": method,
      "by": by,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }
}

final historyService = HistoryService();
