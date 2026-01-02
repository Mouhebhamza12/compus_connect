import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  Future<void> _emailSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@campusconnect.app',
      query: 'subject=Support%20Request&body=Describe%20your%20issue%20here.',
    );
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Help & Support"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F2A44),
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            icon: Icons.chat_bubble_outline,
            title: "FAQ",
            subtitle: "Common questions and answers",
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("FAQ is coming soon.")),
            ),
          ),
          _card(
            icon: Icons.email_outlined,
            title: "Email support",
            subtitle: "Contact support@campusconnect.app",
            onTap: _emailSupport,
          ),
          _card(
            icon: Icons.feedback_outlined,
            title: "Send feedback",
            subtitle: "Tell us what to improve",
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Feedback form coming soon.")),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6ED)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1F4E79)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F2A44))),
        subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF7A8CA3))),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF7A8CA3)),
        onTap: onTap,
      ),
    );
  }
}
