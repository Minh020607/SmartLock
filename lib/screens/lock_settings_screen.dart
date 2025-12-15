import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lock.dart';
import '../providers/lock_provider.dart';
import 'home.dart';

class LockSettingsScreen extends ConsumerStatefulWidget {
  final LockModel lock;
  const LockSettingsScreen({super.key, required this.lock});

  @override
  ConsumerState<LockSettingsScreen> createState() =>
      _LockSettingsScreenState();
}

class _LockSettingsScreenState
    extends ConsumerState<LockSettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _shareController = TextEditingController();

  String _role = 'user';
  bool _loadingRole = true;

  // ======================================================
  // INIT
  // ======================================================
  @override
  void initState() {
    super.initState();
    _nameController.text = widget.lock.name;
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final doc =
            await _firestore.collection('users').doc(uid).get();
        _role = doc.data()?['role'] ?? 'user';
      }
    } catch (_) {
      _role = 'user';
    }

    if (mounted) {
      setState(() => _loadingRole = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shareController.dispose();
    super.dispose();
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(lockProvider.notifier);
    final locks = ref.watch(lockProvider);

    // luôn lấy lock mới nhất từ provider
    final currentLock = locks.firstWhere(
      (l) => l.id == widget.lock.id,
      orElse: () => widget.lock,
    );

    final isAdmin = _role == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text("Cài đặt khóa")),
      body: _loadingRole
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =========================
                  // ĐỔI TÊN KHÓA
                  // =========================
                  TextField(
                    controller: _nameController,
                    enabled: isAdmin,
                    decoration: InputDecoration(
                      labelText: "Tên khóa",
                      border: const OutlineInputBorder(),
                      suffixIcon: Icon(
                        isAdmin ? Icons.edit : Icons.lock,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (isAdmin)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text("Lưu thay đổi"),
                      onPressed: () async {
                        final messenger =
                            ScaffoldMessenger.of(context);

                        final name =
                            _nameController.text.trim();
                        if (name.isEmpty) return;

                        await notifier.updateLock(
                          currentLock.id,
                          {"name": name},
                        );

                        if (!mounted) return;

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("✅ Đã đổi tên khóa"),
                          ),
                        );
                      },
                    ),

                  // =========================
                  // ADMIN SECTION
                  // =========================
                  if (isAdmin) ...[
                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 12),

                    const Text(
                      "Chia sẻ quyền truy cập",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _shareController,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  "Email người dùng",
                              border:
                                  OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.person_add,
                            color: Colors.blue,
                          ),
                          onPressed: () async {
                            final messenger =
                                ScaffoldMessenger.of(
                                    context);

                            final email =
                                _shareController.text
                                    .trim();
                            if (email.isEmpty) return;

                            if (currentLock.sharedWith
                                .contains(email)) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                      "$email đã được chia sẻ"),
                                ),
                              );
                              return;
                            }

                            final uid =
                                await notifier
                                    .findUserUidByEmail(
                                        email);

                            if (!mounted) return;

                            if (uid == null) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                      "⚠️ $email chưa có tài khoản"),
                                ),
                              );
                              return;
                            }

                            await notifier.shareLock(
                              currentLock.id,
                              email,
                            );

                            if (!mounted) return;

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                    "👥 Đã chia sẻ cho $email"),
                              ),
                            );

                            _shareController.clear();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      "Danh sách người được chia sẻ:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    if (currentLock.sharedWith.isEmpty)
                      const Text(
                          "Chưa có người được chia sẻ.")
                    else
                      Column(
                        children: currentLock.sharedWith
                            .map(
                              (email) => ListTile(
                                title: Text(email),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final messenger =
                                        ScaffoldMessenger.of(
                                            context);

                                    await notifier.unshareLock(
                                      currentLock.id,
                                      email,
                                    );

                                    if (!mounted) return;

                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            "🚫 Đã hủy chia sẻ $email"),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),

                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 16),

                    // =========================
                    // XÓA KHÓA
                    // =========================
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        icon: const Icon(Icons.delete),
                        label: const Text("Xóa khóa"),
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          await notifier
                              .removeLock(currentLock.id);

                          if (!mounted) return;

                          navigator.pushAndRemoveUntil(
                             MaterialPageRoute(
                               builder: (_) => const HomeScreen(),
                             ),
                              (_) => false,
                          );
                        },
                      ),
                    ),
                  ],

                  // =========================
                  // USER NOTE
                  // =========================
                  if (!isAdmin)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          "⚠️ Bạn không có quyền chỉnh sửa khóa này.",
                          style:
                              TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
