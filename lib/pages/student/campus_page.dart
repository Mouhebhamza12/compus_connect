import 'package:flutter/material.dart';

class CampusPage extends StatelessWidget {
  const CampusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Campus'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F2A44),
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            title: "Main Library",
            subtitle: "Open 8am - 10pm · 3 floors · Quiet & study rooms",
            icon: Icons.local_library,
            color: const Color(0xFF4F8EF7),
          ),
          _card(
            title: "Science Building",
            subtitle: "Labs, classrooms, and faculty offices",
            icon: Icons.science_outlined,
            color: const Color(0xFF7B61FF),
          ),
          _card(
            title: "Student Hub",
            subtitle: "Cafeteria, lounges, clubs, and events",
            icon: Icons.groups,
            color: const Color(0xFF2DBE7E),
          ),
          _card(
            title: "Sports Center",
            subtitle: "Gym, pool, indoor courts, outdoor fields",
            icon: Icons.sports_soccer,
            color: const Color(0xFFF5A623),
          ),
          _card(
            title: "Admin Office",
            subtitle: "Admissions, records, and financial aid",
            icon: Icons.apartment,
            color: const Color(0xFFE94E77),
          ),
          const SizedBox(height: 16),
          _notice(
            "Need directions?",
            "A full campus map is coming soon. For now, visit the Student Hub desk for assistance.",
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6ED)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F2A44)),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4B5A6B), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F2A44)),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(fontSize: 13, color: Color(0xFF4B5A6B), height: 1.4),
          ),
        ],
      ),
    );
  }
}
