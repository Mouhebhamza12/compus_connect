import 'package:flutter/material.dart';
import '../pages/student/alerts_page.dart';

class HomeHeaderTile extends StatelessWidget {
  final String name;
  final String photoUrl;
  final int unreadCount;
  final VoidCallback? onNotificationsTap;

  const HomeHeaderTile({
    super.key,
    required this.name,
    this.photoUrl = '',
    this.unreadCount = 0,
    this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _avatar(),
      title: Text(
        'Hello, $name',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF7A8CA3),
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: const Text(
        'Welcome back!',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F2A44),
        ),
      ),
      trailing: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E6ED)),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_none,
                color: Color(0xFF1F4E79),
                size: 22,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsPage()),
                ).then((_) {
                  if (onNotificationsTap != null) onNotificationsTap!();
                });
              },
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final hasPhoto = photoUrl.isNotEmpty;
    final initials = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase()
        : 'S';

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: 52,
        height: 52,
        color: const Color(0xFFE0E6ED),
        child: hasPhoto
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initials(initials),
              )
            : _initials(initials),
      ),
    );
  }

  Widget _initials(String initials) {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFFE0E6ED),
      child: Text(
        initials,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F4E79),
        ),
      ),
    );
  }
}
