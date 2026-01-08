import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Thêm thư viện intl vào pubspec.yaml

class HistoryScreen extends StatelessWidget {
  final String lockId;
  const HistoryScreen({super.key, required this.lockId});

  // Hàm hỗ trợ dịch phương thức sang tiếng Việt
  String _translateMethod(String? method) {
    switch (method) {
      case 'app': return 'Ứng dụng';
      case 'rfid': return 'Thẻ từ';
      case 'password': return 'Mật khẩu';
      case 'button': return 'Nút bấm trong';
      case 'system': return 'Hệ thống';
      default: return 'Không xác định';
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyRef = FirebaseFirestore.instance
        .collection('locks')
        .doc(lockId)
        .collection('history')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử hoạt động'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: historyRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có lịch sử nào.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final data = logs[index].data() as Map<String, dynamic>;
              
              // 1. Sửa lại đúng Key 'by' thay vì 'userName'
              final user = data['by'] ?? 'Ẩn danh';
              final action = data['action'] == 'lock' ? 'Đã đóng cửa' : 'Đã mở cửa';
              final method = _translateMethod(data['method']);
              
              // 2. Format thời gian đẹp hơn
              final timestamp = data['timestamp'] as Timestamp?;
              final timeString = timestamp != null 
                  ? DateFormat('HH:mm - dd/MM/yyyy').format(timestamp.toDate())
                  : 'Đang cập nhật...';

              final isLock = data['action'] == 'lock';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isLock ? Colors.red.shade50 : Colors.green.shade50,
                    child: Icon(
                      isLock ? Icons.lock : Icons.lock_open,
                      color: isLock ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(
                    action,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isLock ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87, fontSize: 13),
                            children: [
                              const TextSpan(text: 'Bởi: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              TextSpan(text: '$user '),
                              TextSpan(
                                text: '($method)', 
                                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey)
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeString,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}