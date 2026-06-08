import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/utils/date_helper.dart';
import '../../core/widgets/app_loading_overlay.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/banner_alert.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/repositories/installment_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/access_control_service.dart';
import '../../services/sync_service.dart';

class DailyInstallmentCollectionView extends StatefulWidget {
  const DailyInstallmentCollectionView({super.key});

  @override
  State<DailyInstallmentCollectionView> createState() =>
      _DailyInstallmentCollectionViewState();
}

class _DailyInstallmentCollectionViewState
    extends State<DailyInstallmentCollectionView> {
  final installmentRepository = Get.find<InstallmentRepository>();
  final paymentRepository = Get.find<PaymentRepository>();
  final accessControlService = Get.find<AccessControlService>();

  DateTime selectedDate = DateHelper.startOfDay(DateTime.now());
  bool isLoading = true;
  List<DueInstallmentDetail> dueItems = [];
  Map<int, String> assignedSalesmanByPlanId = {};
  final ScrollController _scrollController = ScrollController();
  Timer? _autoRefreshTimer;
  int _visibleCustomerCount = _pageSize;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadData();
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }
      _loadData(showLoader: false);
    });
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => isLoading = true);
    }
    final items = await accessControlService.filterDueInstallments(
      await installmentRepository.fetchActiveInstallments(
        today: selectedDate,
        includePaid: true,
      ),
    );
    final assigneeNames = await _loadAssignedSalesmanNames();
    if (!mounted) {
      return;
    }
    final selectedDay = DateHelper.startOfDay(selectedDate);
    setState(() {
      dueItems =
          items
              .where(
                (item) =>
                    DateHelper.startOfDay(item.installment.currentDueDate) ==
                    selectedDay,
              )
              .toList()
            ..sort((a, b) {
              final customerCompare = a.customer.name.compareTo(
                b.customer.name,
              );
              if (customerCompare != 0) {
                return customerCompare;
              }
              return a.installment.sequenceNumber.compareTo(
                b.installment.sequenceNumber,
              );
            });
      assignedSalesmanByPlanId = assigneeNames;
      _visibleCustomerCount = _pageSize;
      isLoading = false;
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 280) {
      return;
    }
    if (_visibleCustomerCount >= _groupedCollections().length) {
      return;
    }
    setState(() => _visibleCustomerCount += _pageSize);
  }

  Future<Map<int, String>> _loadAssignedSalesmanNames() async {
    if (!Get.isRegistered<UserRepository>()) {
      return {};
    }

    final userRepository = Get.find<UserRepository>();
    final users = await userRepository.fetchUsers();
    final userNames = {
      for (final user in users)
        user.uuid: user.fullName.isEmpty ? user.phone : user.fullName,
    };
    final assignments = await userRepository.fetchActivePlanAccess();
    final result = <int, String>{};
    for (final assignment in assignments) {
      final planId = int.tryParse(assignment.planUuid);
      if (planId == null) {
        continue;
      }
      result[planId] = userNames[assignment.userUuid] ?? 'Assigned'.tr;
    }
    return result;
  }

  Future<void> _setSelectedDate(DateTime value) async {
    selectedDate = DateHelper.startOfDay(value);
    await _loadData();
  }

  Future<void> _shiftSelectedDate(int days) async {
    await _setSelectedDate(selectedDate.add(Duration(days: days)));
  }

  Future<void> _moveInstallmentToDate({
    required int installmentId,
    required DateTime targetDate,
    String note = '',
  }) async {
    await installmentRepository.rescheduleInstallment(
      installmentId: installmentId,
      targetDate: targetDate,
      note: note,
      manualSyncOnly: true,
    );
    await _loadData();
  }

  Future<void> _collectInstallment({
    required DueInstallmentDetail detail,
    required double amount,
    required DateTime paidOn,
    required String note,
  }) async {
    await paymentRepository.addPayment(
      installmentId: detail.installment.id!,
      amount: amount,
      paidOn: paidOn,
      note: note,
      manualSyncOnly: true,
    );
    await _loadData();
  }

  Future<void> _collectExactInstallment(DueInstallmentDetail detail) async {
    final amount = detail.installment.remainingAmount;
    if (amount <= 0) {
      return;
    }

    try {
      await _collectInstallment(
        detail: detail,
        amount: amount,
        paidOn: DateTime.now(),
        note: 'Exact due amount collected from daily installment list',
      );
      showBannerAlert(
        title: 'Installment Collected'.tr,
        messages: [
          '@name se @amount receive mark kar di gayi hai.'.trParams({
            'name': detail.customer.name,
            'amount': CurrencyHelper.pkr.format(amount),
          }),
        ],
      );
    } catch (error) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Collection Failed'.tr,
        messages: [error.toString()],
      );
    }
  }

  Future<void> _savePendingChangesNow() async {
    if (!Get.isRegistered<SyncService>()) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Sync Unavailable'.tr,
        messages: ['Sync service is not ready yet.'.tr],
      );
      return;
    }

    try {
      final synced = await AppLoadingOverlay.run(
        context,
        message: 'Saving collections...',
        task: () async {
          final syncService = Get.find<SyncService>();
          await syncService.stop(timeout: const Duration(seconds: 5));
          return syncService.syncNow(
            silent: false,
            includeManualSyncOnly: true,
          );
        },
      );
      await _loadData();
      showBannerAlert(
        title: synced ? 'Collections Saved'.tr : 'Sync Already Running'.tr,
        messages: [
          synced
              ? 'Pending collection changes server par save kar di gayi hain.'
                    .tr
              : 'Sync already chal rahi hai; pending changes retry queue me hain.'
                    .tr,
        ],
      );
    } catch (error) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Sync Failed'.tr,
        messages: [error.toString()],
      );
    }
  }

  List<_DailyCustomerCollection> _groupedCollections() {
    final grouped = <int, _DailyCustomerCollection>{};
    for (final item in dueItems) {
      final customerId = item.customer.id ?? 0;
      grouped
          .putIfAbsent(
            customerId,
            () => _DailyCustomerCollection(customer: item.customer),
          )
          .add(item);
    }
    return grouped.values.toList()
      ..sort((a, b) => a.customer.name.compareTo(b.customer.name));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBackground = isDark
        ? AppColors.brandSecondary
        : AppColors.surface;
    final rowBackground = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : AppColors.surfaceMuted;
    final primaryText = isDark ? Colors.white : AppColors.inkStrong;
    final secondaryText = isDark ? const Color(0xFFD0D5DD) : AppColors.inkSoft;

    final collections = _groupedCollections();
    final visibleCollections = collections.take(_visibleCustomerCount).toList();
    final hasMore = visibleCollections.length < collections.length;

    return AppShell(
      title: 'Daily Installment'.tr,
      currentRoute: AppRoutes.dailyInstallments,
      body: Column(
        children: [
          _buildStickyHeader(context),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : collections.isEmpty
                ? _buildEmptyState(context)
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    itemCount: visibleCollections.length + (hasMore ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index >= visibleCollections.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final collection = visibleCollections[index];
                      return Card(
                        color: cardBackground,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.brandPrimary.withValues(
                                        alpha: isDark ? 0.18 : 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.person_outline_rounded,
                                      color: AppColors.brandPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          collection.customer.name,
                                          style: TextStyle(
                                            color: primaryText,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          collection.customer.phone.isEmpty
                                              ? '@count kist due'.trParams({
                                                  'count':
                                                      '${collection.items.length}',
                                                })
                                              : collection.customer.phone,
                                          style: TextStyle(
                                            color: secondaryText,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyHelper.pkr.format(
                                      collection.totalAmount,
                                    ),
                                    style: TextStyle(
                                      color: primaryText,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...collection.items.map(
                                (detail) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: rowBackground,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _productLabel(detail),
                                                  style: TextStyle(
                                                    color: primaryText,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Installment #@number'.trParams({
                                                    'number':
                                                        '${detail.installment.sequenceNumber}',
                                                  }),
                                                  style: TextStyle(
                                                    color: secondaryText,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                CurrencyHelper.pkr.format(
                                                  detail
                                                      .installment
                                                      .remainingAmount,
                                                ),
                                                style: TextStyle(
                                                  color: primaryText,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              StatusBadge(
                                                status: detail.installment
                                                    .visualStatus(selectedDate),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          _detailLine(
                                            context,
                                            label: 'Card Number'.tr,
                                            value:
                                                detail
                                                    .customer
                                                    .cardNumber
                                                    .isEmpty
                                                ? '-'
                                                : detail.customer.cardNumber,
                                          ),
                                          _detailLine(
                                            context,
                                            label: 'Phone Number'.tr,
                                            value: detail.customer.phone.isEmpty
                                                ? '-'
                                                : detail.customer.phone,
                                          ),
                                          _detailLine(
                                            context,
                                            label: 'Due Date'.tr,
                                            value: _dateLabel(
                                              detail.installment.currentDueDate,
                                            ),
                                          ),
                                          _detailLine(
                                            context,
                                            label: 'Installment Amount'.tr,
                                            value: CurrencyHelper.pkr.format(
                                              detail.installment.amount,
                                            ),
                                          ),
                                          _detailLine(
                                            context,
                                            label: 'Remaining Balance'.tr,
                                            value: CurrencyHelper.pkr.format(
                                              detail
                                                  .installment
                                                  .remainingAmount,
                                            ),
                                          ),
                                          _detailLine(
                                            context,
                                            label: 'Assigned Salesman'.tr,
                                            value:
                                                assignedSalesmanByPlanId[detail
                                                    .plan
                                                    .id] ??
                                                'Unassigned'.tr,
                                          ),
                                          if (detail
                                                  .installment
                                                  .previousDueDate !=
                                              null)
                                            _detailLine(
                                              context,
                                              label: 'Previous Due Date'.tr,
                                              value: _dateLabel(
                                                detail
                                                    .installment
                                                    .previousDueDate!,
                                              ),
                                            ),
                                          if (detail
                                              .installment
                                              .rescheduleNote
                                              .isNotEmpty)
                                            _detailLine(
                                              context,
                                              label: 'Reschedule Note'.tr,
                                              value: detail
                                                  .installment
                                                  .rescheduleNote,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          FilledButton.tonal(
                                            onPressed: detail.installment.isPaid
                                                ? null
                                                : () =>
                                                      _collectExactInstallment(
                                                        detail,
                                                      ),
                                            child: Text('Yes'.tr),
                                          ),
                                          OutlinedButton(
                                            onPressed: detail.installment.isPaid
                                                ? null
                                                : () async {
                                                    await _showCollectionDialog(
                                                      detail: detail,
                                                    );
                                                  },
                                            child: Text('Custom'.tr),
                                          ),
                                          OutlinedButton(
                                            onPressed: detail.installment.isPaid
                                                ? null
                                                : () async {
                                                    await _showRescheduleDialog(
                                                      detail: detail,
                                                    );
                                                  },
                                            child: Text('Reschedule'.tr),
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
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.white12 : AppColors.border),
        ),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;
              final previousButton = IconButton.filledTonal(
                onPressed: isLoading ? null : () => _shiftSelectedDate(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              );
              final nextButton = IconButton.filledTonal(
                onPressed: isLoading ? null : () => _shiftSelectedDate(1),
                icon: const Icon(Icons.chevron_right_rounded),
              );
              final todayButton = FilledButton.tonal(
                onPressed: isLoading
                    ? null
                    : () => _setSelectedDate(DateTime.now()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                child: Text('Today'.tr),
              );
              final saveButton = FilledButton.icon(
                onPressed: isLoading ? null : _savePendingChangesNow,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text('Save'.tr),
              );

              if (compact) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        previousButton,
                        const SizedBox(width: 8),
                        Expanded(child: _buildDateSelector(context, isDark)),
                        const SizedBox(width: 8),
                        nextButton,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: todayButton),
                        const SizedBox(width: 8),
                        Expanded(child: saveButton),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  previousButton,
                  const SizedBox(width: 8),
                  Expanded(child: _buildDateSelector(context, isDark)),
                  const SizedBox(width: 8),
                  todayButton,
                  const SizedBox(width: 8),
                  nextButton,
                  const SizedBox(width: 8),
                  saveButton,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: isLoading
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                await _setSelectedDate(picked);
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _dateLabel(selectedDate),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 42,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No due installments'.tr,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Is date par koi kist due nahi mili.'.tr,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailLine(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 135),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFFD0D5DD)
                  : AppColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCollectionDialog({
    required DueInstallmentDetail detail,
  }) async {
    final input = await showDialog<_CollectionInput>(
      context: context,
      builder: (_) => _CollectionDialog(
        detail: detail,
        dateLabel: _dateLabel,
        productLabel: _productLabel,
      ),
    );

    if (input == null) {
      return;
    }
    if (input.amount <= 0) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Invalid Amount'.tr,
        messages: ['Please enter a valid installment amount.'.tr],
      );
      return;
    }

    try {
      await _collectInstallment(
        detail: detail,
        amount: input.amount,
        paidOn: input.paidOn,
        note: input.note.isEmpty
            ? 'Custom collection from daily installment list'
            : input.note,
      );
      showBannerAlert(
        title: 'Installment Collected'.tr,
        messages: [
          '@name se @amount receive mark kar di gayi hai.'.trParams({
            'name': detail.customer.name,
            'amount': CurrencyHelper.pkr.format(input.amount),
          }),
        ],
      );
    } catch (error) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Collection Failed'.tr,
        messages: [error.toString()],
      );
    }
  }

  Future<void> _showRescheduleDialog({
    required DueInstallmentDetail detail,
  }) async {
    final input = await showDialog<_RescheduleInput>(
      context: context,
      builder: (_) => _RescheduleDialog(detail: detail, dateLabel: _dateLabel),
    );

    if (input == null) {
      return;
    }

    await _moveInstallmentToDate(
      installmentId: detail.installment.id!,
      targetDate: input.targetDate,
      note: input.note,
    );
    showBannerAlert(
      title: 'Plan Updated'.tr,
      messages: [
        '@name installment moved to @date.'.trParams({
          'name': detail.customer.name,
          'date': _dateLabel(input.targetDate),
        }),
        if (input.note.isNotEmpty) input.note,
      ],
    );
  }

  static String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year}';

  static String _productLabel(DueInstallmentDetail detail) {
    final product = detail.product;
    if (product == null) {
      return detail.plan.itemName;
    }
    return '${product.brandName} ${product.name}'.trim();
  }
}

class _CollectionDialog extends StatefulWidget {
  const _CollectionDialog({
    required this.detail,
    required this.dateLabel,
    required this.productLabel,
  });

  final DueInstallmentDetail detail;
  final String Function(DateTime value) dateLabel;
  final String Function(DueInstallmentDetail detail) productLabel;

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog> {
  late final TextEditingController amountController;
  late final TextEditingController noteController;
  late DateTime paidOn;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(
      text: widget.detail.installment.remainingAmount.toStringAsFixed(0),
    );
    noteController = TextEditingController();
    paidOn = DateHelper.startOfDay(DateTime.now());
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Collect Installment'.tr),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.detail.customer.name,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              widget.productLabel(widget.detail),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Collected Amount'.tr,
              hint: 'Enter amount'.tr,
              controller: amountController,
              prefixIcon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
            ),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: paidOn,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null && mounted) {
                  setState(() => paidOn = DateHelper.startOfDay(picked));
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    const Icon(Icons.event_available_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Collection Date'.tr),
                          const SizedBox(height: 2),
                          Text(
                            widget.dateLabel(paidOn),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppTextField(
              label: 'Notes'.tr,
              hint: 'Optional notes'.tr,
              controller: noteController,
              prefixIcon: Icons.edit_note_outlined,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'.tr),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _CollectionInput(
                amount: double.tryParse(amountController.text.trim()) ?? 0,
                paidOn: paidOn,
                note: noteController.text.trim(),
              ),
            );
          },
          child: Text('Save'.tr),
        ),
      ],
    );
  }
}

class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog({required this.detail, required this.dateLabel});

  final DueInstallmentDetail detail;
  final String Function(DateTime value) dateLabel;

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  late final TextEditingController noteController;
  late DateTime targetDate;

  @override
  void initState() {
    super.initState();
    noteController = TextEditingController();
    targetDate = DateHelper.startOfDay(
      widget.detail.installment.currentDueDate,
    );
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reschedule Installment'.tr),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.detail.customer.name,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_repeat_outlined),
              title: Text('New Due Date'.tr),
              subtitle: Text(widget.dateLabel(targetDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: targetDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null && mounted) {
                  setState(() => targetDate = DateHelper.startOfDay(picked));
                }
              },
            ),
            AppTextField(
              label: 'Notes'.tr,
              hint: 'Optional reschedule note'.tr,
              controller: noteController,
              prefixIcon: Icons.edit_note_outlined,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'.tr),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _RescheduleInput(
                targetDate: targetDate,
                note: noteController.text.trim(),
              ),
            );
          },
          child: Text('Save'.tr),
        ),
      ],
    );
  }
}

class _DailyCustomerCollection {
  _DailyCustomerCollection({required this.customer});

  final CustomerModel customer;
  final List<DueInstallmentDetail> items = [];

  void add(DueInstallmentDetail detail) {
    items.add(detail);
  }

  double get totalAmount =>
      items.fold(0, (sum, item) => sum + item.installment.remainingAmount);
}

class _CollectionInput {
  const _CollectionInput({
    required this.amount,
    required this.paidOn,
    required this.note,
  });

  final double amount;
  final DateTime paidOn;
  final String note;
}

class _RescheduleInput {
  const _RescheduleInput({required this.targetDate, required this.note});

  final DateTime targetDate;
  final String note;
}
