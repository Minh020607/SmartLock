import 'package:flutter/material.dart';

class StatusTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? color;

  const StatusTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
          Text(value, style: TextStyle(color: color ?? Colors.black)),
        ],
      ),
    );
  }
}
