import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum AppSelectionPresentation { bottomSheet, fullScreen }

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.itemLabelBuilder,
    this.prefixIcon,
    this.sheetTitle,
    this.searchHint,
    this.selectedLabelBuilder,
    this.itemSearchTextBuilder,
    this.itemSubtitleBuilder,
    this.itemBuilder,
    this.presentation = AppSelectionPresentation.bottomSheet,
  });

  final String label;
  final String hint;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T item) itemLabelBuilder;
  final IconData? prefixIcon;
  final String? sheetTitle;
  final String? searchHint;
  final String Function(T item)? selectedLabelBuilder;
  final String Function(T item)? itemSearchTextBuilder;
  final String Function(T item)? itemSubtitleBuilder;
  final Widget Function(BuildContext context, T item, bool selected)? itemBuilder;
  final AppSelectionPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldTextColor = isDark ? Colors.white : AppColors.inkStrong;
    final fieldHintColor =
        isDark ? Colors.white.withValues(alpha: 0.78) : AppColors.inkMuted;
    final fieldBorderColor = isDark ? Colors.white : AppColors.border;
    final fieldBackground = isDark ? const Color(0xFF131B2E) : AppColors.surfaceMuted;

    final selectedLabel = value == null
        ? null
        : (selectedLabelBuilder?.call(value as T) ?? itemLabelBuilder(value as T));

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.inkStrong,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              final selectionFuture = presentation == AppSelectionPresentation.fullScreen
                  ? Navigator.of(context).push<T>(
                      PageRouteBuilder<T>(
                        opaque: false,
                        barrierDismissible: false,
                        barrierColor: Colors.transparent,
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            _SearchableSelectionPage<T>(
                          title: sheetTitle ?? label,
                          hint: searchHint ?? 'Search $label',
                          items: items,
                          itemLabelBuilder: itemLabelBuilder,
                          itemSearchTextBuilder: itemSearchTextBuilder,
                          itemSubtitleBuilder: itemSubtitleBuilder,
                          itemBuilder: itemBuilder,
                          initialValue: value,
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          final curve = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          );
                          return FadeTransition(
                            opacity: curve,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.04),
                                end: Offset.zero,
                              ).animate(curve),
                              child: child,
                            ),
                          );
                        },
                      ),
                    )
                  : showModalBottomSheet<T>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor:
                          isDark ? const Color(0xFF101828) : AppColors.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      builder: (context) {
                        return _SearchableSelectionSheet<T>(
                          title: sheetTitle ?? label,
                          hint: searchHint ?? 'Search $label',
                          items: items,
                          itemLabelBuilder: itemLabelBuilder,
                          itemSearchTextBuilder: itemSearchTextBuilder,
                          itemSubtitleBuilder: itemSubtitleBuilder,
                          itemBuilder: itemBuilder,
                          initialValue: value,
                        );
                      },
                    );
              selectionFuture.then((selected) {
                if (selected != null) {
                  onChanged(selected);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: fieldBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: fieldBorderColor),
              ),
              child: Row(
                children: [
                  if (prefixIcon != null) ...[
                    Icon(prefixIcon, size: 20, color: fieldTextColor),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      selectedLabel ?? hint,
                      style: TextStyle(
                        color: selectedLabel == null ? fieldHintColor : fieldTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: fieldTextColor,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchableSelectionPage<T> extends StatefulWidget {
  const _SearchableSelectionPage({
    required this.title,
    required this.hint,
    required this.items,
    required this.itemLabelBuilder,
    this.itemSearchTextBuilder,
    this.itemSubtitleBuilder,
    this.itemBuilder,
    required this.initialValue,
  });

  final String title;
  final String hint;
  final List<T> items;
  final String Function(T item) itemLabelBuilder;
  final String Function(T item)? itemSearchTextBuilder;
  final String Function(T item)? itemSubtitleBuilder;
  final Widget Function(BuildContext context, T item, bool selected)? itemBuilder;
  final T? initialValue;

  @override
  State<_SearchableSelectionPage<T>> createState() =>
      _SearchableSelectionPageState<T>();
}

class _SearchableSelectionPageState<T> extends State<_SearchableSelectionPage<T>> {
  final TextEditingController searchController = TextEditingController();
  T? selectedValue;

  @override
  void initState() {
    super.initState();
    selectedValue = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overlayColor = isDark
        ? Colors.black.withValues(alpha: 0.38)
        : Colors.black.withValues(alpha: 0.30);
    final pageBackground = isDark ? const Color(0xFF1A1329) : const Color(0xFFF5F7FC);
    final dividerColor = isDark ? Colors.white12 : AppColors.border;
    final query = searchController.text.trim().toLowerCase();
    final filtered = widget.items.where((item) {
      final haystack =
          (widget.itemSearchTextBuilder?.call(item) ?? widget.itemLabelBuilder(item))
              .toLowerCase();
      return haystack.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: overlayColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Container(
            decoration: BoxDecoration(
              color: pageBackground,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 0),
                  child: Row(
                    children: [
                      Text(
                        'Select Customer',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: dividerColor, height: 20),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.inkStrong,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white70 : AppColors.inkSoft,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: dividerColor, height: 20),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No results found',
                              style: theme.textTheme.bodyMedium,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                Divider(color: dividerColor, height: 1),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final selected = selectedValue == item;
                              final customItemBuilder = widget.itemBuilder;

                              if (customItemBuilder != null) {
                                return InkWell(
                                  onTap: () => setState(() => selectedValue = item),
                                  child: customItemBuilder(context, item, selected),
                                );
                              }

                              final subtitle = widget.itemSubtitleBuilder?.call(item);
                              return ListTile(
                                onTap: () => setState(() => selectedValue = item),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                tileColor: selected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: isDark ? 0.18 : 0.10,
                                      )
                                    : null,
                                title: Text(
                                  widget.itemLabelBuilder(item),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight:
                                        selected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                                subtitle: subtitle == null || subtitle.isEmpty
                                    ? null
                                    : Text(subtitle),
                                trailing: selected
                                    ? Icon(
                                        Icons.check_circle_rounded,
                                        color: theme.colorScheme.primary,
                                      )
                                    : null,
                              );
                            },
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: dividerColor, height: 20),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedValue == null
                            ? 'No customer selected'
                            : widget.itemLabelBuilder(selectedValue as T),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () => Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: selectedValue == null
                                  ? null
                                  : () => Navigator.of(context)
                                      .pop(selectedValue as T),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                              child: const Text('Done'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchableSelectionSheet<T> extends StatefulWidget {
  const _SearchableSelectionSheet({
    required this.title,
    required this.hint,
    required this.items,
    required this.itemLabelBuilder,
    this.itemSearchTextBuilder,
    this.itemSubtitleBuilder,
    this.itemBuilder,
    required this.initialValue,
  });

  final String title;
  final String hint;
  final List<T> items;
  final String Function(T item) itemLabelBuilder;
  final String Function(T item)? itemSearchTextBuilder;
  final String Function(T item)? itemSubtitleBuilder;
  final Widget Function(BuildContext context, T item, bool selected)? itemBuilder;
  final T? initialValue;

  @override
  State<_SearchableSelectionSheet<T>> createState() =>
      _SearchableSelectionSheetState<T>();
}

class _SearchableSelectionSheetState<T>
    extends State<_SearchableSelectionSheet<T>> {
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = searchController.text.trim().toLowerCase();
    final filtered = widget.items.where((item) {
      final haystack =
          (widget.itemSearchTextBuilder?.call(item) ?? widget.itemLabelBuilder(item))
              .toLowerCase();
      return haystack.contains(query);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SizedBox(
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.inkStrong,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: isDark ? Colors.white : AppColors.inkStrong),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white70 : AppColors.inkSoft,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No results found',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : AppColors.inkSoft,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => Divider(
                          color: isDark ? Colors.white12 : AppColors.border,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final selected = widget.initialValue == item;
                          final customItemBuilder = widget.itemBuilder;
                          if (customItemBuilder != null) {
                            return InkWell(
                              onTap: () => Navigator.of(context).pop(item),
                              borderRadius: BorderRadius.circular(20),
                              child: customItemBuilder(context, item, selected),
                            );
                          }

                          final subtitle = widget.itemSubtitleBuilder?.call(item);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            title: Text(
                              widget.itemLabelBuilder(item),
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.inkStrong,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            subtitle: subtitle == null || subtitle.isEmpty
                                ? null
                                : Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      subtitle,
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : AppColors.inkSoft,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                            isThreeLine: subtitle != null && subtitle.contains('\n'),
                            trailing: selected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.brandPrimary,
                                  )
                                : null,
                            onTap: () => Navigator.of(context).pop(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
