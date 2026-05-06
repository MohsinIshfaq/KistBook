import 'package:get/get.dart';

import '../core/widgets/banner_alert.dart';

class NotificationService {
  void showInfo(String message) {
    showBannerAlert(
      title: 'Notice'.tr,
      messages: [message],
      type: BannerStyle.success,
    );
  }
}
