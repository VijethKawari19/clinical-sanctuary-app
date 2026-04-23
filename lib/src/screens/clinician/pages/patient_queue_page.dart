import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../features/clinic/clinic_controller.dart';
import '../../../features/clinic/clinic_models.dart';

enum _SearchMode { both, idOnly }

enum _RiskPick { all, low, moderate, high }

enum _RiskSort { highToLow, lowToHigh }

enum _StatusFilter { all, reviewed, pending }

class PatientQueuePage extends ConsumerStatefulWidget {
  const PatientQueuePage({super.key});

  @override
  ConsumerState<PatientQueuePage> createState() => _PatientQueuePageState();
}

class _PatientQueuePageState extends ConsumerState<PatientQueuePage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  _SearchMode _searchMode = _SearchMode.both;
  _RiskPick _riskPick = _RiskPick.all;
  _RiskSort _riskSort = _RiskSort.highToLow;
  _StatusFilter _statusFilter = _StatusFilter.all;

  /// Trim, lowercase, strip zero-width / invisible chars so "asdfgb" matches stored names.
  static String _normalize(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    return s;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      // After clearing, search by name + ID again so names like "asdfgb" match
      // (ID-only mode only searches the case ID string).
      _searchMode = _SearchMode.both;
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(casesProvider);

    final q = _normalize(_searchCtrl.text);
    var items = all.where((c) {
      if (_statusFilter == _StatusFilter.reviewed &&
          c.status != CaseStatus.reviewed) {
        return false;
      }
      if (_statusFilter == _StatusFilter.pending &&
          c.status != CaseStatus.pending) {
        return false;
      }
      if (_riskPick != _RiskPick.all) {
        final wanted = switch (_riskPick) {
          _RiskPick.low => RiskLevel.low,
          _RiskPick.moderate => RiskLevel.moderate,
          _RiskPick.high => RiskLevel.high,
          _RiskPick.all => null,
        };
        if (wanted != null && c.riskLevel != wanted) return false;
      }
      if (q.isEmpty) return true;
      final name = _normalize(c.patientName);
      final id = _normalize(c.id);
      return _searchMode == _SearchMode.idOnly
          ? id.contains(q)
          : (name.contains(q) || id.contains(q));
    }).toList(growable: false);

    items = [...items];
    items.sort((a, b) {
      if (_riskPick == _RiskPick.all) {
        int score(RiskLevel r) => switch (r) {
              RiskLevel.low => 0,
              RiskLevel.moderate => 1,
              RiskLevel.high => 2,
            };
        final ra = score(a.riskLevel);
        final rb = score(b.riskLevel);
        final cmpRisk = ra.compareTo(rb);
        if (cmpRisk != 0) {
          return _riskSort == _RiskSort.lowToHigh ? cmpRisk : -cmpRisk;
        }
      }
      // tie-breaker: newest first
      return b.timestampIso.compareTo(a.timestampIso);
    });

    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Patient Review Queue',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage and review screening submissions from health workers.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        // One search bar (inside the page), full-width for mobile.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: _searchMode == _SearchMode.idOnly
                  ? 'Search by patient ID...'
                  : 'Search patient...',
              hintStyle: TextStyle(color: scheme.onSurfaceVariant),
              prefixIcon:
                  Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear',
                      onPressed: _clearSearch,
                      icon: Icon(Icons.close_rounded,
                          color: scheme.onSurfaceVariant),
                    )
                  : null,
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: scheme.outline.withValues(alpha: 0.65)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: scheme.outline.withValues(alpha: 0.65)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Pill(
                  icon: Icons.badge_outlined,
                  label: 'ID',
                  selected: _searchMode == _SearchMode.idOnly,
                  onTap: () => setState(() {
                    _searchMode = _searchMode == _SearchMode.idOnly
                        ? _SearchMode.both
                        : _SearchMode.idOnly;
                  }),
                ),
                const SizedBox(width: 10),
                _Pill(
                  icon: Icons.task_alt_rounded,
                  label: switch (_statusFilter) {
                    _StatusFilter.all => 'Status',
                    _StatusFilter.reviewed => 'Reviewed',
                    _StatusFilter.pending => 'Pending',
                  },
                  selected: _statusFilter != _StatusFilter.all,
                  onTap: () async {
                    final picked = await _pickStatus(context, _statusFilter);
                    if (!mounted) return;
                    if (picked == null) return;
                    setState(() => _statusFilter = picked);
                  },
                ),
                const SizedBox(width: 10),
                _Pill(
                  icon: Icons.warning_amber_rounded,
                  label: switch (_riskPick) {
                    _RiskPick.low => 'Low',
                    _RiskPick.moderate => 'Medium',
                    _RiskPick.high => 'High',
                    _RiskPick.all => 'Risk',
                  },
                  selected: _riskPick != _RiskPick.all,
                  onTap: () async {
                    final picked = await _pickRisk(context, _riskPick);
                    if (!mounted) return;
                    if (picked == null) return;
                    setState(() => _riskPick = picked);
                  },
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _riskPick != _RiskPick.all
                      ? null
                      : () => setState(() {
                            _riskSort = _riskSort == _RiskSort.highToLow
                                ? _RiskSort.lowToHigh
                                : _RiskSort.highToLow;
                          }),
                  icon: const Icon(Icons.swap_vert_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHighest,
                    foregroundColor: scheme.onSurface,
                    side: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.65)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Scrollbar(
            controller: _scrollCtrl,
            thumbVisibility: false,
            child: items.isEmpty
                ? _QueueEmptyState(
                    totalCases: all.length,
                    hasQuery: q.isNotEmpty,
                    idOnly: _searchMode == _SearchMode.idOnly,
                    riskFiltered: _riskPick != _RiskPick.all,
                    statusFiltered: _statusFilter != _StatusFilter.all,
                  )
                : ListView.separated(
              controller: _scrollCtrl,
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final item = items[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/c/case/${item.id}'),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: context.appSoftIconFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: scheme.outline.withValues(alpha: 0.65)),
                          ),
                          child: const Icon(Icons.person_outline_rounded,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item.patientName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(width: 10),
                                  _RiskChip(
                                    switch (item.riskLevel) {
                                      RiskLevel.low => 'LOW RISK',
                                      RiskLevel.moderate => 'MODERATE',
                                      RiskLevel.high => 'HIGH RISK',
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'ID: ${item.id}    •    ${item.timestampIso.split("T").first}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: scheme.onSurfaceVariant),
                              ),
                              if (item.notes.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.edit_note_rounded,
                                      size: 16,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item.notes.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        _StatusPill(
                          item.status == CaseStatus.pending
                              ? 'Pending'
                              : 'Reviewed',
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded,
                            color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<_StatusFilter?> _pickStatus(
      BuildContext context, _StatusFilter current) {
    return showModalBottomSheet<_StatusFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final sheetScheme = Theme.of(context).colorScheme;
        Widget tile(_StatusFilter v, String title, String subtitle) {
          final selected = v == current;
          return ListTile(
            title: Text(title,
                style: TextStyle(color: sheetScheme.onSurface)),
            subtitle: Text(subtitle,
                style: TextStyle(
                    color: sheetScheme.onSurfaceVariant, fontSize: 12)),
            leading: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? AppColors.primary
                  : sheetScheme.onSurfaceVariant,
            ),
            onTap: () => Navigator.of(context).pop(v),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(
                _StatusFilter.all,
                'All cases',
                'Show reviewed and pending',
              ),
              tile(
                _StatusFilter.reviewed,
                'Reviewed only',
                'Cases with a finalized clinician review',
              ),
              tile(
                _StatusFilter.pending,
                'Pending only',
                'Cases still awaiting review',
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<_RiskPick?> _pickRisk(BuildContext context, _RiskPick current) {
    return showModalBottomSheet<_RiskPick>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final sheetScheme = Theme.of(context).colorScheme;
        Widget tile(_RiskPick v, String title) {
          final selected = v == current;
          return ListTile(
            title: Text(title,
                style: TextStyle(color: sheetScheme.onSurface)),
            leading: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? AppColors.primary
                  : sheetScheme.onSurfaceVariant,
            ),
            onTap: () => Navigator.of(context).pop(v),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(_RiskPick.low, 'Low'),
              tile(_RiskPick.moderate, 'Medium'),
              tile(_RiskPick.high, 'High'),
              Divider(
                  height: 1,
                  color: sheetScheme.outline.withValues(alpha: 0.35)),
              tile(_RiskPick.all, 'Risk'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _QueueEmptyState extends StatelessWidget {
  const _QueueEmptyState({
    required this.totalCases,
    required this.hasQuery,
    required this.idOnly,
    required this.riskFiltered,
    required this.statusFiltered,
  });

  final int totalCases;
  final bool hasQuery;
  final bool idOnly;
  final bool riskFiltered;
  final bool statusFiltered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = totalCases == 0
        ? 'No patients in the queue yet'
        : 'No matching patients';
    final lines = <String>[
      if (totalCases > 0 && hasQuery)
        'No case matches your current search and filters.',
      if (totalCases > 0 && idOnly && hasQuery)
        'ID-only mode is on: only the case ID is searched. Tap ID again to search by name and ID.',
      if (totalCases > 0 && riskFiltered && hasQuery)
        'A risk level filter is hiding some patients. Open Risk and choose Risk to show all risk levels.',
      if (totalCases > 0 && statusFiltered)
        'A status filter is active. Open Status and choose All cases to see the full queue.',
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 48,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    line,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primaryContainer : scheme.surface;
    final border = selected
        ? scheme.primary.withValues(alpha: 0.35)
        : scheme.outline.withValues(alpha: 0.65);
    final fg = selected ? AppColors.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.primary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskChip extends StatelessWidget {
  const _RiskChip(this.risk);
  final String risk;

  @override
  Widget build(BuildContext context) {
    final color = switch (risk) {
      'HIGH RISK' => AppColors.danger,
      'MODERATE' => AppColors.warning,
      _ => AppColors.success,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        risk,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'Pending' => (const Color(0xFFF8EEDB), const Color(0xFF9A6A10)),
      _ => (const Color(0xFFE4F7EA), const Color(0xFF1B7A3A)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        status,
        style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 12),
      ),
    );
  }
}

