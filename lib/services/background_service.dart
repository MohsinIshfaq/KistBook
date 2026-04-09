import 'dart:async';

import '../data/repositories/report_repository.dart';
import 'notification_service.dart';

class BackgroundService {
  BackgroundService({
    required ReportRepository reportRepository,
    required NotificationService notificationService,
  })  : _reportRepository = reportRepository,
        _notificationService = notificationService;

  final ReportRepository _reportRepository;
  final NotificationService _notificationService;
  Timer? _timer;

  Future<void> start() async {
    await _reportRepository.generateDailyReport(date: DateTime.now());
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    _timer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(nextMidnight.difference(now), () async {
      final path = await _reportRepository.generateDailyReport(date: DateTime.now());
      _notificationService.showInfo('Daily due report generated at $path');
      _scheduleNextTick();
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}
