import 'package:get/get.dart';

import '../../data/models/product_model.dart';
import '../../data/models/product_price_history_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../services/background_service.dart';

class ProductController extends GetxController {
  ProductController({required ProductRepository productRepository})
    : _productRepository = productRepository;

  final ProductRepository _productRepository;

  List<ProductModel> products = [];
  ProductModel? product;
  List<ProductPriceHistoryModel> priceHistory = [];
  List<String> selectedCategories = [];
  String searchQuery = '';
  bool isLoading = false;

  List<String> get categories {
    final values =
        products
            .expand((item) => item.categories)
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<ProductModel> get filteredProducts {
    final normalizedCategories = selectedCategories
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    final normalizedQuery = searchQuery.trim().toLowerCase();

    return products.where((product) {
      final productCategories = product.categories
          .map((item) => item.trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toSet();
      final categoryMatches =
          normalizedCategories.isEmpty ||
          productCategories.any(normalizedCategories.contains);
      if (!categoryMatches) {
        return false;
      }

      if (normalizedQuery.isEmpty) {
        return true;
      }

      final haystack = [
        product.name,
        product.brandName,
        product.sku,
      ].join(' ').toLowerCase();
      return haystack.contains(normalizedQuery);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    loadProducts();
  }

  Future<void> loadProducts() async {
    isLoading = true;
    update();
    products = await _productRepository.fetchProducts();
    isLoading = false;
    update();
  }

  void toggleCategory(String category) {
    if (selectedCategories.contains(category)) {
      selectedCategories.remove(category);
    } else {
      selectedCategories.add(category);
    }
    update();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    update();
  }

  void clearFilters() {
    selectedCategories = [];
    searchQuery = '';
    update();
  }

  Future<void> saveProduct(ProductModel product) async {
    await _productRepository.saveProduct(product);
    _requestSync();
    await loadProducts();
  }

  Future<void> deleteProduct(int productId) async {
    await _productRepository.deleteProduct(productId);
    _requestSync();
    await loadProducts();
  }

  Future<void> loadProduct(int productId) async {
    isLoading = true;
    update();
    product = await _productRepository.fetchProduct(productId);
    priceHistory = await _productRepository.fetchPriceHistory(productId);
    isLoading = false;
    update();
  }

  void _requestSync() {
    if (Get.isRegistered<BackgroundService>()) {
      Get.find<BackgroundService>().requestSync();
    }
  }
}
