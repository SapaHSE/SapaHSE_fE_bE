import 'package:flutter/material.dart';
import '../models/report.dart';
import '../models/user_model.dart';
import '../models/news_model.dart';

BoxDecoration dashboardCardDecoration({double radius = 16, Color? color}) =>
    BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );

class DashboardSectionHeader extends StatelessWidget {
  final String title, subtitle;
  const DashboardSectionHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF1A56C4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(subtitle,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                  fontWeight: FontWeight.w400)),
        ),
      ],
    );
  }
}

class DashboardStatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;

  const DashboardStatCard(
      {super.key,
      required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: dashboardCardDecoration(radius: 24),
        child: Stack(
          clipBehavior: Clip.antiAlias,
          children: [
            Positioned(
              right: -12,
              top: -12,
              child: Icon(icon, color: color.withValues(alpha: 0.04), size: 100),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 20),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardSeverityBadge extends StatelessWidget {
  final ReportSeverity severity;
  const DashboardSeverityBadge(this.severity, {super.key});

  @override
  Widget build(BuildContext context) {
    Color bg, text;
    switch (severity) {
      case ReportSeverity.high:
      case ReportSeverity.critical:
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFF991B1B);
        break;
      case ReportSeverity.medium:
        bg = const Color(0xFFFFF7ED);
        text = const Color(0xFF9A3412);
        break;
      case ReportSeverity.low:
        bg = const Color(0xFFF0FDF4);
        text = const Color(0xFF166534);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: text.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: text, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(severity.label,
              style: TextStyle(
                  color: text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class DashboardStatusBadge extends StatelessWidget {
  final ReportStatus status;
  const DashboardStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (status) {
      case ReportStatus.pending:
        color = const Color(0xFFF59E0B); // Amber
        icon = Icons.hourglass_empty;
        break;
      case ReportStatus.open:
        color = const Color(0xFF2563EB);
        icon = Icons.radio_button_checked;
        break;
      case ReportStatus.inProgress:
        color = const Color(0xFF7C3AED);
        icon = Icons.sync;
        break;
      case ReportStatus.closed:
        color = const Color(0xFF059669);
        icon = Icons.check_circle;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(status.label.toUpperCase(),
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

class DashboardUserAvatar extends StatelessWidget {
  final String name;
  final double size;

  const DashboardUserAvatar({super.key, required this.name, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty
        ? name.split(' ').take(2).map((e) => e[0].toUpperCase()).join('')
        : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A56C4),
            const Color(0xFF1A56C4).withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1A56C4).withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class DashboardRoleBadge extends StatelessWidget {
  final String role;
  const DashboardRoleBadge(this.role, {super.key});

  @override
  Widget build(BuildContext context) {
    final isSuper =
        role.toLowerCase().contains('super') || role.toLowerCase() == 'admin';
    final color = isSuper ? const Color(0xFF1E293B) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class DashboardCardAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const DashboardCardAction({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

class DashboardReportCard extends StatefulWidget {
  final Report report;
  final ReportType type;
  final String Function(DateTime) fmt;
  final VoidCallback onView;
  final VoidCallback onEdit;

  const DashboardReportCard({
    super.key,
    required this.report,
    required this.type,
    required this.fmt,
    required this.onView,
    required this.onEdit,
  });

  @override
  State<DashboardReportCard> createState() => _DashboardReportCardState();
}

class _DashboardReportCardState extends State<DashboardReportCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final isHazard = widget.type == ReportType.hazard;
    final accentColor =
        isHazard ? const Color(0xFFDC2626) : const Color(0xFFEA580C);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovering
                ? accentColor.withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: _hovering
                  ? accentColor.withValues(alpha: 0.08)
                  : const Color(0xFF1E293B).withValues(alpha: 0.04),
              blurRadius: _hovering ? 20 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: widget.onView,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A56C4).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.ticketNumber ?? '-',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Color(0xFF1A56C4),
                            letterSpacing: 0.5),
                      ),
                    ),
                    const Spacer(),
                    DashboardStatusBadge(r.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  r.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                      height: 1.4),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        r.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text(
                      widget.fmt(r.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                if (isHazard) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DashboardSeverityBadge(r.severity),
                      Row(
                        children: [
                          DashboardCardAction(
                            icon: Icons.visibility_outlined,
                            color: const Color(0xFF1A56C4),
                            label: 'Lihat',
                            onTap: widget.onView,
                          ),
                          const SizedBox(width: 6),
                          DashboardCardAction(
                            icon: Icons.edit_outlined,
                            color: const Color(0xFF64748B),
                            label: 'Edit',
                            onTap: widget.onEdit,
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      DashboardCardAction(
                        icon: Icons.visibility_outlined,
                        color: const Color(0xFF1A56C4),
                        label: 'Lihat',
                        onTap: widget.onView,
                      ),
                      const SizedBox(width: 6),
                      DashboardCardAction(
                        icon: Icons.edit_outlined,
                        color: const Color(0xFF64748B),
                        label: 'Edit',
                        onTap: widget.onEdit,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardNewsImagePlaceholder extends StatelessWidget {
  final Color catColor;
  const DashboardNewsImagePlaceholder({super.key, required this.catColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            catColor.withValues(alpha: 0.15),
            catColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.newspaper_rounded,
          size: 40,
          color: catColor.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class DashboardNewsCard extends StatefulWidget {
  final NewsModel news;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DashboardNewsCard({
    super.key,
    required this.news,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<DashboardNewsCard> createState() => _DashboardNewsCardState();
}

class _DashboardNewsCardState extends State<DashboardNewsCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.news;
    final dateStr = n.date ?? n.createdAt?.substring(0, 10) ?? '-';

    Color catColor;
    switch (n.category.toLowerCase()) {
      case 'safety':
        catColor = const Color(0xFF059669);
        break;
      case 'training':
        catColor = const Color(0xFF2563EB);
        break;
      case 'health':
        catColor = const Color(0xFF7C3AED);
        break;
      case 'environment':
        catColor = const Color(0xFF0891B2);
        break;
      default:
        catColor = const Color(0xFF64748B);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovering
                ? const Color(0xFF1D4ED8).withValues(alpha: 0.25)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: _hovering
                  ? const Color(0xFF1D4ED8).withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: _hovering ? 20 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              child: n.imageUrl != null
                  ? Image.network(
                      n.imageUrl!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          DashboardNewsImagePlaceholder(catColor: catColor),
                    )
                  : DashboardNewsImagePlaceholder(catColor: catColor),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: catColor.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            n.category.toUpperCase(),
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: catColor,
                                letterSpacing: 0.8),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          dateStr,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        n.excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: widget.onEdit,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit_outlined,
                                      size: 14, color: Color(0xFF475569)),
                                  SizedBox(width: 4),
                                  Text('Edit',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF475569))),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: widget.onDelete,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.delete_outline,
                                size: 16, color: Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardUserInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const DashboardUserInfoTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class DashboardUserCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DashboardUserCard({
    super.key,
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<DashboardUserCard> createState() => _DashboardUserCardState();
}

class _DashboardUserCardState extends State<DashboardUserCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: _hovering
                  ? const Color(0xFF1D4ED8).withValues(alpha: 0.3)
                  : const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: _hovering
                  ? const Color(0xFF1D4ED8).withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: _hovering ? 25 : 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DashboardUserAvatar(name: u.fullName, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.fullName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.4)),
                      const SizedBox(height: 4),
                      DashboardRoleBadge(u.role),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: u.isActive
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: u.isActive
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: u.isActive
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        u.isActive ? 'Aktif' : 'Nonaktif',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: u.isActive
                                ? const Color(0xFF166534)
                                : const Color(0xFF991B1B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DashboardUserInfoTile(
                    label: 'NIK / Emp. ID',
                    value: u.employeeId,
                    icon: Icons.badge_outlined,
                  ),
                ),
                Expanded(
                  child: DashboardUserInfoTile(
                    label: 'Role',
                    value: u.role.toUpperCase(),
                    icon: Icons.shield_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DashboardUserInfoTile(
              label: 'Email',
              value: u.personalEmail ?? u.email,
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text('Hapus'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardPagerButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const DashboardPagerButton({super.key, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 150),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF475569)),
        ),
      ),
    );
  }
}

class DashboardActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final bool isLast;

  const DashboardActivityItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border:
                      Border.all(color: const Color(0xFF1D4ED8), width: 2.5),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: const Color(0xFFF1F5F9),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A))),
                      ),
                      const SizedBox(width: 8),
                      Text(time,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B), height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class DashboardSuccessDialog extends StatelessWidget {
  final String title;
  final String message;

  const DashboardSuccessDialog({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBBF7D0), width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF156534),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF156534),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child:
                    const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;

  const DashboardConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Hapus',
    this.confirmColor = Colors.red,
    this.icon = Icons.warning_amber_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFEDD5), width: 2),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFEA580C),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: const Text('Batal',
                        style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
