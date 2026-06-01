<?php

namespace App\Services;

use App\Contracts\Services\ProductServiceInterface;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\ProductVariant;
use App\Models\User;
use App\Support\ApiKeyFormatter;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Throwable;

class ProductSyncService
{
    public function __construct(
        private readonly ProductServiceInterface $products,
        private readonly ProductImageStorageService $images,
    ) {}

    public function download(?string $lastUpdatedAt, int $limit, ?string $lastServerId = null): array
    {
        $limit = max(1, min(10, $limit));
        $query = Product::query()
            ->where('is_deleted', false)
            ->with(['categories', 'images', 'variants.attributes']);
        if ($lastUpdatedAt !== null) {
            $timestamp = Carbon::parse($lastUpdatedAt);
            $query->where(function (Builder $query) use ($timestamp, $lastServerId): void {
                $query->where('updated_at', '>', $timestamp);
                if ($lastServerId !== null) {
                    $query->orWhere(function (Builder $query) use ($timestamp, $lastServerId): void {
                        $query
                            ->where('updated_at', '=', $timestamp)
                            ->where('uuid', '>', $lastServerId);
                    });
                }
            });
        }

        $records = $query
            ->orderBy('updated_at')
            ->orderBy('uuid')
            ->limit($limit + 1)
            ->get();
        $hasMore = $records->count() > $limit;
        $records = $records->take($limit)->values();
        $lastRecord = $records->last();

        return [
            'success' => true,
            'message' => 'Product sync data fetched successfully',
            'serverTime' => now()->toJSON(),
            'limit' => $limit,
            'count' => $records->count(),
            'hasMore' => $hasMore,
            'nextCursor' => $hasMore && $lastRecord instanceof Product ? [
                'lastUpdatedAt' => $lastRecord->updated_at?->toJSON(),
                'lastServerId' => $lastRecord->uuid,
            ] : null,
            'data' => $records->map(fn (Product $product): array => $this->serialize($product))->all(),
        ];
    }

    public function mutate(User $actor, array $rows, string $operation): array
    {
        if (count($rows) < 1 || count($rows) > 10) {
            throw ValidationException::withMessages([
                'products' => ['The products field must contain between 1 and 10 records.'],
            ]);
        }

        $mappings = [];
        $synced = [];
        $failed = [];
        $conflicts = [];

        foreach ($rows as $index => $row) {
            try {
                $result = DB::transaction(fn (): array => $this->syncRow($actor, $row, $operation));
                if (isset($result['conflict'])) {
                    $conflicts[] = ['index' => $index] + $result['conflict'];

                    continue;
                }

                $mappings[] = [
                    'index' => $index,
                    'serverId' => $result['serverId'],
                ];
                $synced[] = $result['product'];
            } catch (ValidationException $exception) {
                $failed[] = [
                    'index' => $index,
                    'serverId' => $row['serverId'] ?? $row['server_id'] ?? null,
                    'errors' => ApiKeyFormatter::validationErrors($exception->errors()),
                ];
            } catch (Throwable $exception) {
                report($exception);
                $failed[] = [
                    'index' => $index,
                    'serverId' => $row['serverId'] ?? $row['server_id'] ?? null,
                    'errors' => ['record' => [$exception->getMessage()]],
                ];
            }
        }

        return [
            'success' => true,
            'message' => 'Product sync upload completed',
            'serverTime' => now()->toJSON(),
            'mappings' => $mappings,
            'synced' => $synced,
            'failed' => $failed,
            'conflicts' => $conflicts,
        ];
    }

    private function syncRow(User $actor, array $row, string $operation): array
    {
        $row = $this->normalize($row);
        Validator::make($row, [
            'server_id' => [$operation === 'pending_create' ? 'nullable' : 'required', 'uuid'],
            'updated_at' => ['nullable', 'date'],
        ])->validate();

        $product = isset($row['server_id'])
            ? Product::query()->withTrashed()->where('uuid', $row['server_id'])->first()
            : null;

        if ($operation !== 'pending_create' && $product === null) {
            throw ValidationException::withMessages(['serverId' => ['The selected product is unavailable.']]);
        }

        if ($product && isset($row['updated_at']) && $product->updated_at->greaterThan(Carbon::parse($row['updated_at']))) {
            return [
                'conflict' => [
                    'serverId' => $product->uuid,
                    'reason' => 'The server product is newer than the uploaded record.',
                    'serverRecord' => $product->is_deleted || $product->trashed()
                        ? $this->deletionAcknowledgement($product)
                        : $this->serialize($product->load(['categories', 'images', 'variants.attributes'])),
                ],
            ];
        }

        if ($operation === 'pending_delete') {
            $this->products->delete($product->uuid);

            return [
                'serverId' => $product->uuid,
                'product' => $this->deletionAcknowledgement($product),
            ];
        }

        $data = $this->validateProductData($actor, $row, $product);
        $images = $data['product_images'] ?? null;
        unset($data['product_images']);

        $product = $operation === 'pending_create'
            ? $this->products->create($data)
            : $this->products->update($product->uuid, $data);

        if (is_array($images)) {
            $this->images->replaceBase64Images($product, $images);
        }

        return [
            'serverId' => $product->uuid,
            'product' => $this->serialize($product->load(['categories', 'images', 'variants.attributes'])),
        ];
    }

