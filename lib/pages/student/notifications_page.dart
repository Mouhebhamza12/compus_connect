import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _email = true;
  bool _push = true;
  bool _sms = false;
  bool _loading = false;

  Future<void> _save() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preferences saved locally (no backend yet).")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F2A44),
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Manage how you get notifications.",
            style: TextStyle(color: Color(0xFF4B5A6B)),
          ),
          const SizedBox(height: 12),
          _tile(
            title: "Email",
            subtitle: "Announcements and updates",
            value: _email,
            onChanged: (v) => setState(() => _email = v),
          ),
          _tile(
            title: "Push",
            subtitle: "Real-time alerts to your device",
            value: _push,
            onChanged: (v) => setState(() => _push = v),
          ),
          _tile(
            title: "SMS",
            subtitle: "Urgent alerts by text message",
            value: _sms,
            onChanged: (v) => setState(() => _sms = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C78D1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Save preferences", style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Note: These preferences are stored locally for now. Push/SMS delivery depends on device/platform setup.",
            style: TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
          ),
        ],
      ),
    );
  }

  Widget _tile({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F2A44))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF7A8CA3))),
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFF5C78D1),
    );
  }
}
