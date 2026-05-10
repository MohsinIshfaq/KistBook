import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/models/dashboard_models.dart';
import 'payment_controller.dart';

class PaymentFormView extends StatefulWidget {
  const PaymentFormView({super.key});

  @override
  State<PaymentFormView> createState() => _PaymentFormViewState();
}

class _PaymentFormViewState extends State<PaymentFormView> {
  final controller = Get.find<PaymentController>();
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  late DueInstallmentDetail detail;
  DateTime paidOn = DateTime.now();

  @override
  void initState() {
    super.initState();
    detail = Get.arguments as DueInstallmentDetail;
    amountController.text = detail.installment.remainingAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Record Payment'.tr)),
      body: GetBuilder<PaymentController>(
        builder: (logic) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(detail.customer.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(detail.product?.name ?? detail.plan.itemName),
                      const SizedBox(height: 8),
                      Text(
                        'Remaining: @amount'.trParams({
                          'amount': CurrencyHelper.pkr.format(detail.installment.remainingAmount),
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: amountController,
                label: 'Amount'.tr,
                hint: 'Enter received amount'.tr,
                prefixIcon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: noteController,
                label: 'Note'.tr,
                hint: 'Add payment note'.tr,
                prefixIcon: Icons.edit_note_outlined,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Payment date'.tr),
                subtitle: Text(paidOn.toLocal().toString().split(' ').first),
                onTap: logic.isSubmittingPayment
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: paidOn,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => paidOn = picked);
                        }
                      },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: logic.isSubmittingPayment
                    ? null
                    : () async {
                        await controller.addPayment(
                          installmentId: detail.installment.id!,
                          amount: double.tryParse(amountController.text.trim()) ?? 0,
                          paidOn: paidOn,
                          note: noteController.text.trim(),
                        );
                        if (!mounted) {
                          return;
                        }
                        Get.offNamed(AppRoutes.payments);
                      },
                child: Text(
                  logic.isSubmittingPayment ? 'Saving...'.tr : 'Save Payment'.tr,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
