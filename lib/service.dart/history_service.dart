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
  Future<void> clearAllHistory(String lockId) async {
  final batch = FirebaseFirestore.instance.batch();
  final collection = FirebaseFirestore.instance
      .collection('locks')
      .doc(lockId)
      .collection('history');

  final snapshots = await collection.get();
  
  for (final doc in snapshots.docs) {
    batch.delete(doc.reference);
  }

  await batch.commit();
}
}

final historyService = HistoryService();
