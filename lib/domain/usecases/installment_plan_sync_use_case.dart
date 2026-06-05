import '../../data/repositories/installment_plan_sync_repository.dart';

class InstallmentPlanSyncUseCase {
  InstallmentPlanSyncUseCase(this._repository);

  final InstallmentPlanSyncRepository _repository;

  Future<void> uploadPending() => _repository.uploadPending();

  Future<void> downloadLatest() => _repository.downloadLatest();
}
