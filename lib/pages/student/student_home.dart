import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/studentCard.dart';
import '../../widgets/homeHeader.dart';
import '../../widgets/servicesCard.dart';
import '../../widgets/servicesTab.dart';
import '../../widgets/profileTab.dart';

class StudentHomePage extends StatefulWidget {
  final String fullName;
  final String studentNumber;
  final String major;
  final String year;
  final String email;
  final String photoUrl;
  final String institution;
  final String validity;

  const StudentHomePage({
    super.key,
    String? fullName,
    String? studentNumber,
    String? major,
    String? year,
    String? email,
    String? photoUrl,
    String? institution,
    String? validity,
  })  : fullName = fullName ?? 'Student',
        studentNumber = studentNumber ?? 'N/A',
        major = major ?? 'Student',
        year = year ?? '',
        email = email ?? '',
        photoUrl = photoUrl ?? '',
        institution = institution ?? 'Campus Connect University',
        validity = validity ?? 'Active';

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _currentIndex = 0;
  bool _loading = false;
  String? _error;
  late String _fullName;
  late String _studentNumber;
  late String _major;
  late String _year;
  late String _email;
  late String _photoUrl;
  late String _validity;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _fullName = widget.fullName;
    _studentNumber = widget.studentNumber;
    _major = widget.major;
    _year = widget.year;
    _email = widget.email;
    _photoUrl = widget.photoUrl;
    _validity = widget.validity;
    _refreshLatest();
  }

  void _handlePhotoUpdated(String url) {
    setState(() {
      _photoUrl = url;
    });
  }

  Future<void> _refreshLatest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception("Not signed in");
      }

      final Map<String, dynamic>? profile = await client
          .from('profiles')
          .select('full_name, email, photo_url, status')
          .eq('user_id', user.id)
          .maybeSingle();

      final Map<String, dynamic>? student = await client
          .from('students')
          .select('student_number, major, year')
          .eq('user_id', user.id)
          .maybeSingle();

      int unread = 0;
      try {
        final notifs = await client
            .from('notifications')
            .select('id')
            .eq('user_id', user.id)
            .eq('read', false);
        unread = (notifs as List).length;
      } on PostgrestException catch (e) {
        if (e.code != '42P01') {
          rethrow;
        }
      }

      setState(() {
        final fullNameStr = (profile?['full_name'] ?? _fullName).toString();
        _fullName = fullNameStr.trim().isNotEmpty ? fullNameStr : _fullName;
        _email = (profile?['email'] ?? _email).toString();
        _photoUrl = (profile?['photo_url'] ?? _photoUrl).toString();
        _studentNumber = (student?['student_number'] ?? _studentNumber).toString();
        _major = (student?['major'] ?? _major).toString();
        _year = (student?['year'] ?? _year).toString();
        _validity = (_year.isNotEmpty ? 'Year $_year' : widget.validity);
        _unreadNotifications = unread;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      bottomNavigationBar: _bottomBar(),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _buildTab(),
      ),
    );
  }

  Widget _bottomBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF1F4E79),
      unselectedItemColor: const Color(0xFF7A8CA3),
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), activeIcon: Icon(Icons.grid_view), label: 'Services'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  Widget _buildTab() {
    return [
      _homeTab(),
      const ServicesTab(),
      ProfileTab(
        fullName: _fullName,
        email: _email,
        studentNumber: _studentNumber,
        major: _major,
        year: _year,
        photoUrl: _photoUrl,
        onPhotoUpdated: _handlePhotoUpdated,
      ),
    ][_currentIndex];
  }

  Widget _homeTab() {
    return RefreshIndicator(
      onRefresh: _refreshLatest,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          HomeHeaderTile(
            name: _fullName,
            photoUrl: _photoUrl,
            unreadCount: _unreadNotifications,
            onNotificationsTap: _refreshLatest,
          ),
          const SizedBox(height: 20),

          StudentIdCard(
            name: _fullName,
            studentNumber: _studentNumber,
            institution: widget.institution,
            validity: _year.isNotEmpty ? 'Year $_year' : _validity,
            program: _major.isNotEmpty ? _major : 'Student',
            photoUrl: _photoUrl,
          ),

          const SizedBox(height: 24),

          ServicesGridCard(
            onMoreTap: () => setState(() => _currentIndex = 1),
          ),
        ],
      ),
    );
  }
}
