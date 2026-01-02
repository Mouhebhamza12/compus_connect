import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("About"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F2A44),
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0E6ED)),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Campus Connect", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F2A44))),
                SizedBox(height: 6),
                Text("Version 1.0.0", style: TextStyle(fontSize: 14, color: Color(0xFF7A8CA3))),
                SizedBox(height: 10),
                Text(
                  "Your digital campus companion for ID, requests, timetable, and more.",
                  style: TextStyle(fontSize: 14, color: Color(0xFF4B5A6B), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _linkTile("Privacy Policy", "https://compusconnect.com/privacy"),
          _linkTile("Terms of Service", "https://compusconnect.com/terms"),
        ],
      ),
    );
  }

  Widget _linkTile(String title, String url) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F2A44))),
      subtitle: Text(url, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
      trailing: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF7A8CA3)),
      onTap: () async {
        // ignore: deprecated_member_use
        await launchUrl(Uri.parse(url));
      },
    );
  }
}
