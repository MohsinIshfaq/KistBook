import 'package:sqflite/sqflite.dart';

import '../../services/product_image_storage.dart';
import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../database/sync_metadata.dart';
import '../models/product_image_model.dart';
import '../models/product_model.dart';
import '../models/product_price_history_model.dart';
import '../models/product_variant_attribute_model.dart';
import '../models/product_variant_model.dart';
import 'generic_repository.dart';

class ProductRepository extends GenericRepository<ProductModel> {
  ProductRepository(DbHelper dbHelper)
    : super(
        dbHelper: dbHelper,
        tableName: DbConstants.products,
        fromMap: ProductModel.fromMap,
      );

  Future<List<ProductModel>> fetchProducts() async {
    final products = await getAll(orderBy: 'updated_at DESC');
    return _attachProductRelations(products);
  }

  Future<ProductModel> saveProduct(ProductModel product) async {
    final database = await db;
    final saveResult = await database.transaction<_ProductSaveResult>((
      txn,
    ) async {
      ProductModel? existing;
      var existingImagePaths = <String>[];
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
        existingImagePaths = await _fetchImagePaths(txn, product.id!);
      }

      final now = DateTime.now();
      final imagePaths = _normalizedImagePaths(product.imagePaths);
      final imagesChanged =
          product.id == null ||
          !_sameStringList(imagePaths, existingImagePaths);
      final productToSave = ProductModel(
        id: product.id,
        categories: product.categories,
        brandName: product.brandName,
        name: product.name,
        sku: product.sku,
        salePrice: product.salePrice,
        notes: product.notes,
        imagePaths: imagePaths,
        createdAt: existing?.createdAt ?? product.createdAt,
        updatedAt: now,
      );

      int productId;
      if (productToSave.id == null) {
        productId = await txn.insert(
          DbConstants.products,
          SyncMetadata.withLocalChange(
            DbConstants.products,
            productToSave.toMap()..remove('id'),
          ),
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
          SyncMetadata.withLocalChange(
            DbConstants.products,
            productToSave.toMap()..remove('id'),
          ),
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

      if (imagesChanged) {
        await _replaceImages(txn, productId, imagePaths, now);
      }
      await _replaceVariants(txn, productId, product.variants, now);

      final removedImagePaths = imagesChanged
          ? existingImagePaths
                .where((path) => !imagePaths.contains(path))
                .toSet()
                .toList()
          : <String>[];

      return _ProductSaveResult(
        product: ProductModel(
          id: productId,
          categories: productToSave.categories,
          brandName: productToSave.brandName,
          name: productToSave.name,
          sku: productToSave.sku,
          salePrice: productToSave.salePrice,
          notes: productToSave.notes,
          imagePaths: productToSave.imagePaths,
          variants: product.variants
              .map((variant) => variant.copyWith(productId: productId))
              .toList(),
          createdAt: productToSave.createdAt,
          updatedAt: productToSave.updatedAt,
        ),
        removedImagePaths: removedImagePaths,
      );
    });

    await _deleteImageFiles(saveResult.removedImagePaths);
    return saveResult.product;
  }

  Future<void> deleteProduct(int productId) async {
    final database = await db;
    final imagePaths = await database.transaction<List<String>>((txn) async {
      final paths = await _fetchImagePaths(txn, productId);
      final variantIds = await _fetchVariantIds(txn, productId);
      if (variantIds.isNotEmpty) {
        final placeholders = List.filled(variantIds.length, '?').join(',');
        await txn.update(
          DbConstants.productVariantAttributes,
          {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
          where: 'variant_id IN ($placeholders)',
          whereArgs: variantIds,
        );
      }
      await txn.update(
        DbConstants.productVariants,
        {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      await txn.update(
        DbConstants.productImages,
        SyncMetadata.withLocalChange(DbConstants.productImages, {
          'is_deleted': 1,
        }),
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      await txn.update(
        DbConstants.products,
        SyncMetadata.withLocalChange(DbConstants.products, {'is_deleted': 1}),
        where: 'id = ?',
        whereArgs: [productId],
      );
      return paths;
    });
    await _deleteImageFiles(imagePaths);
  }

  Future<ProductModel?> fetchProduct(int productId) async {
    final database = await db;
    final rows = await database.query(
      DbConstants.products,
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final imagePaths = await _fetchImagePaths(database, productId);
    final variants = await _fetchVariants(database, productId);
    return ProductModel.fromMap(
      rows.first,
    ).copyWith(imagePaths: imagePaths, variants: variants);
  }

  Future<List<ProductPriceHistoryModel>> fetchPriceHistory(
    int productId,
  ) async {
    final database = await db;
    final rows = await database.query(
      DbConstants.productPriceHistory,
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'changed_at DESC',
    );
    return rows.map(ProductPriceHistoryModel.fromMap).toList();
  }

  Future<List<ProductModel>> _attachProductRelations(
    List<ProductModel> products,
  ) async {
    final productIds = products
        .map((product) => product.id)
        .whereType<int>()
        .toList();
    if (productIds.isEmpty) {
      return products;
    }

    final database = await db;
    final imagePathsByProductId = await _fetchImagePathsByProductId(
      database,
      productIds,
    );
    final variantsByProductId = await _fetchVariantsByProductId(
      database,
      productIds,
    );
    return products
        .map(
          (product) => product.id == null
              ? product
              : product.copyWith(
                  imagePaths: imagePathsByProductId[product.id] ?? const [],
                  variants: variantsByProductId[product.id] ?? const [],
                ),
        )
        .toList();
  }

  Future<List<String>> _fetchImagePaths(
    DatabaseExecutor executor,
    int productId,
  ) async {
    final rows = await executor.query(
      DbConstants.productImages,
      columns: ['image_path'],
      where: 'product_id = ? AND is_deleted = 0',
      whereArgs: [productId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows
        .map((row) => row['image_path'] as String? ?? '')
        .where((path) => path.trim().isNotEmpty)
        .toList();
  }

  Future<Map<int, List<String>>> _fetchImagePathsByProductId(
    DatabaseExecutor executor,
    List<int> productIds,
  ) async {
    if (productIds.isEmpty) {
      return const {};
    }

    final placeholders = List.filled(productIds.length, '?').join(',');
    final rows = await executor.query(
      DbConstants.productImages,
      columns: ['product_id', 'image_path'],
      where: 'product_id IN ($placeholders) AND is_deleted = 0',
      whereArgs: productIds,
      orderBy: 'product_id ASC, sort_order ASC, id ASC',
    );

    final imagePathsByProductId = <int, List<String>>{};
    for (final row in rows) {
      final productId = row['product_id'] as int;
      final imagePath = row['image_path'] as String? ?? '';
      if (imagePath.trim().isEmpty) {
        continue;
      }
      imagePathsByProductId.putIfAbsent(productId, () => []).add(imagePath);
    }
    return imagePathsByProductId;
  }

  Future<void> _replaceImages(
    Transaction txn,
    int productId,
    List<String> imagePaths,
    DateTime createdAt,
  ) async {
    await txn.update(
      DbConstants.productImages,
      SyncMetadata.withLocalChange(DbConstants.productImages, {
        'is_deleted': 1,
      }),
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    for (var index = 0; index < imagePaths.length; index += 1) {
      await txn.insert(
        DbConstants.productImages,
        SyncMetadata.withLocalChange(
          DbConstants.productImages,
          ProductImageModel(
            productId: productId,
            imagePath: imagePaths[index],
            sortOrder: index,
            createdAt: createdAt,
          ).toMap()..remove('id'),
        ),
      );
    }
  }

  Future<void> _replaceVariants(
    Transaction txn,
    int productId,
    List<ProductVariantModel> variants,
    DateTime updatedAt,
  ) async {
    final existingVariantIds = await _fetchVariantIds(txn, productId);
    if (existingVariantIds.isNotEmpty) {
      final placeholders = List.filled(
        existingVariantIds.length,
        '?',
      ).join(',');
      await txn.update(
        DbConstants.productVariantAttributes,
        {'is_deleted': 1, 'updated_at': updatedAt.toIso8601String()},
        where: 'variant_id IN ($placeholders)',
        whereArgs: existingVariantIds,
      );
    }
    await txn.update(
      DbConstants.productVariants,
      {'is_deleted': 1, 'updated_at': updatedAt.toIso8601String()},
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    for (final variant in variants) {
      final values =
          variant
              .copyWith(
                productId: productId,
                createdAt: variant.createdAt.millisecondsSinceEpoch == 0
                    ? updatedAt
                    : variant.createdAt,
                updatedAt: updatedAt,
                isDeleted: false,
              )
              .toMap()
            ..remove('id');

      int variantId;
      if (variant.id != null &&
          existingVariantIds.contains(variant.id) &&
          await _variantBelongsToProduct(txn, variant.id!, productId)) {
        variantId = variant.id!;
        await txn.update(
          DbConstants.productVariants,
          values,
          where: 'id = ?',
          whereArgs: [variantId],
        );
      } else {
        variantId = await txn.insert(DbConstants.productVariants, values);
      }

      await txn.update(
        DbConstants.productVariantAttributes,
        {'is_deleted': 1, 'updated_at': updatedAt.toIso8601String()},
        where: 'variant_id = ?',
        whereArgs: [variantId],
      );

      for (final attribute in variant.attributes) {
        final name = attribute.name.trim();
        final value = attribute.value.trim();
        if (name.isEmpty || value.isEmpty) {
          continue;
        }
        await txn.insert(
          DbConstants.productVariantAttributes,
          ProductVariantAttributeModel(
            variantId: variantId,
            name: name,
            value: value,
            createdAt: updatedAt,
            updatedAt: updatedAt,
          ).toMap()..remove('id'),
        );
      }
    }
  }

  Future<List<int>> _fetchVariantIds(
    DatabaseExecutor executor,
    int productId,
  ) async {
    final rows = await executor.query(
      DbConstants.productVariants,
      columns: ['id'],
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    return rows.map((row) => row['id'] as int).toList();
  }

  Future<bool> _variantBelongsToProduct(
    DatabaseExecutor executor,
    int variantId,
    int productId,
  ) async {
    final rows = await executor.query(
      DbConstants.productVariants,
      columns: ['id'],
      where: 'id = ? AND product_id = ?',
      whereArgs: [variantId, productId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<ProductVariantModel>> _fetchVariants(
    DatabaseExecutor executor,
    int productId,
  ) async {
    final rows = await executor.query(
      DbConstants.productVariants,
      where: 'product_id = ? AND is_deleted = 0',
      whereArgs: [productId],
      orderBy: 'id ASC',
    );
    final variants = <ProductVariantModel>[];
    for (final row in rows) {
      final variantId = row['id'] as int?;
      final attributes = variantId == null
          ? const <ProductVariantAttributeModel>[]
          : await _fetchVariantAttributes(executor, variantId);
      variants.add(ProductVariantModel.fromMap(row, attributes: attributes));
    }
    return variants;
  }

  Future<Map<int, List<ProductVariantModel>>> _fetchVariantsByProductId(
    DatabaseExecutor executor,
    List<int> productIds,
  ) async {
    final result = <int, List<ProductVariantModel>>{};
    for (final productId in productIds) {
      result[productId] = await _fetchVariants(executor, productId);
    }
    return result;
  }

  Future<List<ProductVariantAttributeModel>> _fetchVariantAttributes(
    DatabaseExecutor executor,
    int variantId,
  ) async {
    final rows = await executor.query(
      DbConstants.productVariantAttributes,
      where: 'variant_id = ? AND is_deleted = 0',
      whereArgs: [variantId],
      orderBy: 'id ASC',
    );
    return rows.map(ProductVariantAttributeModel.fromMap).toList();
  }

  List<String> _normalizedImagePaths(List<String> imagePaths) {
    final seen = <String>{};
    final values = <String>[];
    for (final imagePath in imagePaths) {
      final normalized = imagePath.trim();
      if (normalized.isEmpty || seen.contains(normalized)) {
        continue;
      }
      seen.add(normalized);
      values.add(normalized);
    }
    return values;
  }

  bool _sameStringList(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _deleteImageFiles(List<String> imagePaths) async {
    for (final imagePath in imagePaths) {
      try {
        await ProductImageStorage.deleteImage(imagePath);
      } catch (_) {
        // Product data is already saved; stale files can be cleaned later.
      }
    }
  }
}

class _ProductSaveResult {
  const _ProductSaveResult({
    required this.product,
    required this.removedImagePaths,
  });

  final ProductModel product;
  final List<String> removedImagePaths;
}
