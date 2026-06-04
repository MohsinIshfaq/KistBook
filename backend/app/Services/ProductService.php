<?php

namespace App\Services;

use App\Contracts\Repositories\ProductRepositoryInterface;
use App\Contracts\Services\ProductServiceInterface;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\ProductVariant;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;
use Illuminate\Validation\ValidationException;

class ProductService implements ProductServiceInterface
{
    private const IMAGE_DISK = 'public';

    public function __construct(private readonly ProductRepositoryInterface $products) {}

    public function list(int $perPage = 15, ?string $search = null): LengthAwarePaginator
    {
        return $this->products->paginateSearch($perPage, $search, ['categories', 'images', 'variants.attributes']);
    }

    public function create(array $data): Product
    {
        return DB::transaction(function () use ($data): Product {
            $categoryUuids = $data['category_uuids'] ?? [];
            $images = $data['images'] ?? [];
            $variants = $data['variants'] ?? [];
            unset($data['category_uuids'], $data['images'], $data['variants']);
            $data['brand_name'] = $data['brand_name'] ?? '';
            $data['code'] = $data['code'] ?? $this->generateSku((int) ($data['company_id'] ?? auth()->user()?->company_id));
            $data['base_price'] = $data['base_price'] ?? $data['sales_price'];
            $categoryUuids = $this->categoryUuids($categoryUuids, $data['primary_category_uuid'] ?? null);

            /** @var Product $product */
            $product = $this->products->create($data);
            $this->products->syncCategories($product, $categoryUuids);
            $this->storeImages($product, $images);
            $this->syncVariants($product, $variants);

            return $product->load(['categories', 'images', 'variants.attributes']);
        });
    }

    public function show(string $uuid): Product
    {
        return $this->products->findByUuidOrFail($uuid, ['categories', 'images', 'variants.attributes', 'plans']);
    }

    public function update(string $uuid, array $data): Product
    {
        return DB::transaction(function () use ($uuid, $data): Product {
            $product = $this->products->findByUuidOrFail($uuid, ['images']);
            $categoryUuids = $data['category_uuids'] ?? null;
            $images = $data['images'] ?? [];
            $imageUuids = $data['image_uuids'] ?? null;
            $removeImageUuids = $data['remove_image_uuids'] ?? [];
            $variants = $data['variants'] ?? null;
            unset(
                $data['category_uuids'],
                $data['images'],
                $data['image_uuids'],
                $data['remove_image_uuids'],
                $data['variants'],
            );

            /** @var Product $updated */
            $updated = $this->products->update($product, $data);

            if (is_array($categoryUuids) || array_key_exists('primary_category_uuid', $data)) {
                $categoryUuids ??= $updated->categories()->pluck('uuid')->all();
                $categoryUuids = $this->categoryUuids($categoryUuids, $data['primary_category_uuid'] ?? $updated->primary_category_uuid);
                $this->products->syncCategories($updated, $categoryUuids);
            }

            $this->syncExistingImages($updated, $imageUuids, $removeImageUuids);
            $this->storeImages($updated, $images);
            $this->compactImageOrder($updated);
            if (is_array($variants)) {
                $this->syncVariants($updated, $variants);
            }

            return $updated->load(['categories', 'images', 'variants.attributes']);
        });
    }

    public function delete(string $uuid): void
    {
        DB::transaction(function () use ($uuid): void {
            $product = $this->products->findByUuidOrFail($uuid, ['images']);
            $this->deleteImages($product->images);
            foreach ($product->variants()->get() as $variant) {
                $this->deleteVariant($variant);
            }
            $this->products->softDelete($product);
        });
    }

    private function syncVariants(Product $product, array $variants): void
    {
        $kept = [];
        foreach ($variants as $data) {
            $variant = isset($data['uuid'])
                ? $product->variants()->withTrashed()->where('uuid', $data['uuid'])->first()
                : null;
            if (isset($data['uuid']) && $variant === null) {
                throw ValidationException::withMessages(['variants' => ['The selected variant does not belong to this product.']]);
            }
            $duplicate = ProductVariant::query()
                ->withTrashed()
                ->where('sku_code', $data['sku_code'])
                ->when($variant, fn ($query) => $query->where('uuid', '!=', $variant->uuid))
                ->exists();
            if ($duplicate) {
                throw ValidationException::withMessages(['variants' => ['Variant SKU ['.$data['sku_code'].'] is already in use.']]);
            }

            $variant ??= new ProductVariant(['product_uuid' => $product->uuid]);
            if ($variant->trashed()) {
                $variant->restore();
            }
            $variant->fill([
                'product_uuid' => $product->uuid,
                'sku_code' => $data['sku_code'],
                'sale_price' => $data['sale_price'],
                'is_deleted' => false,
            ])->save();
            $kept[] = $variant->uuid;

            foreach ($variant->attributes()->get() as $attribute) {
                $attribute->forceFill(['is_deleted' => true])->save();
                $attribute->delete();
            }
            foreach ($data['attributes'] ?? [] as $attribute) {
                $variant->attributes()->create([
                    'name' => $attribute['name'],
                    'value' => $attribute['value'],
                    'is_deleted' => false,
                ]);
            }
        }

        $product->variants()->whereNotIn('uuid', $kept)->get()->each(fn (ProductVariant $variant) => $this->deleteVariant($variant));
    }