    private function validateProductData(User $actor, array $row, ?Product $product): array
    {
        $required = $product ? 'sometimes' : 'required';
        $maxImages = max(1, (int) config('kistbook.product_sync.max_images_per_product', 12));
        $data = Validator::make($row, [
            'brand_name' => [$required, 'string', 'max:255'],
            'product_name' => [$required, 'string', 'max:255'],
            'code' => [$required, 'string', 'max:100', Rule::unique('products', 'code')->where('company_id', $actor->company_id)->ignore($product?->uuid, 'uuid')],
            'base_price' => [$required, 'numeric', 'min:0'],
            'sales_price' => [$required, 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
            'primary_category_uuid' => ['nullable', 'uuid', Rule::exists('product_categories', 'uuid')->where('company_id', $actor->company_id)],
            'category_uuids' => ['nullable', 'array'],
            'category_uuids.*' => ['uuid', Rule::exists('product_categories', 'uuid')->where('company_id', $actor->company_id)],
            'product_images' => ['nullable', 'array', 'max:'.$maxImages],
            'product_images.*.image_base64' => ['required', 'string'],
            'product_images.*.original_name' => ['nullable', 'string', 'max:255'],
            'product_images.*.mime_type' => ['nullable', Rule::in(['image/jpeg', 'image/png', 'image/webp', 'image/heic'])],
            'variants' => ['nullable', 'array'],
            'variants.*.uuid' => ['nullable', 'uuid'],
            'variants.*.sku_code' => ['required', 'string', 'max:100', 'distinct'],
            'variants.*.sale_price' => ['required', 'numeric', 'min:0'],
            'variants.*.attributes' => ['nullable', 'array'],
            'variants.*.attributes.*.name' => ['required', 'string', 'max:100'],
            'variants.*.attributes.*.value' => ['required', 'string', 'max:255'],
        ])->validate();

        return $data;
    }

    private function normalize(array $row): array
    {
        $basePrice = $row['basePrice'] ?? $row['base_price'] ?? $row['sales_price'] ?? null;

        return array_filter([
            'server_id' => $row['serverId'] ?? $row['server_id'] ?? $row['id'] ?? null,
            'updated_at' => $row['updatedAt'] ?? $row['updated_at'] ?? null,
            'brand_name' => $row['brandName'] ?? $row['brand_name'] ?? null,
            'product_name' => $row['productName'] ?? $row['product_name'] ?? null,
            'code' => $row['skuCode'] ?? $row['code'] ?? null,
            'base_price' => $basePrice,
            'sales_price' => $basePrice,
            'notes' => $row['notes'] ?? null,
            'primary_category_uuid' => $row['categoryId'] ?? $row['primary_category_uuid'] ?? null,
            'category_uuids' => $row['categoryIds'] ?? $row['category_uuids'] ?? null,
            'product_images' => $this->normalizeImages($row['productImages'] ?? $row['product_images'] ?? null),
            'variants' => $this->normalizeVariants($row['variants'] ?? null),
        ], fn (mixed $value): bool => $value !== null);
    }

    private function normalizeImages(mixed $images): mixed
    {
        if (! is_array($images)) {
            return $images;
        }

        return array_map(fn (mixed $image): mixed => is_array($image) ? [
            'image_base64' => $image['imageBase64'] ?? $image['image_base64'] ?? null,
            'original_name' => $image['originalName'] ?? $image['original_name'] ?? null,
            'mime_type' => $image['mimeType'] ?? $image['mime_type'] ?? null,
        ] : $image, $images);
    }

    private function normalizeVariants(mixed $variants): mixed
    {
        if (! is_array($variants)) {
            return $variants;
        }

        return array_map(fn (mixed $variant): mixed => is_array($variant) ? [
            'uuid' => $variant['serverId'] ?? $variant['uuid'] ?? null,
            'sku_code' => $variant['skuCode'] ?? $variant['sku_code'] ?? null,
            'sale_price' => $variant['salePrice'] ?? $variant['sale_price'] ?? null,
            'attributes' => $variant['attributes'] ?? [],
        ] : $variant, $variants);
    }

    private function deletionAcknowledgement(Product $product): array
    {
        return [
            'serverId' => $product->uuid,
            'isSync' => true,
            'syncStatus' => 'synced',
            'isDeleted' => true,
        ];
    }

    private function serialize(Product $product): array
    {
        return [
            'serverId' => $product->uuid,
            'categoryId' => $product->primary_category_uuid,
            'categoryIds' => $product->categories->pluck('uuid')->values()->all(),
            'brandName' => $product->brand_name,
            'productName' => $product->product_name,
            'skuCode' => $product->code,
            'basePrice' => (float) ($product->base_price ?? $product->sales_price),
            'notes' => $product->notes,
            'productImages' => $product->images->map(fn (ProductImage $image): array => [
                'serverId' => $image->uuid,
                'url' => url(Storage::disk($image->disk)->url($image->path)),
                'originalName' => $image->original_name,
                'mimeType' => $image->mime_type,
                'size' => $image->size,
                'sortOrder' => $image->sort_order,
            ])->values()->all(),
            'variants' => $product->variants->map(fn (ProductVariant $variant): array => [
                'serverId' => $variant->uuid,
                'skuCode' => $variant->sku_code,
                'salePrice' => (float) $variant->sale_price,
                'attributes' => $variant->attributes->map(fn ($attribute): array => [
                    'name' => $attribute->name,
                    'value' => $attribute->value,
                ])->values()->all(),
            ])->values()->all(),
            'isSync' => true,
            'syncStatus' => 'synced',
            'isDeleted' => false,
            'createdAt' => $product->created_at?->toJSON(),
            'updatedAt' => $product->updated_at?->toJSON(),
        ];
    }
}
