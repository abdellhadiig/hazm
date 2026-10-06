import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../platform/blocker.dart';
import '../motion/reveal.dart';
import '../widgets/app_icon.dart';
import '../widgets/kit.dart';

class AllowedAppsScreen extends StatefulWidget {
  const AllowedAppsScreen({super.key});

  @override
  State<AllowedAppsScreen> createState() => _AllowedAppsScreenState();
}

class _AllowedAppsScreenState extends State<AllowedAppsScreen> {
  List<InstalledApp>? _apps;
  Set<String> _allowed = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (apps, allowed) = await (Blocker.apps(), Blocker.allowedApps()).wait;
    if (!mounted) return;
    AppLabelCache.remember(apps);
    setState(() {
      _apps = apps;
      _allowed = allowed;
    });
  }

  void _toggle(InstalledApp app, bool value) {
    Haptics.selection();
    setState(() {
      _allowed = {..._allowed};
      if (value) {
        _allowed.add(app.package);
      } else {
        _allowed.remove(app.package);
      }
    });
    Blocker.setAllowedApps(_allowed);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final apps = _apps;
    final query = _query.trim().toLowerCase();
    final visible = (apps ?? const <InstalledApp>[])
        .where((app) => query.isEmpty || app.label.toLowerCase().contains(query))
        .toList();
    final essentials = visible.where((app) => app.essential).toList();
    final others = visible.where((app) => !app.essential).toList()
      ..sort((a, b) {
        final allowedA = _allowed.contains(a.package);
        final allowedB = _allowed.contains(b.package);
        if (allowedA != allowedB) return allowedA ? -1 : 1;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
    final allowedCount = others.where((app) => _allowed.contains(app.package)).length;
    return Scaffold(
      backgroundColor: Palette.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, 0),
              sliver: SliverToBoxAdapter(
                child: Reveal(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PageHeader(
                        eyebrow: l.t('sectionBlocking'),
                        title: l.t('allowedApps'),
                        trailing: IconSquare(
                          icon: Icons.close,
                          tooltip: l.t('back'),
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(l.t('allowedAppsBody'), style: Typo.body),
                      const SizedBox(height: Space.lg),
                      Container(
                        decoration: BoxDecoration(
                          color: Palette.surface,
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(color: Palette.divider),
                        ),
                        child: TextField(
                          onChanged: (value) => setState(() => _query = value),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: l.t('searchApps'),
                            hintStyle: const TextStyle(color: Palette.textFaint),
                            prefixIcon: const Icon(Icons.search, color: Palette.textMuted, size: 20),
                            contentPadding: const EdgeInsets.symmetric(vertical: Space.md + 2),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.xl),
                    ],
                  ),
                ),
              ),
            ),
            if (apps == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              if (essentials.isNotEmpty) ...[
                _Header(title: l.t('alwaysAllowed'), trailing: l.t('alwaysAllowedBody')),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.lg),
                  sliver: SliverList.builder(
                    itemCount: essentials.length,
                    itemBuilder: (context, index) => _AppRow(app: essentials[index], allowed: true, locked: true),
                  ),
                ),
              ],
              _Header(title: l.t('yourApps'), trailing: l.f('allowedCount', {'count': '$allowedCount'})),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xxl),
                sliver: SliverList.builder(
                  itemCount: others.length,
                  itemBuilder: (context, index) {
                    final app = others[index];
                    return _AppRow(
                      app: app,
                      allowed: _allowed.contains(app.package),
                      onChanged: (value) => _toggle(app, value),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.md),
      sliver: SliverToBoxAdapter(
        child: SectionTitle(
          title,
          trailing: Caps(
            trailing,
            style:
                const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1, color: Palette.textFaint),
          ),
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.allowed, this.locked = false, this.onChanged});

  final InstalledApp app;
  final bool allowed;
  final bool locked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CardBox(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.md, Space.sm, Space.sm, Space.sm),
        onTap: locked ? null : () => onChanged?.call(!allowed),
        child: Row(
          children: [
            AppIcon(app.package, size: 36, label: app.label),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Typo.strong),
            ),
            if (locked)
              const Padding(
                padding: EdgeInsets.all(Space.md),
                child: Icon(Icons.lock, size: 16, color: Palette.textMuted),
              )
            else
              Switch(value: allowed, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
