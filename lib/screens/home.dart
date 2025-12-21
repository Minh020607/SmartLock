import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:smart_lock/providers/lock_provider.dart';
import 'package:smart_lock/widgets/lock_card.dart';
import 'package:smart_lock/screens/add_lock_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locks = ref.watch(lockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartLock Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // ✅ LOGOUT CHUẨN – KHÔNG cleanup thủ công
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),

      body: locks.isEmpty
          ? const Center(
              child: Text(
                'Chưa có khóa nào.\nHãy thêm mới bằng nút + bên dưới.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: locks.length,
              itemBuilder: (context, index) {
                return LockCard(lock: locks[index]);
              },
            ),

      floatingActionButton: FloatingActionButton(
        tooltip: 'Thêm khóa mới',
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddLockScreen(),
            ),
          );
        },
      ),
    );
  }
}
