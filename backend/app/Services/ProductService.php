<?php

namespace App\Services;

use App\Contracts\Repositories\ProductRepositoryInterface;
use App\Contracts\Services\ProductServiceInterface;
use App\Models\Product;
use App\Models\ProductImage;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;

class ProductService implements ProductServiceInterface
{
    private const IMAGE_DISK = 'public';

    public function __construct(private readonly ProductRepositoryInterface $products) {}

    public function list(int $perPage = 15): LengthAwarePaginator
    {
        return $this->products->paginate($perPage, ['categories', 'images']);
    }

    public function create(array $data): Product
    {
        return DB::transaction(function () use ($data): Product {
            $categoryUuids = $data['category_uuids'] ?? [];
            $images = $data['images'] ?? [];
            unset($data['category_uuids'], $data['images']);

            /** @var Product $product */
            $product = $this->products->create($data);
            $this->products->syncCategories($product, $categoryUuids);
            $this->storeImages($product, $images);

            return $product->load(['categories', 'images']);
        });
    }

    public function show(string $uuid): Product
    {
        return $this->products->findByUuidOrFail($uuid, ['categories', 'images', 'plans']);
    }

    public function update(string $uuid, array $data): Product
    {
        return DB::transaction(function () use ($uuid, $data): Product {
            $product = $this->products->findByUuidOrFail($uuid, ['images']);
            $categoryUuids = $data['category_uuids'] ?? null;
            $images = $data['images'] ?? [];
            $imageUuids = $data['image_uuids'] ?? null;
            $removeImageUuids = $data['remove_image_uuids'] ?? [];
            unset(
                $data['category_uuids'],
                $data['images'],
                $data['image_uuids'],
                $data['remove_image_uuids'],
            );

            /** @var Product $updated */
            $updated = $this->products->update($product, $data);

            if (is_array($categoryUuids)) {
                $this->products->syncCategories($updated, $categoryUuids);
            }

            $this->syncExistingImages($updated, $imageUuids, $removeImageUuids);
            $this->storeImages($updated, $images);
            $this->compactImageOrder($updated);

            return $updated->load(['categories', 'images']);
        });
    }

    public function delete(string $uuid): void
    {
        DB::transaction(function () use ($uuid): void {
            $product = $this->products->findByUuidOrFail($uuid, ['images']);
            $this->deleteImages($product->images);
            $this->products->softDelete($product);
        });
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
}
