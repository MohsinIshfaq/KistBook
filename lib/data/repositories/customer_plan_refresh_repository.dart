import '../../core/utils/dart_json.dart';
import '../datasources/customer_remote_data_source.dart';
import 'customer_repository.dart';
import 'installment_plan_sync_repository.dart';
import 'product_sync_repository.dart';

class CustomerPlanRefreshRepository {
  CustomerPlanRefreshRepository({
    required CustomerRepository customerRepository,
    required CustomerRemoteDataSource remoteDataSource,
    required ProductSyncRepository productSyncRepository,
    required InstallmentPlanSyncRepository installmentPlanSyncRepository,
  }) : _customerRepository = customerRepository,
       _remoteDataSource = remoteDataSource,
       _productSyncRepository = productSyncRepository,
       _installmentPlanSyncRepository = installmentPlanSyncRepository;

  final CustomerRepository _customerRepository;
  final CustomerRemoteDataSource _remoteDataSource;
  final ProductSyncRepository _productSyncRepository;
  final InstallmentPlanSyncRepository _installmentPlanSyncRepository;

  Future<CustomerPlanRefreshResult> refreshCustomerPlans(int customerId) async {
    final serverId = await _customerRepository.serverIdForCustomer(customerId);
    if (serverId == null) {
      return const CustomerPlanRefreshResult.skipped();
    }

    final response = await _remoteDataSource.planDetails(serverId);
    final data = DartJson(response).mapValue('data');
    final products = _listOfMaps(DartJson(data).listValue('products'));
    final plans = _listOfMaps(DartJson(data).listValue('plans'));

    if (products.isNotEmpty) {
      await _productSyncRepository.applyDownloadedRecords(products);
    }
    if (plans.isNotEmpty) {
      await _installmentPlanSyncRepository.applyDownloadedRecords(plans);
    }

    return CustomerPlanRefreshResult.refreshed(
      productCount: products.length,
      planCount: plans.length,
    );
  }

  List<Map<String, dynamic>> _listOfMaps(List<dynamic> values) {
    return values
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }
}

class CustomerPlanRefreshResult {
  const CustomerPlanRefreshResult({
    required this.didRefresh,
    required this.productCount,
    required this.planCount,
  });

  const CustomerPlanRefreshResult.skipped()
    : didRefresh = false,
      productCount = 0,
      planCount = 0;

  const CustomerPlanRefreshResult.refreshed({
    required this.productCount,
    required this.planCount,
  }) : didRefresh = true;

  final bool didRefresh;
  final int productCount;
  final int planCount;
}
