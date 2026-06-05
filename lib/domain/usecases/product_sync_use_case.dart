import '../../data/repositories/product_sync_repository.dart';

class ProductSyncUseCase {
  ProductSyncUseCase(this._repository);

  final ProductSyncRepository _repository;

  Future<void> uploadPending() => _repository.uploadPending();

  Future<void> downloadLatest() => _repository.downloadLatest();
}
