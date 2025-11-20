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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(lockProvider.notifier);
    final updatedLock = ref.watch(lockProvider)
        .firstWhere((l) => l.id == lock.id, orElse: () => lock);

    return Scaffold(
      appBar: AppBar(
        title: Text(updatedLock.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              updatedLock.isLocked ? Icons.lock : Icons.lock_open,
              size: 120,
              color: updatedLock.isLocked ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 20),
            Text(
              updatedLock.isLocked ? 'Đang khóa' : 'Đang mở',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: updatedLock.isOnline
                  ? () => notifier.toggleLock(updatedLock.id)
                  : null,
              icon: const Icon(Icons.power_settings_new),
              label: Text(updatedLock.isLocked ? 'Mở khóa' : 'Đóng khóa'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: updatedLock.isLocked ? Colors.green : Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 40),
            StatusTile(
              icon: Icons.wifi,
              title: 'Trạng thái kết nối',
              value: updatedLock.isOnline ? 'Online' : 'Offline',
              color: updatedLock.isOnline ? Colors.green : Colors.grey,
            ),
            StatusTile(
              icon: Icons.schedule,
              title: 'Lần cập nhật gần nhất',
              value: updatedLock.lastUpdated != null
                  ? timeago.format(updatedLock.lastUpdated!)
                  : 'Không xác định',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: (){
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:(context)=>
                        HistoryScreen(lockId: updatedLock.id)
                       ),
                    );
                  }, 
                  icon: const Icon(Icons.history),
                  label: const Text('Xem lịch sử')
                  ),
                  const Spacer(),
                ElevatedButton.icon(
                  onPressed: (){
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:(context)=>
                        LockSettingsScreen(lock: updatedLock)
                       ),
                    );
                  }, 
                  icon: const Icon(Icons.settings),
                  label: const Text('Cài đặt khóa')
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
