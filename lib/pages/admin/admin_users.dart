import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_components.dart';

class AdminUsersTab extends StatelessWidget {
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> teachers;
  final String searchValue;
  final TextEditingController searchCtrl;
  final bool busy;
  final void Function(String userId) onDeleteUser;
  final String? roleFilter;
  final VoidCallback? onClearRoleFilter;

  const AdminUsersTab({
    super.key,
    required this.students,
    required this.teachers,
    required this.searchValue,
    required this.searchCtrl,
    required this.busy,
    required this.onDeleteUser,
    this.roleFilter,
    this.onClearRoleFilter,
  });

  @override
  Widget build(BuildContext context) {
    final users = [...students, ...teachers].where((u) {
      if (roleFilter != null && u["role"]?.toString() != roleFilter) return false;
      final n = (u["full_name"] ?? "").toString().toLowerCase();
      final e = (u["email"] ?? "").toString().toLowerCase();
      return searchValue.isEmpty || n.contains(searchValue) || e.contains(searchValue);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AdminColors.border),
            ),
            child: TextField(
              controller: searchCtrl,
              decoration: const InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Color(0xFF7A8CA3)),
                hintText: "Search users...",
              ),
            ),
          ),
        ),
        if (roleFilter != null)
          Padding(
            padding: const EdgeInsets.only(left: 18, right: 18, bottom: 8),
            child: Row(
              children: [
                Text(
                  "Filtered by ${roleFilter == "teacher" ? "Teachers" : "Students"}",
                  style: const TextStyle(
                    color: AdminColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                if (onClearRoleFilter != null)
                  TextButton(
                    onPressed: onClearRoleFilter,
                    child: const Text("Clear"),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            itemCount: users.length,
            itemBuilder: (_, i) => _userCard(users[i]),
          ),
        ),
      ],
    );
  }

  Widget _userCard(Map<String, dynamic> u) {
    final name = (u["full_name"] ?? "User").toString();
    final email = (u["email"] ?? "").toString();
    final id = (u["user_id"] ?? "").toString();
    final role = (u["role"] ?? "").toString();

    final color = role == "teacher" ? AdminColors.uniBlue : AdminColors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: color.withOpacity(0.12), child: Icon(Icons.person, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy)),
                const SizedBox(height: 3),
                Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
                const SizedBox(height: 6),
                PillChip(role.toUpperCase(), color),
              ],
            ),
          ),
          IconButton(
            onPressed: busy ? null : () => onDeleteUser(id),
            icon: const Icon(Icons.delete_forever, color: AdminColors.red),
          ),
        ],
      ),
    );
  }
}
