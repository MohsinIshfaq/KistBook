import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../models/product_model.dart';
import '../models/product_price_history_model.dart';
import 'generic_repository.dart';

class ProductRepository extends GenericRepository<ProductModel> {
  ProductRepository(DbHelper dbHelper)
      : super(
          dbHelper: dbHelper,
          tableName: DbConstants.products,
          fromMap: ProductModel.fromMap,
        );

  Future<List<ProductModel>> fetchProducts() async {
    return getAll(orderBy: 'updated_at DESC');
  }

  Future<ProductModel> saveProduct(ProductModel product) async {
    final database = await db;
    return database.transaction((txn) async {
      ProductModel? existing;
      if (product.id != null) {
        final rows = await txn.query(
          DbConstants.products,
          where: 'id = ?',
          whereArgs: [product.id],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          existing = ProductModel.fromMap(rows.first);
        }
      }

      final now = DateTime.now();
      final productToSave = ProductModel(
        id: product.id,
        categories: product.categories,
        brandName: product.brandName,
        name: product.name,
        sku: product.sku,
        salePrice: product.salePrice,
        notes: product.notes,
        createdAt: existing?.createdAt ?? product.createdAt,
        updatedAt: now,
      );

      int productId;
      if (productToSave.id == null) {
        productId = await txn.insert(
          DbConstants.products,
          productToSave.toMap()..remove('id'),
        );
        await txn.insert(
          DbConstants.productPriceHistory,
          ProductPriceHistoryModel(
            productId: productId,
            previousPrice: null,
            newPrice: productToSave.salePrice,
            changedAt: now,
          ).toMap()..remove('id'),
        );
      } else {
        productId = productToSave.id!;
        await txn.update(
          DbConstants.products,
          productToSave.toMap()..remove('id'),
          where: 'id = ?',
          whereArgs: [productId],
        );
        if (existing != null &&
            (existing.salePrice - productToSave.salePrice).abs() > 0.009) {
          await txn.insert(
            DbConstants.productPriceHistory,
            ProductPriceHistoryModel(
              productId: productId,
              previousPrice: existing.salePrice,
              newPrice: productToSave.salePrice,
              changedAt: now,
            ).toMap()..remove('id'),
          );
        }
      }

      return ProductModel(
        id: productId,
        categories: productToSave.categories,
        brandName: productToSave.brandName,
        name: productToSave.name,
        sku: productToSave.sku,
        salePrice: productToSave.salePrice,
        notes: productToSave.notes,
        createdAt: productToSave.createdAt,
        updatedAt: productToSave.updatedAt,
      );
    });
  }

  Future<void> deleteProduct(int productId) async {
    await delete(productId);
  }

  Future<ProductModel?> fetchProduct(int productId) => findOne(productId);

  Future<List<ProductPriceHistoryModel>> fetchPriceHistory(int productId) async {
    final database = await db;
    final rows = await database.query(
      DbConstants.productPriceHistory,
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'changed_at DESC',
    );
    return rows.map(ProductPriceHistoryModel.fromMap).toList();
  }
}
