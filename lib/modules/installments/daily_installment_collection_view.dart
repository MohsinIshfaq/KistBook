import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/utils/date_helper.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/banner_alert.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/repositories/installment_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../services/access_control_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final items = await accessControlService.filterDueInstallments(
      await installmentRepository.fetchActiveInstallments(today: selectedDate),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      dueItems = items
          .where(
            (item) =>
                DateHelper.startOfDay(item.installment.currentDueDate) ==
                DateHelper.startOfDay(selectedDate),
          )
          .toList()
        ..sort((a, b) {
          final customerCompare = a.customer.name.compareTo(b.customer.name);
          if (customerCompare != 0) {
            return customerCompare;
          }
          return a.installment.sequenceNumber.compareTo(b.installment.sequenceNumber);
        });
      isLoading = false;
    });
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
  }) async {
    await installmentRepository.rescheduleInstallment(
      installmentId: installmentId,
      targetDate: targetDate,
    );
    await _loadData();
  }

  Future<void> _collectInstallment({
    required DueInstallmentDetail detail,
    required double amount,
  }) async {
    await paymentRepository.addPayment(
      installmentId: detail.installment.id!,
      amount: amount,
      paidOn: selectedDate,
      note: 'Collected from daily installment list',
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBackground = isDark ? AppColors.brandSecondary : AppColors.surface;
    final rowBackground = isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.surfaceMuted;
    final primaryText = isDark ? Colors.white : AppColors.inkStrong;
    final secondaryText = isDark ? const Color(0xFFD0D5DD) : AppColors.inkSoft;

    final grouped = <int, _DailyCustomerCollection>{};
    for (final item in dueItems) {
      final customerId = item.customer.id ?? 0;
      grouped.putIfAbsent(
        customerId,
        () => _DailyCustomerCollection(customer: item.customer),
      ).add(item);
    }
    final collections = grouped.values.toList()
      ..sort((a, b) => a.customer.name.compareTo(b.customer.name));
    final totalCollectible = collections.fold<double>(
      0,
      (sum, entry) => sum + entry.totalAmount,
    );

    return AppShell(
      title: 'Daily Installment'.tr,
      currentRoute: AppRoutes.dailyInstallments,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: collections.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildHeaderCard(
                    context,
                    customerCount: collections.length,
                    totalCollectible: totalCollectible,
                  );
                }

                final collection = collections[index - 1];
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                        ? '@count kist due'
                                            .trParams({'count': '${collection.items.length}'})
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
                              CurrencyHelper.pkr.format(collection.totalAmount),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                    Text(
                                      CurrencyHelper.pkr.format(
                                        detail.installment.remainingAmount
                                            .clamp(0, double.infinity),
                                      ),
                                      style: TextStyle(
                                        color: primaryText,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed: () async {
                                          await _showCollectionDialog(detail: detail);
                                        },
                                        child: Text('Yes'.tr),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: detail.installment.currentDueDate,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked == null) {
                                            return;
                                          }
                                          await _moveInstallmentToDate(
                                            installmentId: detail.installment.id!,
                                            targetDate: picked,
                                          );
                                          showBannerAlert(
                                            title: 'Plan Updated'.tr,
                                            messages: [
                                              '@name installment moved to @date.'.trParams({
                                                'name': detail.customer.name,
                                                'date': _dateLabel(picked),
                                              }),
                                            ],
                                          );
                                        },
                                        child: Text('Edit'.tr),
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
              },
            ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context, {
    required int customerCount,
    required double totalCollectible,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Single Day Collection'.tr,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Selected date ke customers, product name, installment amount aur collection action yahan show hotay hain.'
                  .tr,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => _shiftSelectedDate(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? Colors.white12 : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _dateLabel(selectedDate),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () => _setSelectedDate(DateTime.now()),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            child: Text('Today'.tr),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => _shiftSelectedDate(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _infoChip(
                  context,
                  label: 'Selected date'.tr,
                  value: _dateLabel(selectedDate),
                ),
                _infoChip(
                  context,
                  label: 'Customers due'.tr,
                  value: '$customerCount',
                ),
                _infoChip(
                  context,
                  label: 'Total collectible'.tr,
                  value: CurrencyHelper.pkr.format(totalCollectible),
                ),
              ],
            ),
            if (customerCount == 0) ...[
              const SizedBox(height: 14),
              Text(
                'Is date par koi kist due nahi mili.'.tr,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
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

  Future<void> _showCollectionDialog({
    required DueInstallmentDetail detail,
  }) async {
    final amountController = TextEditingController(
      text: detail.installment.remainingAmount
          .clamp(0, double.infinity)
          .toStringAsFixed(0),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Collect Installment'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.customer.name,
                style: Theme.of(dialogContext).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _productLabel(detail),
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Amount'.tr,
                hint: 'Enter amount'.tr,
                controller: amountController,
                prefixIcon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel'.tr),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Save'.tr),
            ),
          ],
        );
      },
    );

    void disposeControllerSafely() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        amountController.dispose();
      });
    }

    if (saved != true) {
      disposeControllerSafely();
      return;
    }

    final enteredAmount = double.tryParse(amountController.text.trim()) ?? 0;
    disposeControllerSafely();

    if (enteredAmount <= 0) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Invalid Amount'.tr,
        messages: ['Please enter a valid installment amount.'.tr],
      );
      return;
    }

    await _collectInstallment(detail: detail, amount: enteredAmount);
    showBannerAlert(
      title: 'Installment Collected'.tr,
      messages: [
        '@name se @amount receive mark kar di gayi hai.'.trParams({
          'name': detail.customer.name,
          'amount': CurrencyHelper.pkr.format(enteredAmount),
        }),
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

class _DailyCustomerCollection {
  _DailyCustomerCollection({required this.customer});

  final CustomerModel customer;
  final List<DueInstallmentDetail> items = [];

  void add(DueInstallmentDetail detail) {
    items.add(detail);
  }

  double get totalAmount => items.fold(
        0,
        (sum, item) =>
            sum + item.installment.remainingAmount.clamp(0, double.infinity),
      );
}
