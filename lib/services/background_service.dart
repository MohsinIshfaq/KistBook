import 'dart:async';

import 'package:get/get.dart';

import '../data/repositories/report_repository.dart';
import 'notification_service.dart';
import 'sync_service.dart';

class BackgroundService {
  BackgroundService({
    required ReportRepository reportRepository,
    required NotificationService notificationService,
    required SyncService syncService,
  }) : _reportRepository = reportRepository,
       _notificationService = notificationService,
       _syncService = syncService;

  final ReportRepository _reportRepository;
  final NotificationService _notificationService;
  final SyncService _syncService;
  Timer? _dailyReportTimer;
  Timer? _syncRetryTimer;

  Future<void> start() async {
    _dailyReportTimer?.cancel();
    _syncRetryTimer?.cancel();
    _scheduleNextReportTick();
    requestSync();
    _syncRetryTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => requestSync(),
    );
  }

  void requestSync() {
    unawaited(_syncService.syncNow());
  }

  void _scheduleNextReportTick() {
    _dailyReportTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _dailyReportTimer = Timer(nextMidnight.difference(now), () async {
      final path = await _reportRepository.generateDailyReport(
        date: DateTime.now(),
      );
      _notificationService.showInfo(
        'Daily due report generated at @path'.trParams({'path': path}),
      );
      _scheduleNextReportTick();
    });
  }

  void dispose() {
    _dailyReportTimer?.cancel();
    _syncRetryTimer?.cancel();
  }
}
