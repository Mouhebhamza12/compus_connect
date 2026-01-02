import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_components.dart';

class AdminPendingTab extends StatelessWidget {
  final List<Map<String, dynamic>> pending;
  final List<Map<String, dynamic>> changeRequests;
  final bool busy;
  final void Function(Map<String, dynamic> user) onApprove;
  final void Function(Map<String, dynamic> user) onReject;
  final void Function(Map<String, dynamic> req) onApproveRequest;
  final void Function(Map<String, dynamic> req) onRejectRequest;
  final bool showRequestsFirst;

  const AdminPendingTab({
    super.key,
    required this.pending,
    required this.changeRequests,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onApproveRequest,
    required this.onRejectRequest,
    this.showRequestsFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    void addPending() {
      children.addAll([
        const SectionTitle("Pending Approvals"),
        const SizedBox(height: 10),
        if (pending.isEmpty)
          const EmptyState("No pending students")
        else
          ...pending.map((u) => PendingCard(
                user: u,
                busy: busy,
                onApprove: onApprove,
                onReject: onReject,
              )),
        const SizedBox(height: 24),
      ]);
    }

    void addRequests() {
      children.addAll([
        const SectionTitle("Profile Change Requests"),
        const SizedBox(height: 10),
        if (changeRequests.isEmpty)
          const EmptyState("No pending change requests")
        else
          ...changeRequests.map((r) => ChangeRequestCard(
                request: r,
                busy: busy,
                onApprove: onApproveRequest,
                onReject: onRejectRequest,
              )),
      ]);
    }

    if (showRequestsFirst) {
      addRequests();
      children.add(const SizedBox(height: 24));
      addPending();
    } else {
      addPending();
      addRequests();
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: children,
    );
  }
}

class PendingCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool busy;
  final void Function(Map<String, dynamic> user) onApprove;
  final void Function(Map<String, dynamic> user) onReject;

  const PendingCard({
    super.key,
    required this.user,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final name = (user["full_name"] ?? "Student").toString();
    final email = (user["email"] ?? "").toString();

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
          CircleAvatar(radius: 22, backgroundColor: AdminColors.red.withOpacity(0.12), child: const Icon(Icons.person, color: AdminColors.red)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy)),
                const SizedBox(height: 3),
                Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
              ],
            ),
          ),
          IconButton(
            onPressed: busy ? null : () => onApprove(user),
            icon: const Icon(Icons.check_circle, color: AdminColors.green),
          ),
          IconButton(
            onPressed: busy ? null : () => onReject(user),
            icon: const Icon(Icons.cancel, color: AdminColors.red),
          ),
        ],
      ),
    );
  }
}

class ChangeRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final bool busy;
  final void Function(Map<String, dynamic> req) onApprove;
  final void Function(Map<String, dynamic> req) onReject;

  const ChangeRequestCard({
    super.key,
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final profile = request['profiles'] as Map<String, dynamic>?;
    final currentName = (profile?['full_name'] ?? '').toString();
    final currentEmail = (profile?['email'] ?? '').toString();
    final requestedName = (request['full_name'] ?? '').toString();
    final requestedEmail = (request['email'] ?? '').toString();
    final requestedMajor = (request['major'] ?? '').toString();
    final requestedYear = request['year']?.toString() ?? '';
    final requestedStudentNumber = (request['student_number'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AdminColors.uniBlue.withOpacity(0.12),
                child: const Icon(Icons.edit_note, color: AdminColors.uniBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requestedName.isNotEmpty ? requestedName : (currentName.isNotEmpty ? currentName : "Student"),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      requestedEmail.isNotEmpty ? requestedEmail : (currentEmail.isNotEmpty ? currentEmail : "No email"),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: busy ? null : () => onApprove(request),
                icon: const Icon(Icons.check_circle, color: AdminColors.green),
              ),
              IconButton(
                onPressed: busy ? null : () => onReject(request),
                icon: const Icon(Icons.cancel, color: AdminColors.red),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _changeRow("Name", currentName, requestedName),
          _changeRow("Email", currentEmail, requestedEmail),
          _changeRow("Student #", "", requestedStudentNumber),
          _changeRow("Major", "", requestedMajor),
          _changeRow("Year", "", requestedYear.isNotEmpty ? "Year $requestedYear" : ""),
        ],
      ),
    );
  }

  Widget _changeRow(String label, String current, String requested) {
    if (current == requested && requested.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AdminColors.navy))),
          Expanded(
            child: Text(
              requested.isNotEmpty ? requested : (current.isNotEmpty ? current : "-"),
              style: const TextStyle(color: Color(0xFF4A5A6A)),
            ),
          ),
        ],
      ),
    );
  }
}
