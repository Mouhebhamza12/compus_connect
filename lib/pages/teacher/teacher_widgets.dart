import 'package:flutter/material.dart';

import 'teacher_models.dart';
import 'teacher_theme.dart';

class TeacherHeader extends StatelessWidget {
  final String name;
  final String email;
  final List<StatCardData> stats;
  final List<Widget>? actions;

  const TeacherHeader({
    super.key,
    required this.name,
    required this.email,
    required this.stats,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AdminColors.heroGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [AdminColors.softShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: const Icon(Icons.palette_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Faculty' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email.isEmpty ? 'Teacher workspace' : email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withOpacity(0.86), fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Manage courses, files, attendance, and grading.',
                          style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (actions != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: actions!,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: stats.map((s) => _StatPill(data: s)).toList(),
              ),
            ],
          ),
        ),
        Positioned(
          top: -22,
          right: -12,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(60),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final StatCardData data;

  const _StatPill({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white.withOpacity(0.18),
            child: Icon(data.icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
              Text(
                data.value,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const PillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AdminColors.uniBlue,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 4,
          decoration: BoxDecoration(
            color: AdminColors.uniBlue,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AdminColors.navy),
        ),
      ],
    );
  }
}

class EmptyCard extends StatelessWidget {
  final String message;
  const EmptyCard(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AdminColors.cardTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
        boxShadow: const [AdminColors.softShadow],
      ),
      child: Column(
        children: [
          const Icon(Icons.info_outline, color: AdminColors.muted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AdminColors.navy),
          ),
        ],
      ),
    );
  }
}

class TeacherPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool elevated;
  final Color? color;

  const TeacherPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.elevated = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: color == null ? AdminColors.cardTint : null,
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
        boxShadow: elevated ? const [AdminColors.softShadow] : const [],
      ),
      child: child,
    );
  }
}
