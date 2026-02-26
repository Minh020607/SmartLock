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

  // Dịch phương thức hoạt động chuẩn với code ESP32
  String _translateMethod(String? method) {
    switch (method) {
      case 'app': return 'Ứng dụng';
      case 'rfid': return 'Thẻ từ';
      case 'password': return 'Bàn phím';
      case 'button': return 'Nút bấm trong';
      case 'system': return 'Hệ thống';
      case 'warning': return 'Cảnh báo xâm nhập';
      case 'periodic': return 'Cập nhật pin định kỳ';
      case 'change_password': return 'Đổi mật khẩu'; // Đã khớp với code ESP32
      case 'auto_lock': return 'Tự động khóa';
      default: return method ?? 'Không xác định';
    }
  }

  // Lấy màu sắc, Icon và Tiêu đề tương ứng với hành động (ĐÃ FIX 100%)
  Map<String, dynamic> _getStyle(String action, String method) {
    // 1. TRƯỜNG HỢP CẢNH BÁO (Màu đỏ)
    if (action == 'warning' || method == 'warning') {
      return {
        'color': Colors.red, 
        'icon': Icons.report_problem_rounded, 
        'bg': Colors.red.shade50,
        'title': "CẢNH BÁO XÂM NHẬP!"
      };
    }
    
    // 2. TRƯỜNG HỢP ĐỔI MẬT KHẨU (Màu tím)
    if (action == 'change_password' || method == 'change_password') {
      return {
        'color': Colors.purple, 
        'icon': Icons.lock_reset_rounded, 
        'bg': Colors.purple.shade50,
        'title': "Đã đổi mật khẩu"
      };
    }

    // 3. TRƯỜNG HỢP CẬP NHẬT PIN (Màu xám)
    if (method == 'periodic') {
      return {
        'color': Colors.blueGrey, 
        'icon': Icons.battery_charging_full_rounded, 
        'bg': Colors.blueGrey.shade50,
        'title': "Cập nhật hệ thống"
      };
    }

    // 4. TRƯỜNG HỢP KHÓA (Xanh đen)
    if (action == 'lock') {
      return {
        'color': Colors.blueGrey.shade800, 
        'icon': Icons.lock_outline_rounded, 
        'bg': Colors.blueGrey.shade50,
        'title': "Đã khóa cửa"
      };
    }

    // 5. TRƯỜNG HỢP MỞ (Xanh lá)
    return {
      'color': Colors.green.shade700, 
      'icon': Icons.lock_open_rounded, 
      'bg': Colors.green.shade50,
      'title': "Đã mở cửa"
    };
  }

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
          if (isAdmin) 
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
              
              // Lấy Style đã fix
              final style = _getStyle(data['action'] ?? '', data['method'] ?? '');

              bool showDateHeader = false;
              if (index == 0) {
                showDateHeader = true;
              } else {
                final prevDoc = logs[index - 1].data() as Map<String, dynamic>;
                final prevDate = prevDoc['timestamp'] as Timestamp?;
                if (prevDate != null && 
                    DateFormat('ddMMyy').format(timestamp) != DateFormat('ddMMyy').format(prevDate.toDate())) {
                  showDateHeader = true;
                }
              }

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
                    style['title'], // Dùng title từ hàm style đã fix
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 15,
                      color: style['color'], // Màu tiêu đề đi theo icon
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

              if (isAdmin) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateHeader) _buildDateHeader(timestamp),
                    Dismissible(
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
                      onDismissed: (_) async => await doc.reference.delete(),
                      child: itemCard,
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateHeader) _buildDateHeader(timestamp),
                    itemCard,
                  ],
                );
              }
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