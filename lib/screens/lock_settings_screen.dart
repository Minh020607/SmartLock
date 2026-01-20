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
  ConsumerState<LockSettingsScreen> createState() => _LockSettingsScreenState();
}

class _LockSettingsScreenState extends ConsumerState<LockSettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _shareController = TextEditingController();

  String _role = 'user';
  bool _loadingRole = true;

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
        final doc = await _firestore.collection('users').doc(uid).get();
        _role = doc.data()?['role'] ?? 'user';
      }
    } catch (_) {
      _role = 'user';
    }
    if (mounted) setState(() => _loadingRole = false);
  }

  // 1. Hàm gửi lệnh bắt đầu học thẻ
  void _startRfidLearning() {
    final notifier = ref.read(lockProvider.notifier);
    
    // Gửi Map để Provider tự encode JSON
    final cmdMap = {
      "action": "START_LEARNING",
      "by": _auth.currentUser?.email ?? "Admin"
    };
    
    notifier.publishRaw(widget.lock.id, cmdMap);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📡 Chế độ học thẻ: Hãy quẹt thẻ mới vào khóa..."),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // 2. Hàm hiển thị Popup nhập tên thẻ khi nhận được tín hiệu từ MQTT
  void _showAddCardDialog(String cardId) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false, // Bắt buộc tương tác
      builder: (context) => AlertDialog(
        title: const Text("🎴 Phát hiện thẻ mới"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Mã ID: $cardId", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Đặt tên thẻ (VD: Thẻ con gái)",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              
              final notifier = ref.read(lockProvider.notifier);
              await notifier.addRfidCard(widget.lock.id, cardId, name);
              if (!context.mounted) return;
              
              if (mounted) {
                Navigator.pop(context); // Đóng Dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Đã lưu thẻ thành công")),
                );
              }
            },
            child: const Text("Lưu thẻ"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shareController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(lockProvider.notifier);
    final locks = ref.watch(lockProvider);

    // LẤY TRẠNG THÁI MỚI NHẤT CỦA KHÓA
    final currentLock = locks.firstWhere(
      (l) => l.id == widget.lock.id,
      orElse: () => widget.lock,
    );

    // 3. LẮNG NGHE BIẾN PENDING_ID TỪ PROVIDER ĐỂ BẬT POPUP
    ref.listen(lockProvider, (previous, next) {
      if (notifier.pendingCardId != null) {
        final cardId = notifier.pendingCardId!;
        notifier.pendingCardId = null; // Reset ngay lập tức
        _showAddCardDialog(cardId);
      }
    });

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
                  // --- PHẦN TÊN KHÓA ---
                  const Text("Thông tin chung", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    enabled: isAdmin,
                    decoration: InputDecoration(
                      labelText: "Tên khóa",
                      border: const OutlineInputBorder(),
                      suffixIcon: Icon(isAdmin ? Icons.edit : Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isAdmin)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text("Cập nhật tên khóa"),
                        onPressed: () async {
                          final name = _nameController.text.trim();
                          if (name.isEmpty) return;
                          await notifier.updateLock(currentLock.id, {"name": name});
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("✅ Đã đổi tên khóa")),
                          );
                        },
                      ),
                    ),

                  if (isAdmin) ...[
                    const SizedBox(height: 30),
                    const Divider(),
                    
                    // --- QUẢN LÝ RFID ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Danh sách thẻ RFID",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: _startRfidLearning,
                          icon: const Icon(Icons.add_card),
                          label: const Text("Thêm thẻ"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, 
                            foregroundColor: Colors.white
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    if (currentLock.rfidCards.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("Chưa có thẻ nào. Nhấn 'Thêm thẻ' để bắt đầu."),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: currentLock.rfidCards.length,
                        itemBuilder: (context, index) {
                          final card = currentLock.rfidCards[index];
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.credit_card)),
                            title: Text(card['name'] ?? 'Không tên'),
                            subtitle: Text("ID: ${card['id']}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Xóa thẻ?"),
                                    content: Text("Bạn muốn xóa thẻ '${card['name']}'?"),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xóa", style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await notifier.removeRfidCard(currentLock.id, card);
                                }
                              },
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 30),
                    const Divider(),

                    // --- CHIA SẺ QUYỀN ---
                    const Text(
                      "Chia sẻ quyền truy cập",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _shareController,
                            decoration: const InputDecoration(
                              labelText: "Email người dùng",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.person_add, color: Colors.blue, size: 32),
                          onPressed: () async {
                            final email = _shareController.text.trim();
                            if (email.isEmpty) return;
                            if (currentLock.sharedWith.contains(email)) return;

                            final uid = await notifier.findUserUidByEmail(email);
                            if (!context.mounted) return;
                            if (uid == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("⚠️ $email chưa có tài khoản")),
                              );
                              return;
                            }
                            await notifier.shareLock(currentLock.id, email);
                            _shareController.clear();
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    ...currentLock.sharedWith.map((email) => ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(email),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => notifier.unshareLock(currentLock.id, email),
                      ),
                    )),

                    const SizedBox(height: 40),
                    const Divider(),

                    // --- NÚT XÓA KHÓA ---
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        icon: const Icon(Icons.delete_forever),
                        label: const Text("GỠ BỎ KHÓA NÀY"),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Xác nhận xóa"),
                              content: const Text("Khóa sẽ bị xóa khỏi hệ thống của bạn. Thao tác này không thể hoàn tác."),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xác nhận Xóa", style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await notifier.removeLock(currentLock.id);
                            if (!context.mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const HomeScreen()),
                              (_) => false,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}