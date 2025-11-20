import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_lock/models/lock.dart';
import 'package:smart_lock/providers/lock_provider.dart';
import 'package:uuid/uuid.dart';

class AddLockScreen extends ConsumerStatefulWidget {
  const AddLockScreen({super.key});

  @override
  ConsumerState<AddLockScreen> createState() => _AddLockScreenState();
}

class _AddLockScreenState extends ConsumerState<AddLockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _topicController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addLock() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Chưa đăng nhập!");

      // ✅ Tạo lock mới với dữ liệu hợp lệ
      final newLock = LockModel(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        topic: _topicController.text.trim(),
        ownerId: user.uid,
        isLocked: true,
        isOnline: false,
        lastUpdated: DateTime.now(),
      );

      // 🔥 Thêm vào Firestore
      await ref.read(lockProvider.notifier).addLock(newLock);

      if (!mounted) return;

      // ✅ Thông báo và quay lại Home
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Đã thêm khóa mới!')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thêm khóa mới")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Tên khóa",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Nhập tên khóa' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _topicController,
                decoration: const InputDecoration(
                  labelText: "MQTT Topic (ví dụ: smartlock/lock_1)",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Nhập topic' : null,
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _addLock,
                      icon: const Icon(Icons.add),
                      label: const Text("Thêm khóa"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
