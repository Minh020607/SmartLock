import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_lock/models/lock.dart';
import 'package:smart_lock/providers/lock_provider.dart';
import 'package:smart_lock/screens/history_screen.dart';
import 'package:smart_lock/screens/lock_settings_screen.dart';
import 'package:smart_lock/widgets/status_tile.dart';
import 'package:timeago/timeago.dart' as timeago;

class LockDetailScreen extends ConsumerWidget {
  final LockModel lock;
  const LockDetailScreen({super.key, required this.lock});

  // Hàm chọn Icon pin theo mức độ
  IconData _getBatteryIcon(int level) {
    if (level > 85) return Icons.battery_full;
    if (level > 70) return Icons.battery_6_bar;
    if (level > 50) return Icons.battery_4_bar;
    if (level > 30) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  // Hàm chọn màu pin (Đỏ khi yếu)
  Color _getBatteryColor(int level) {
    if (level > 20) return Colors.blueGrey;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(lockProvider.notifier);
    final updatedLock = ref.watch(lockProvider)
        .firstWhere((l) => l.id == lock.id, orElse: () => lock);

    return Scaffold(
      appBar: AppBar(
        title: Text(updatedLock.name),
        actions: [
          // Hiển thị Pin nhanh trên thanh AppBar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(_getBatteryIcon(updatedLock.battery), size: 20),
                Text(' ${updatedLock.battery}%'),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView( // Thêm để tránh lỗi tràn màn hình trên máy nhỏ
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Phần hiển thị Trạng thái Khóa
            const SizedBox(height: 10),
            Stack( // Dùng Stack để tạo hiệu ứng vòng tròn bao quanh
              alignment: Alignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (updatedLock.isLocked ? Colors.red : Colors.green).withOpacity(0.1),
                  ),
                ),
                Icon(
                  updatedLock.isLocked ? Icons.lock : Icons.lock_open,
                  size: 100,
                  color: updatedLock.isLocked ? Colors.red : Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              updatedLock.isLocked ? 'ĐANG KHÓA' : 'ĐANG MỞ',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: updatedLock.isLocked ? Colors.red : Colors.green,
                  ),
            ),
            const SizedBox(height: 40),

            // Nút bấm Điều khiển chính
            ElevatedButton.icon(
              onPressed: updatedLock.isOnline
                  ? () => notifier.toggleLock(updatedLock.id)
                  : null,
              icon: Icon(updatedLock.isLocked ? Icons.lock_open : Icons.lock),
              label: Text(updatedLock.isLocked ? 'MỞ KHÓA NGAY' : 'ĐÓNG KHÓA NGAY'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
                backgroundColor: updatedLock.isLocked ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Bảng trạng thái chi tiết (Thêm Pin vào đây)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  StatusTile(
                    icon: Icons.wifi,
                    title: 'Kết nối',
                    value: updatedLock.isOnline ? 'Trực tuyến' : 'Ngoại tuyến',
                    color: updatedLock.isOnline ? Colors.green : Colors.grey,
                  ),
                  const Divider(),
                  StatusTile(
                    icon: _getBatteryIcon(updatedLock.battery),
                    title: 'Dung lượng Pin',
                    value: '${updatedLock.battery}%',
                    color: _getBatteryColor(updatedLock.battery),
                  ),
                  const Divider(),
                  StatusTile(
                    icon: Icons.access_time,
                    title: 'Cập nhật',
                    value: updatedLock.lastUpdated != null
                        ? timeago.format(updatedLock.lastUpdated!)
                        : 'Vừa xong',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Hàng nút chức năng phụ
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => HistoryScreen(lockId: updatedLock.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('Lịch sử'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => LockSettingsScreen(lock: updatedLock),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Cài đặt'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}