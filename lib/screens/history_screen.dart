import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_lock/providers/lock_provider.dart';

class HistoryScreen extends ConsumerWidget {
  final String lockId;

  const HistoryScreen({
    super.key,
    required this.lockId,
  });

  // Dịch phương thức hoạt động
  String _translateMethod(String? method) {
    switch (method) {
      case 'app': return 'Ứng dụng';
      case 'rfid': return 'Thẻ từ';
      case 'password': return 'Bàn phím';
      case 'button': return 'Nút bấm trong';
      case 'system': return 'Hệ thống';
      case 'warning': return 'Cảnh báo xâm nhập';
      case 'periodic': return 'Cập nhật pin định kỳ';
      case 'change_pass': return 'Đổi mật khẩu';
      case 'auto_lock': return 'Tự động khóa';
      default: return 'Không xác định';
    }
  }

  // Lấy màu sắc và Icon tương ứng với hành động
  Map<String, dynamic> _getStyle(String action, String method) {
    if (method == 'warning') {
      return {'color': Colors.redAccent, 'icon': Icons.report_gmailerrorred_rounded, 'bg': Colors.red.shade50};
    }
    if (method == 'periodic') {
      return {'color': Colors.grey, 'icon': Icons.battery_charging_full_rounded, 'bg': Colors.grey.shade100};
    }
    if (method == 'change_pass') {
      return {'color': Colors.purple, 'icon': Icons.vpn_key_rounded, 'bg': Colors.purple.shade50};
    }
    if (action == 'lock') {
      return {'color': Colors.blueGrey, 'icon': Icons.lock, 'bg': Colors.blueGrey.shade50};
    }
    return {'color': Colors.green, 'icon': Icons.lock_open, 'bg': Colors.green.shade50};
  }

  // Hàm xóa toàn bộ lịch sử (Chỉ dành cho Admin)
  Future<void> _clearAllHistory(BuildContext context, bool isAdmin) async {
    if (!isAdmin) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tất cả lịch sử?'),
        content: const Text('Hành động này không thể hoàn tác. Bạn có chắc chắn muốn xóa toàn bộ nhật ký?'),
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
      try {
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
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lỗi: Bạn không có quyền xóa lịch sử')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔥 Lấy quyền Admin từ Provider
    final isAdmin = ref.watch(lockProvider.notifier).isAdmin;

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
          if (isAdmin) // 🛡️ CHỈ HIỆN NÚT XÓA NẾU LÀ ADMIN
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              onPressed: () => _clearAllHistory(context, isAdmin),
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
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = logs[index];
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final style = _getStyle(data['action'] ?? '', data['method'] ?? '');

              // Logic hiển thị tiêu đề ngày (Hôm nay, Hôm qua...)
              bool showDateHeader = false;
              if (index == 0) {
                showDateHeader = true;
              } else {
                final prevDate = (logs[index - 1].data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                if (prevDate != null && 
                    DateFormat('ddMMyy').format(timestamp) != DateFormat('ddMMyy').format(prevDate.toDate())) {
                  showDateHeader = true;
                }
              }

              // Card nội dung hiển thị lịch sử
              Widget itemCard = Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03), 
                      blurRadius: 10, 
                      offset: const Offset(0, 4)
                    )
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
                    data['method'] == 'warning' 
                        ? "PHÁT HIỆN XÂM NHẬP!" 
                        : (data['action'] == 'lock' ? 'Đã khóa cửa' : 'Đã mở cửa'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 15,
                      color: data['method'] == 'warning' ? Colors.red : Colors.black87,
                    ),
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

              // 🛡️ PHÂN QUYỀN VUỐT ĐỂ XÓA
              Widget finalWidget;
              if (isAdmin) {
                // Admin: Có thể vuốt để xóa
                finalWidget = Dismissible(
                  key: Key(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent, 
                      borderRadius: BorderRadius.circular(16)
                    ),
                    child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
                  ),
                  onDismissed: (_) async {
                    try {
                      await doc.reference.delete();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lỗi: Không thể xóa dữ liệu')),
                        );
                      }
                    }
                  },
                  child: itemCard,
                );
              } else {
                // Người thường: Không bao bọc Dismissible -> Không thể vuốt
                finalWidget = itemCard;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDateHeader) _buildDateHeader(timestamp),
                  finalWidget,
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