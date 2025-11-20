import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> save(String lockId, String action) async {
    final user = _auth.currentUser!;
    final doc = _firestore.collection("locks/$lockId/history").doc();

    await doc.set({
      "action": action,
      "timestamp": FieldValue.serverTimestamp(),
      "userId": user.uid,
      "userName": user.email,
    });
  }
}

final historyService = HistoryService();