    private function deleteVariant(ProductVariant $variant): void
    {
        foreach ($variant->attributes()->get() as $attribute) {
            $attribute->forceFill(['is_deleted' => true])->save();
            $attribute->delete();
        }
        $variant->forceFill(['is_deleted' => true])->save();
        $variant->delete();
    }

    private function categoryUuids(array $categoryUuids, ?string $primaryCategoryUuid): array
    {
        return array_values(array_unique(array_filter([...$categoryUuids, $primaryCategoryUuid])));
    }

    /**
     * @param  array<int, UploadedFile>  $images
     */
    private function storeImages(Product $product, array $images): void
    {
        if ($images === []) {
            return;
        }

        $currentMaxSortOrder = $product->images()->max('sort_order');
        $nextSortOrder = $currentMaxSortOrder === null ? 0 : ((int) $currentMaxSortOrder) + 1;

        foreach (array_values($images) as $image) {
            if (! $image instanceof UploadedFile) {
                continue;
            }

            $path = $image->storeAs(
                'products/'.$product->uuid,
                Str::uuid()->toString().'.'.$image->extension(),
                self::IMAGE_DISK
            );

            if (! is_string($path)) {
                throw new RuntimeException('Unable to store product image.');
            }

            $product->images()->create([
                'disk' => self::IMAGE_DISK,
                'path' => $path,
                'original_name' => $image->getClientOriginalName(),
                'mime_type' => $image->getClientMimeType(),
                'size' => $image->getSize(),
                'sort_order' => $nextSortOrder,
            ]);

            $nextSortOrder++;
        }
    }

    /**
     * @param  array<int, string>|null  $orderedImageUuids
     * @param  array<int, string>  $removeImageUuids
     */
    private function syncExistingImages(Product $product, ?array $orderedImageUuids, array $removeImageUuids): void
    {
        if (is_array($orderedImageUuids)) {
            $ownedImages = $product->images()->get()->keyBy('uuid');
            $orderedImageUuids = array_values(array_unique($orderedImageUuids));
            $removeImageUuids = array_values(array_unique($removeImageUuids));

            $keepUuids = collect($orderedImageUuids);
            $deleteUuids = $ownedImages
                ->keys()
                ->diff($keepUuids)
                ->merge($removeImageUuids)
                ->unique()
                ->values();

            $this->deleteImages(
                $ownedImages->filter(fn (ProductImage $image): bool => $deleteUuids->contains($image->uuid))
            );

            foreach ($orderedImageUuids as $sortOrder => $imageUuid) {
                /** @var ProductImage|null $image */
                $image = $ownedImages->get($imageUuid);
                if ($image === null || in_array($imageUuid, $removeImageUuids, true)) {
                    continue;
                }

                $image->forceFill(['sort_order' => $sortOrder])->save();
            }

            return;
        }

        if ($removeImageUuids !== []) {
            $imagesToRemove = $product->images()
                ->whereIn('uuid', array_values(array_unique($removeImageUuids)))
                ->get();

            $this->deleteImages($imagesToRemove);
        }
    }

    /**
     * @param  Collection<int, ProductImage>  $images
     */
    private function deleteImages(Collection $images): void
    {
        if ($images->isEmpty()) {
            return;
        }

        foreach ($images as $image) {
            Storage::disk($image->disk)->delete($image->path);
            $image->forceFill(['is_deleted' => true])->save();
            $image->delete();
        }
    }

    private function compactImageOrder(Product $product): void
    {
        $product->images()
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->values()
            ->each(function (ProductImage $image, int $sortOrder): void {
                if ($image->sort_order === $sortOrder) {
                    return;
                }

                $image->forceFill(['sort_order' => $sortOrder])->save();
            });
    }

    private function generateSku(int $companyId): string
    {
        do {
            $code = 'PRD-'.Str::upper(Str::random(10));
        } while (Product::query()
            ->where('company_id', $companyId)
            ->where('code', $code)
            ->exists());

        return $code;
    }
}
