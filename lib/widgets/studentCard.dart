import 'package:flutter/material.dart';

class StudentIdCard extends StatelessWidget {
  final String name;
  final String studentNumber;
  final String institution;
  final String validity;
  final String program;
  final String photoUrl;

  const StudentIdCard({
    super.key,
    required this.name,
    required this.studentNumber,
    required this.institution,
    required this.validity,
    this.program = 'Program',
    this.photoUrl = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E6ED)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: institution + logo placeholder
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                institution,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F2A44),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF3F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset("assets/images/LogoBlue.png", width: 40),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 64,
                  height: 64,
                  color: const Color(0xFFE0E6ED),
                  child: photoUrl.isNotEmpty
                      ? Image.network(photoUrl, fit: BoxFit.cover)
                      : Image.asset('assets/images/zlb.png'),
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F2A44),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Student No: $studentNumber',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7A8CA3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Valid: $validity',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
              ),
              Container(
                width: 110,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  program,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F2A44),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
