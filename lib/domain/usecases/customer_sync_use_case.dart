import '../../data/repositories/customer_sync_repository.dart';

class CustomerSyncUseCase {
  CustomerSyncUseCase(this._repository);

  final CustomerSyncRepository _repository;

  Future<void> uploadPending() => _repository.uploadPending();

  Future<void> downloadLatest() => _repository.downloadLatest();
}
