import 'dart:io';

import 'package:compus_connect/pages/loginPage.dart';
import 'package:compus_connect/pages/student/about_page.dart';
import 'package:compus_connect/pages/student/change_password_page.dart';
import 'package:compus_connect/pages/student/help_support_page.dart';
import 'package:compus_connect/pages/student/notifications_page.dart';
import 'package:compus_connect/pages/student/profile_change_request_page.dart';
import 'package:compus_connect/utilities/friendly_error.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utilities/colors.dart' as colors;

class ProfileTab extends StatefulWidget {
  final String fullName;
  final String email;
  final String studentNumber;
  final String major;
  final String year;
  final String photoUrl;
  final void Function(String url) onPhotoUpdated;

  const ProfileTab({
    super.key,
    required this.fullName,
    required this.email,
    required this.studentNumber,
    required this.major,
    required this.year,
    required this.photoUrl,
    required this.onPhotoUpdated,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;

  Future<void> _changePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("Not signed in");
      final file = File(picked.path);
      final ext = p.extension(file.path);
      final storagePath = 'avatars/${user.id}$ext';
      await Supabase.instance.client.storage.from('avatars').upload(
            storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = Supabase.instance.client.storage.from('avatars').getPublicUrl(storagePath);
      await Supabase.instance.client.from('profiles').update({'photo_url': url}).eq('user_id', user.id);
      widget.onPhotoUpdated(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, fallback: 'Could not update photo.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),

        Center(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _avatar(),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton(
                      onPressed: _uploading ? null : _changePhoto,
                      icon: _uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit, color: colors.kAccentBlue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.fullName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F2A44),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Student ID: ${widget.studentNumber}",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7A8CA3),
                ),
              ),
              if (widget.major.isNotEmpty || widget.year.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  [widget.major, widget.year.isNotEmpty ? 'Year ${widget.year}' : '']
                      .where((e) => e.isNotEmpty)
                      .join(' • '),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7A8CA3),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 26),
        _profileInfoCard(widget.email),

        const SizedBox(height: 22),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileChangeRequestPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.kAccentBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.edit_note, color: Colors.white),
            label: const Text(
              "Request profile change",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          "Settings",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F2A44),
          ),
        ),
        const SizedBox(height: 14),

        _settingTile(
          icon: Icons.lock_outline,
          title: "Change Password",
          subtitle: "Update your account password",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage())),
        ),
        _settingTile(
          icon: Icons.notifications_outlined,
          title: "Notifications",
          subtitle: "Manage your notifications",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
        ),
        _settingTile(
          icon: Icons.help_outline,
          title: "Help & Support",
          subtitle: "Get help or contact support",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportPage())),
        ),
        _settingTile(
          icon: Icons.info_outline,
          title: "About",
          subtitle: "App version and information",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())),
        ),

        const SizedBox(height: 26),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text(
              "Logout",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.kPrimaryNavy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1F4E79)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F2A44),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xFF7A8CA3),
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF7A8CA3)),
      onTap: onTap,
    );
  }

  Widget _profileInfoCard(String email) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E6ED)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Email",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7A8CA3),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email.isNotEmpty ? email : 'No email',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2A44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final hasPhoto = widget.photoUrl.isNotEmpty;
    final initials = widget.fullName.isNotEmpty
        ? widget.fullName.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase()
        : 'S';

    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: const Color(0xFF1F4E79).withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1F4E79), width: 2),
        image: hasPhoto
            ? DecorationImage(
                fit: BoxFit.cover,
                image: NetworkImage(widget.photoUrl),
              )
            : null,
      ),
      child: hasPhoto
          ? null
          : Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F4E79),
                ),
              ),
            ),
    );
  }
}
