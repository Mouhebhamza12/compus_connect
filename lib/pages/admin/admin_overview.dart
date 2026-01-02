import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_components.dart';
import 'admin_models.dart';
import 'admin_pending.dart';

class AdminOverviewTab extends StatelessWidget {
  final AdminBundle data;
  final bool busy;
  final void Function(Map<String, dynamic> user) onApprove;
  final void Function(Map<String, dynamic> user) onReject;
  final VoidCallback onPendingTap;
  final VoidCallback onRequestsTap;
  final VoidCallback onStudentsTap;
  final VoidCallback onTeachersTap;
  final VoidCallback onGroupsTap;
  final VoidCallback onCoursesTap;

  const AdminOverviewTab({
    super.key,
    required this.data,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onPendingTap,
    required this.onRequestsTap,
    required this.onStudentsTap,
    required this.onTeachersTap,
    required this.onGroupsTap,
    required this.onCoursesTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _heroCard(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _statCard("Pending", data.pending.length, AdminColors.red, Icons.hourglass_bottom, onPendingTap)),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                "Requests",
                data.changeRequests.length,
                AdminColors.orange,
                Icons.edit_note_outlined,
                onRequestsTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard("Students", data.students.length, AdminColors.green, Icons.school, onStudentsTap)),
            const SizedBox(width: 12),
            Expanded(child: _statCard("Teachers", data.teachers.length, AdminColors.uniBlue, Icons.person, onTeachersTap)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard("Groups", data.groups.length, AdminColors.purple, Icons.groups, onGroupsTap)),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                "Courses",
                data.courses.length,
                AdminColors.navy,
                Icons.menu_book_outlined,
                onCoursesTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle("Latest Pending"),
        const SizedBox(height: 8),
        if (data.pending.isEmpty)
          const EmptyState("No pending students")
        else
          ...data.pending.take(3).map((u) => PendingCard(
                user: u,
                busy: busy,
                onApprove: onApprove,
                onReject: onReject,
              )),
        const SizedBox(height: 18),
        const SectionTitle("Latest Change Requests"),
        const SizedBox(height: 8),
        if (data.changeRequests.isEmpty)
          const EmptyState("No pending change requests")
        else
          ...data.changeRequests.take(3).map((r) => ChangeRequestCard(
                request: r,
                busy: busy,
                onApprove: onApprove,
                onReject: onReject,
              )),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdminColors.navy, AdminColors.uniBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: const Row(
        children: [
          Image(image: AssetImage('assets/images/LogoWhite.png'), width: 60, height: 60),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Campus Admin Panel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                SizedBox(height: 4),
                Text("Approve accounts, create groups & courses, assign students and manage data.",
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    int value,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AdminColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 22, backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
                Text("$value", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AdminColors.navy)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
