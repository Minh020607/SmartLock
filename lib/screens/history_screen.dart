import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  final String lockId;
  const HistoryScreen({super.key, required this.lockId});

  String _translateMethod(String? method) {
    switch (method) {
      case 'app': return 'Ứng dụng';
      case 'rfid': return 'Thẻ từ';
      case 'password': return 'Bàn phím';
      case 'button': return 'Nút bấm trong';
      case 'system': return 'Hệ thống';
      case 'warning': return 'Cảnh báo'; // Thêm cảnh báo cho sai pass/thẻ
      default: return 'Không xác định';
    }
  }

  // Hàm lấy màu sắc và icon theo loại hành động
  Map<String, dynamic> _getStyle(String action, String method) {
    if (method == 'warning') {
      return {'color': Colors.orange, 'icon': Icons.report_problem, 'bg': Colors.orange.shade50};
    }
    if (action == 'lock') {
      return {'color': Colors.blueGrey, 'icon': Icons.lock, 'bg': Colors.blueGrey.shade50};
    }
    return {'color': Colors.green, 'icon': Icons.lock_open, 'bg': Colors.green.shade50};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Nền xám nhạt cho sạch sẽ
      appBar: AppBar(
        title: const Text('Lịch sử hoạt động', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('locks')
            .doc(lockId)
            .collection('history')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final logs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (context, index) {
              // Vẽ đường gạch nối giữa các item (tạo hiệu ứng timeline)
              return Container(
                margin: const EdgeInsets.only(left: 24),
                height: 10,
                width: 2,
                color: Colors.grey.shade300,
              );
            },
            itemBuilder: (context, index) {
              final data = logs[index].data() as Map<String, dynamic>;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final style = _getStyle(data['action'] ?? '', data['method'] ?? '');
              
              // Logic hiển thị tiêu đề ngày nếu có sự thay đổi ngày
              bool showDateHeader = false;
              if (index == 0) {
                showDateHeader = true;
              } else {
                final prevData = logs[index - 1].data() as Map<String, dynamic>;
                final prevDate = (prevData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                if (DateFormat('ddMMyyyy').format(timestamp) != DateFormat('ddMMyyyy').format(prevDate)) {
                  showDateHeader = true;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDateHeader) _buildDateHeader(timestamp),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: style['bg'], shape: BoxShape.circle),
                        child: Icon(style['icon'], color: style['color'], size: 24),
                      ),
                      title: Text(
                        data['method'] == 'warning' ? "Phát hiện xâm nhập!" : (data['action'] == 'lock' ? 'Đã khóa cửa' : 'Đã mở cửa'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            "Bởi: ${data['by'] ?? 'Hệ thống'} • ${_translateMethod(data['method'])}",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('HH:mm:ss').format(timestamp),
                            style: TextStyle(color: Colors.blueAccent.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    String label = DateFormat('dd/MM/yyyy').format(date);
    final now = DateTime.now();
    if (DateFormat('ddMMyyyy').format(date) == DateFormat('ddMMyyyy').format(now)) {
      label = "Hôm nay";
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Text(
        label,
        style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Chưa có dữ liệu hoạt động', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }
}