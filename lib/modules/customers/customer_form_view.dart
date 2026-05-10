import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/banner_alert.dart';
import '../../core/constants/app_enums.dart';
import '../../core/utils/text_helper.dart';
import '../../data/models/customer_model.dart';
import '../../services/session_manager.dart';
import 'customer_controller.dart';

class CustomerFormView extends StatefulWidget {
  const CustomerFormView({super.key});

  @override
  State<CustomerFormView> createState() => _CustomerFormViewState();
}

class _CustomerFormViewState extends State<CustomerFormView> {
  final controller = Get.find<CustomerController>();
  final cardNumberController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final cnicController = TextEditingController();
  final addressController = TextEditingController();
  final referenceController = TextEditingController();
  CustomerModel? existing;

  @override
  void initState() {
    super.initState();
    final arg = Get.arguments;
    if (arg is CustomerModel) {
      existing = arg;
      cardNumberController.text = arg.cardNumber;
      nameController.text = arg.name;
      phoneController.text = arg.phone;
      cnicController.text = arg.cnic;
      addressController.text = arg.address;
      referenceController.text = arg.reference;
    }
  }

  @override
  void dispose() {
    cardNumberController.dispose();
    nameController.dispose();
    phoneController.dispose();
    cnicController.dispose();
    addressController.dispose();
    referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canManageCustomers = Get.find<SessionManager>().role == UserRole.owner;
    return Scaffold(
      appBar: AppBar(
        title: Text((existing == null ? 'Add Customer' : 'Edit Customer').tr),
      ),
      body: canManageCustomers
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                AppTextField(
                  label: 'Card / Reference Number'.tr,
                  hint: 'Enter optional card number'.tr,
                  controller: cardNumberController,
                  prefixIcon: Icons.credit_card_outlined,
                ),
                AppTextField(
                  label: 'Customer name'.tr,
                  hint: 'Enter customer full name'.tr,
                  controller: nameController,
                  prefixIcon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                ),
                AppTextField(
                  label: 'Phone'.tr,
                  hint: '03001234567',
                  controller: phoneController,
                  prefixIcon: Icons.call_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                ),
                AppTextField(
                  label: 'CNIC'.tr,
                  hint: '4210112345671',
                  controller: cnicController,
                  prefixIcon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ],
                ),
                AppTextField(
                  label: 'Address'.tr,
                  hint: 'Street, area, city'.tr,
                  controller: addressController,
                  prefixIcon: Icons.location_on_outlined,
                  maxLines: 2,
                ),
                AppTextField(
                  label: 'Reference / referred by'.tr,
                  hint: 'Enter reference person name'.tr,
                  controller: referenceController,
                  prefixIcon: Icons.groups_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    final customerName = TextHelper.toTitleCase(nameController.text);
                    final address = addressController.text.trim();
                    final errors = <String>[];

                    if (customerName.isEmpty) {
                      errors.add('Customer name is required.'.tr);
                    }
                    if (address.isEmpty) {
                      errors.add('Address is required.'.tr);
                    }

                    if (errors.isNotEmpty) {
                      showBannerAlert(
                        type: BannerStyle.error,
                        title: 'Validation Errors'.tr,
                        messages: errors,
                        duration: 4,
                      );
                      return;
                    }

                    await controller.saveCustomer(
                      CustomerModel(
                        id: existing?.id,
                        cardNumber: cardNumberController.text.trim(),
                        name: customerName,
                        phone: TextHelper.digitsOnly(phoneController.text),
                        cnic: TextHelper.digitsOnly(cnicController.text),
                        address: address,
                        reference: TextHelper.toTitleCase(referenceController.text),
                        createdAt: existing?.createdAt ?? DateTime.now(),
                      ),
                    );
                    Get.back();
                  },
                  child: Text('Save Customer'.tr),
                ),
              ],
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'You can view assigned customers, but only the owner can add or edit customer records.'
                      .tr,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }
}
