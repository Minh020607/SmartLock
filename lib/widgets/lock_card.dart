import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_lock/models/lock.dart';
import 'package:smart_lock/providers/lock_provider.dart';
import 'package:smart_lock/screens/lock_detail_screen.dart';

class LockCard extends ConsumerWidget {
  final LockModel lock;
  const LockCard({super.key, required this.lock});

  // Hàm bổ trợ chọn Icon pin dựa trên phần trăm (đọc từ chân D35 của ESP32)
  IconData _getBatteryIcon(int level) {
    if (level > 85) return Icons.battery_full;
    if (level > 70) return Icons.battery_6_bar;
    if (level > 50) return Icons.battery_4_bar;
    if (level > 30) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  // Hàm bổ trợ chọn màu sắc để cảnh báo pin yếu
  Color _getBatteryColor(int level) {
    if (level > 20) return Colors.grey[600]!;
    return Colors.red; // Pin dưới 20% báo đỏ
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Opacity(
      opacity: lock.isOnline ? 1 : 0.5,
      child: Card(
        clipBehavior: Clip.hardEdge,
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: Icon(
            lock.isLocked ? Icons.lock : Icons.lock_open,
            color: lock.isLocked ? Colors.red : Colors.green,
            size: 28,
          ),
          title: Text(
            lock.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                // Trạng thái Online/Offline
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: lock.isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  lock.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: lock.isOnline ? Colors.green[700] : Colors.grey,
                    fontSize: 13,
                  ),
                ),
                
                // Dấu gạch đứng phân cách
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('|', style: TextStyle(color: Colors.grey)),
                ),

                // Hiển thị PIN
                Icon(
                  _getBatteryIcon(lock.battery),
                  size: 16,
                  color: _getBatteryColor(lock.battery),
                ),
                const SizedBox(width: 4),
                Text(
                  '${lock.battery}%',
                  style: TextStyle(
                    fontSize: 13,
                    color: _getBatteryColor(lock.battery),
                    fontWeight: lock.battery <= 20 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),

          trailing: Switch(
            value: !lock.isLocked,
            onChanged: lock.isOnline
                ? (value) async {
                    print("👉 UI toggle pressed | lockId=${lock.id} | value=$value");
                    await ref
                        .read(lockProvider.notifier)
                        .toggleLock(lock.id);
                  }
                : null,
          ),

          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LockDetailScreen(lock: lock),
              ),
            );
          },
        ),
      ),
    );
  }
}