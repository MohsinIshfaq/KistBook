import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/banner_alert.dart';
import 'report_controller.dart';

class ReportView extends GetView<ReportController> {
  const ReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Reports'.tr,
      currentRoute: AppRoutes.reports,
      actions: [
        IconButton(
          onPressed: controller.loadDueItems,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: GetBuilder<ReportController>(
        builder: (logic) {
          if (logic.isLoading && logic.dueItems.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Due Installment PDF'.tr,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () async {
                          await logic.generateReport();
                          if (logic.reportPath != null) {
                            showBannerAlert(
                              title: 'Report Saved'.tr,
                              messages: [logic.reportPath!],
                            );
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text('Generate today report'.tr),
                      ),
                      if (logic.reportPath != null) ...[
                        const SizedBox(height: 12),
                        Text(logic.reportPath!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...logic.dueItems.map(
                (item) => Card(
                  child: ListTile(
                    title: Text(item.customer.name),
                    subtitle: Text(item.product?.name ?? item.plan.itemName),
                    trailing: Text(
                      CurrencyHelper.pkr.format(item.installment.remainingAmount),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
