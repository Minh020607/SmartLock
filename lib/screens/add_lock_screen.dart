import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../providers/lock_provider.dart';

class AddLockScreen extends ConsumerStatefulWidget {
  const AddLockScreen({super.key});

  @override
  ConsumerState<AddLockScreen> createState() => _AddLockScreenState();
}

class _AddLockScreenState extends ConsumerState<AddLockScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addLock() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "Chưa đăng nhập";

      // Tạo lockId = UUID
      final lockId = const Uuid().v4();
      final name = _nameController.text.trim();

      // Gọi provider
      await ref.read(lockProvider.notifier).addLock(lockId, name);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã thêm khóa: $name")),
      );

      Navigator.pop(context);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thêm khóa mới")),
      body: Padding(
        padding: const EdgeInsets.all(16),
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
                validator: (v) =>
                    v == null || v.isEmpty ? "Nhập tên khóa" : null,
              ),
              const SizedBox(height: 30),
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
