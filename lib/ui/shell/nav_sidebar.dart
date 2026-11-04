import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_info.dart';
import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../../domain/models.dart';
import '../license/license_controller.dart';
import '../widgets/common.dart';

/// แถบเมนูซ้าย — ย่อ/ขยายได้ · หน้าหลัก · โปรเจค (+ รายชื่อโปรเจค) · ตั้งค่า · ท้ายแถบเป็นเวอร์ชัน/ติดต่อ
class NavSidebar extends StatelessWidget {
  const NavSidebar({super.key, required this.onNewProject});

  final VoidCallback onNewProject;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    final collapsed = state.navCollapsed;

    final width = collapsed ? d.rw(4.6).clamp(64.0, 84.0) : d.rw(16).clamp(190.0, 250.0);

    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.curve,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      // เนื้อในวางที่ความกว้างปลายทางเสมอแล้วค่อย clip ระหว่างอนิเมชัน
      // ไม่งั้นตอนแถบกำลังกางออก เนื้อในจะล้นชั่วขณะและ Flutter ฟ้อง overflow
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: width,
          maxWidth: width,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: d.gap, vertical: d.gapLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ปุ่มย่อ/ขยายแถบ
                Align(
                  alignment: collapsed ? Alignment.center : Alignment.centerRight,
                  child: CircleIconButton(
                    tooltip: collapsed ? 'ขยายเมนู' : 'ย่อเมนู',
                    icon: collapsed ? Icons.chevron_right : Icons.chevron_left,
                    onPressed: state.toggleNav,
                  ),
                ),
                SizedBox(height: d.gapLg),

                _NavItem(
                  icon: Icons.bolt_outlined,
                  label: 'หน้าหลัก',
                  collapsed: collapsed,
                  selected: state.page == AppPage.home,
                  onTap: state.goHome,
                ),
                SizedBox(height: d.gap - 4),
                _NavItem(
                  icon: Icons.folder_outlined,
                  label: 'โปรเจค',
                  collapsed: collapsed,
                  selected: state.page == AppPage.project,
                  // หัวข้อโปรเจคเองไม่มีหน้าของมัน กดแล้ว = สร้างโปรเจคใหม่ (ปุ่ม + ด้านขวา)
                  onTap: onNewProject,
                  trailing: collapsed
                      ? null
                      : Tooltip(
                          message: 'สร้างโปรเจคใหม่',
                          child: Icon(Icons.add, size: d.iconSm, color: AppColors.textMuted),
                        ),
                ),

                // รายชื่อโปรเจค = เมนูย่อย กดเข้าไปหน้าค้นหาของโปรเจคนั้น
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(top: d.gap - 6),
                    children: [
                      for (final project in state.projects)
                        _ProjectItem(
                          project: project,
                          collapsed: collapsed,
                          selected:
                              state.page == AppPage.project &&
                              state.currentProject?.id == project.id,
                          onTap: () => state.openProject(project),
                        ),
                      if (state.projects.isEmpty && !collapsed)
                        Padding(
                          padding: EdgeInsets.only(left: d.gapLg, top: d.gap - 4),
                          child: Text(
                            'ยังไม่มีโปรเจค',
                            style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
                          ),
                        ),
                    ],
                  ),
                ),

                _NavItem(
                  icon: Icons.settings_outlined,
                  label: 'ตั้งค่า',
                  collapsed: collapsed,
                  selected: state.page == AppPage.settings,
                  onTap: state.goSettings,
                ),
                SizedBox(height: d.gap),
                Divider(height: 1, color: AppColors.border),
                SizedBox(height: d.gap),
                const _AboutFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ปุ่มเมนู 1 รายการ — ตอนย่อเหลือไอคอนกลางแถบพร้อม tooltip
class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final fg = widget.selected ? AppColors.accent : AppColors.textBody;
    return Tooltip(
      message: widget.collapsed ? widget.label : '',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: Motion.fast,
            padding: EdgeInsets.symmetric(
              horizontal: widget.collapsed ? 0 : d.gapLg * 0.7,
              vertical: d.gap,
            ),
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.accentSurface
                  : (_hover ? AppColors.surfaceMuted : Colors.transparent),
              borderRadius: BorderRadius.circular(d.radius),
            ),
            child: Row(
              mainAxisAlignment: widget.collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(widget.icon, size: d.icon, color: fg),
                if (!widget.collapsed) ...[
                  SizedBox(width: d.gap),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: d.fontBody,
                        fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// เมนูย่อย = 1 โปรเจค
class _ProjectItem extends StatefulWidget {
  const _ProjectItem({
    required this.project,
    required this.collapsed,
    required this.selected,
    required this.onTap,
  });

  final Project project;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ProjectItem> createState() => _ProjectItemState();
}

class _ProjectItemState extends State<_ProjectItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final fg = widget.selected ? AppColors.accent : AppColors.textMuted;
    return Tooltip(
      message: widget.collapsed ? widget.project.name : '',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: Motion.fast,
            margin: const EdgeInsets.only(bottom: 2),
            padding: EdgeInsets.symmetric(
              horizontal: widget.collapsed ? 0 : d.gapLg * 0.7,
              vertical: d.gap - 3,
            ),
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.accentSurface
                  : (_hover ? AppColors.surfaceMuted : Colors.transparent),
              borderRadius: BorderRadius.circular(d.radius),
            ),
            child: Row(
              mainAxisAlignment: widget.collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                // ตอนย่อเหลือไอคอน ตอนขยายใช้จุดนำสายตาให้ดูเป็นเมนูย่อย
                if (widget.collapsed)
                  Icon(Icons.folder_open_outlined, size: d.iconSm, color: fg)
                else ...[
                  SizedBox(width: d.gap),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.selected ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  SizedBox(width: d.gap),
                  Expanded(
                    child: Text(
                      widget.project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: d.fontSm,
                        fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                        color: fg,
                      ),
                    ),
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

/// ท้ายแถบ — เวอร์ชัน ติดต่อ และวันคงเหลือของใบอนุญาต
class _AboutFooter extends StatelessWidget {
  const _AboutFooter();

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final collapsed = context.select<AppState, bool>((s) => s.navCollapsed);
    final license = LicenseController.maybeOf(context)?.state;
    final days = license?.daysLeft;
    final licenseLine = license == null
        ? null
        : (license.perpetual ? 'ใบอนุญาต: ไม่มีวันหมดอายุ' : 'ใบอนุญาตเหลือ $days วัน');

    if (collapsed) {
      return Tooltip(
        message:
            '$kAppName $kAppVersion\n$kContactEmail${licenseLine == null ? '' : '\n$licenseLine'}',
        child: Icon(Icons.info_outline, size: d.icon, color: AppColors.textMuted),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: d.gapLg * 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$kAppName $kAppVersion',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: d.fontSm,
              fontWeight: FontWeight.w600,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            kContactEmail,
            maxLines: 1,
            style: TextStyle(fontSize: d.fontSm - 1, color: AppColors.textMuted),
          ),
          if (licenseLine != null) ...[
            const SizedBox(height: 2),
            Text(
              licenseLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: d.fontSm - 1, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
