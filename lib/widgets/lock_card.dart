import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_lock/models/lock.dart';
import 'package:smart_lock/providers/lock_provider.dart';
import 'package:smart_lock/screens/lock_detail_screen.dart';

class LockCard extends ConsumerWidget {
  final LockModel lock;
  const LockCard({super.key, required this.lock});

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
          ),
          title: Text(lock.name),
          subtitle: Text(
            lock.isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: lock.isOnline ? Colors.green : Colors.grey,
            ),
          ),

          /// 🔥 SWITCH BẬT / TẮT
          trailing: Switch(
            value: !lock.isLocked,
            onChanged: lock.isOnline
                ? (value) async {
                    print(
                        "👉 UI toggle pressed | lockId=${lock.id} | value=$value");

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
