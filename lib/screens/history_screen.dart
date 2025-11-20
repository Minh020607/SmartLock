import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  final String lockId;
  const HistoryScreen({super.key, required this.lockId});

  @override
  Widget build(BuildContext context) {
    final historyRef = FirebaseFirestore.instance
        .collection('locks')
        .doc(lockId)
        .collection('history')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử mở/đóng khóa'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: historyRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Chưa có lịch sử nào.'));
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final data = logs[index].data() as Map<String, dynamic>;
              final action = data['action'] == 'lock' ? 'Đóng khóa' : 'Mở khóa';
              final user = data['userName'] ?? 'Ẩn danh';
              final time = (data['timestamp'] as Timestamp?)?.toDate();

              return Card(
                child: ListTile(
                  leading: Icon(
                    data['action'] == 'lock'
                        ? Icons.lock
                        : Icons.lock_open,
                    color: data['action'] == 'lock'
                        ? Colors.red
                        : Colors.green,
                  ),
                  title: Text(action),
                  subtitle: Text(
                    'Người thực hiện: $user\nThời gian: ${time ?? 'Chưa có'}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
