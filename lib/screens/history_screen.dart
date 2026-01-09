import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  final String lockId;
  final bool isAdmin; // Thêm biến này để kiểm tra quyền xóa

  const HistoryScreen({
    super.key,
    required this.lockId,
    this.isAdmin = true, // Mặc định là true hoặc lấy từ Provider của bạn
  });

  // Dịch phương thức
  String _translateMethod(String? method) {
    switch (method) {
      case 'app': return 'Ứng dụng';
      case 'rfid': return 'Thẻ từ';
      case 'password': return 'Bàn phím';
      case 'button': return 'Nút bấm trong';
      case 'system': return 'Hệ thống';
      case 'warning': return 'Cảnh báo xâm nhập';
      default: return 'Không xác định';
    }
  }

  // Lấy màu sắc và Icon
  Map<String, dynamic> _getStyle(String action, String method) {
    if (method == 'warning') {
      return {'color': Colors.orange, 'icon': Icons.report_problem, 'bg': Colors.orange.shade50};
    }
    if (action == 'lock') {
      return {'color': Colors.blueGrey, 'icon': Icons.lock, 'bg': Colors.blueGrey.shade50};
    }
    return {'color': Colors.green, 'icon': Icons.lock_open, 'bg': Colors.green.shade50};
  }

  // Hàm xóa toàn bộ lịch sử
  Future<void> _clearAllHistory(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tất cả lịch sử?'),
        content: const Text('Hành động này không thể hoàn tác. Bạn có chắc chắn muốn xóa toàn bộ nhật ký của khóa này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('HỦY')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('XÓA HẾT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final batch = FirebaseFirestore.instance.batch();
      final snapshots = await FirebaseFirestore.instance
          .collection('locks')
          .doc(lockId)
          .collection('history')
          .get();

      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa sạch nhật ký hoạt động')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyQuery = FirebaseFirestore.instance
        .collection('locks')
        .doc(lockId)
        .collection('history')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Lịch sử hoạt động', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (isAdmin) // Chỉ Admin mới thấy nút xóa hết
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              onPressed: () => _clearAllHistory(context),
              tooltip: "Xóa tất cả",
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: historyQuery.snapshots(),
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
            separatorBuilder: (context, index) => Container(
              margin: const EdgeInsets.only(left: 24),
              height: 10,
              width: 2,
              color: Colors.grey.shade300,
            ),
            itemBuilder: (context, index) {
              final doc = logs[index];
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final style = _getStyle(data['action'] ?? '', data['method'] ?? '');

              // Hiển thị tiêu đề ngày (Hôm nay, Hôm qua...)
              bool showDateHeader = false;
              if (index == 0) {
                showDateHeader = true;
              } else {
                final prevDate = (logs[index - 1].data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                if (prevDate != null && DateFormat('ddMMyy').format(timestamp) != DateFormat('ddMMyy').format(prevDate.toDate())) {
                  showDateHeader = true;
                }
              }

              Widget itemCard = Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
                ),
              );

              // Nếu là Admin thì cho phép vuốt để xóa từng mục
              if (isAdmin) {
                itemCard = Dismissible(
                  key: Key(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
                  ),
                  onDismissed: (_) => doc.reference.delete(),
                  child: itemCard,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDateHeader) _buildDateHeader(timestamp),
                  itemCard,
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
    if (DateFormat('ddMMyy').format(date) == DateFormat('ddMMyy').format(now)) label = "Hôm nay";
    if (DateFormat('ddMMyy').format(date) == DateFormat('ddMMyy').format(now.subtract(const Duration(days: 1)))) label = "Hôm qua";

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Text(label, style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 16)),
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