import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/sticky_search_header.dart';
import '../../data/models/dashboard_models.dart';
import 'installment_controller.dart';
import 'installment_plan_detail_view.dart';
import 'installment_plan_generator.dart';

class InstallmentScheduleView extends StatefulWidget {
  const InstallmentScheduleView({super.key});

  @override
  State<InstallmentScheduleView> createState() =>
      _InstallmentScheduleViewState();
}

class _InstallmentScheduleViewState extends State<InstallmentScheduleView> {
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDark
        ? AppColors.brandSecondary
        : AppColors.surface;
    final primaryText = isDark ? Colors.white : AppColors.inkStrong;
    final secondaryText = isDark ? const Color(0xFFD0D5DD) : AppColors.inkSoft;
    final mutedText = isDark ? const Color(0xFF98A2B3) : AppColors.inkMuted;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.border;

    return AppShell(
      title: 'Installments'.tr,
      currentRoute: AppRoutes.installments,
      centerTitle: true,
      showSubtitle: false,
      showSettingsAction: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => const InstallmentPlanGenerator()),
        icon: const Icon(Icons.add_chart_outlined),
        label: Text('New Plan'.tr),
      ),
      body: GetBuilder<InstallmentController>(
        builder: (logic) {
          if (searchController.text != logic.searchQuery) {
            searchController.value = searchController.value.copyWith(
              text: logic.searchQuery,
              selection: TextSelection.collapsed(
                offset: logic.searchQuery.length,
              ),
              composing: TextRange.empty,
            );
          }

          final summaries = _buildSummaries(logic.installments)
              .where((summary) => _matchesSearch(summary, logic.searchQuery))
              .toList();

          return Column(
            children: [
              StickySearchHeader(
                controller: searchController,
                hintText: 'Search by customer, product or plan'.tr,
                onChanged: logic.setSearchQuery,
                showClear: logic.searchQuery.isNotEmpty,
                onClear: () {
                  searchController.clear();
                  logic.clearSearch();
                },
              ),
              Expanded(
                child: logic.isLoading && logic.installments.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : summaries.isEmpty
                    ? _EmptyInstallmentState(
                        cardBackground: cardBackground,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        hasSearch: logic.searchQuery.isNotEmpty,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                        itemCount: summaries.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final summary = summaries[index];
                          final status = summary.status;
                          return Card(
                            color: cardBackground,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: () => Get.to(
                                () => const InstallmentPlanDetailView(),
                                arguments: summary,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: switch (status) {
                                              InstallmentVisualStatus.paid =>
                                                AppColors.success,
                                              InstallmentVisualStatus.partial =>
                                                AppColors.info,
                                              InstallmentVisualStatus.overdue =>
                                                AppColors.danger,
                                              InstallmentVisualStatus
                                                  .rescheduled =>
                                                AppColors.brandPrimary,
                                              InstallmentVisualStatus.pending =>
                                                AppColors.warning,
                                            },
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.receipt_long_outlined,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                summary.customer.name,
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w800,
                                                  color: primaryText,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                summary.product?.name ??
                                                    summary.plan.itemName,
                                                style: const TextStyle(
                                                  color: AppColors.brandAccent,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            StatusBadge(status: status),
                                            const SizedBox(height: 8),
                                            Text(
                                              CurrencyHelper.pkr.format(
                                                summary.remainingAmount,
                                              ),
                                              style: TextStyle(
                                                color: primaryText,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Divider(color: dividerColor, height: 1),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Next due: @date'.trParams({
                                              'date':
                                                  summary.nextDueDate == null
                                                  ? 'N/A'.tr
                                                  : summary.nextDueDate!
                                                        .toLocal()
                                                        .toString()
                                                        .split(' ')
                                                        .first,
                                            }),
                                            style: TextStyle(
                                              color: secondaryText,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '@count remaining'.trParams({
                                            'count':
                                                '${summary.remainingInstallments}',
                                          }),
                                          style: TextStyle(
                                            color: mutedText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        _infoChip(
                                          context,
                                          label: 'Total'.tr,
                                          value: CurrencyHelper.pkr.format(
                                            summary.plan.totalAmount,
                                          ),
                                        ),
                                        _infoChip(
                                          context,
                                          label: 'Collected'.tr,
                                          value: CurrencyHelper.pkr.format(
                                            summary.collectedAmount,
                                          ),
                                        ),
                                        _infoChip(
                                          context,
                                          label: 'Installment'.tr,
                                          value: CurrencyHelper.pkr.format(
                                            summary.plan.installmentAmount,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<InstallmentPlanSummary> _buildSummaries(
    List<DueInstallmentDetail> installments,
  ) {
    final grouped = <int, List<DueInstallmentDetail>>{};
    for (final item in installments) {
      grouped.putIfAbsent(item.plan.id ?? 0, () => []).add(item);
    }

    return grouped.values.map((items) {
      items.sort(
        (a, b) => a.installment.currentDueDate.compareTo(
          b.installment.currentDueDate,
        ),
      );
      final first = items.first;
      return InstallmentPlanSummary(
        customer: first.customer,
        plan: first.plan,
        product: first.product,
        installments: items.map((item) => item.installment).toList(),
      );
    }).toList()..sort((a, b) {
      final firstDate = a.nextDueDate ?? DateTime(2100);
      final secondDate = b.nextDueDate ?? DateTime(2100);
      return firstDate.compareTo(secondDate);
    });
  }

  bool _matchesSearch(InstallmentPlanSummary summary, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final haystack = [
      summary.customer.name,
      summary.customer.phone,
      summary.customer.cnic,
      summary.customer.cardNumber,
      summary.product?.name ?? '',
      summary.product?.brandName ?? '',
      summary.product?.sku ?? '',
      summary.plan.itemName,
      summary.plan.notes,
      summary.status.name,
    ].join(' ').toLowerCase();

    return haystack.contains(normalizedQuery);
  }

  Widget _infoChip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInstallmentState extends StatelessWidget {
  const _EmptyInstallmentState({
    required this.cardBackground,
    required this.primaryText,
    required this.secondaryText,
    required this.hasSearch,
  });

  final Color cardBackground;
  final Color primaryText;
  final Color secondaryText;
  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: [
        Card(
          color: cardBackground,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, color: secondaryText, size: 32),
                const SizedBox(height: 12),
                Text(
                  hasSearch
                      ? 'No installment plans found'.tr
                      : 'No installment plans available.'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasSearch) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Try another customer, product or plan search.'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: secondaryText),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
