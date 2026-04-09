import '../core/widgets/banner_alert.dart';

class NotificationService {
  void showInfo(String message) {
    showBannerAlert(
      title: 'Notice',
      messages: [message],
      type: BannerStyle.success,
    );
  }
}
