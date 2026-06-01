<?php

namespace App\Services;

use App\Models\Product;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Throwable;

class ProductImageStorageService
{
    public function replaceBase64Images(Product $product, array $images): void
    {
        $currentImages = $product->images()->get();
        $prepared = array_map(fn (array $image): array => $this->prepare($product, $image), array_values($images));
        $storedPaths = [];

        try {
            foreach ($prepared as $image) {
                Storage::disk($this->disk())->put($image['path'], $image['bytes']);
                $storedPaths[] = $image['path'];
            }

            foreach ($prepared as $sortOrder => $image) {
                $product->images()->create([
                    'disk' => $this->disk(),
                    'path' => $image['path'],
                    'original_name' => $image['original_name'],
                    'mime_type' => $image['mime_type'],
                    'size' => strlen($image['bytes']),
                    'sort_order' => $sortOrder,
                    'is_deleted' => false,
                ]);
            }

            $this->deleteImages($currentImages);
        } catch (Throwable $exception) {
            Storage::disk($this->disk())->delete($storedPaths);

            throw $exception;
        }
    }

    public function deleteCurrent(Product $product): void
    {
        $this->deleteImages($product->images()->get());
    }

    private function deleteImages(iterable $images): void
    {
        foreach ($images as $image) {
            Storage::disk($image->disk)->delete($image->path);
            $image->forceFill(['is_deleted' => true])->save();
            $image->delete();
        }
    }

    private function prepare(Product $product, array $image): array
    {
        $encoded = preg_replace('/^data:[^;]+;base64,/', '', (string) $image['image_base64']) ?? (string) $image['image_base64'];
        $bytes = base64_decode($encoded, true);

        if ($bytes === false) {
            throw ValidationException::withMessages(['productImages' => ['A product image contains invalid base64 data.']]);
        }

        $maxSize = max(1, (int) config('kistbook.product_sync.max_image_size_kb', 5120)) * 1024;
        if (strlen($bytes) > $maxSize) {
            throw ValidationException::withMessages(['productImages' => ['A product image may not be greater than '.((int) ($maxSize / 1024)).' kilobytes.']]);
        }

        $extension = $this->extension($image['original_name'] ?? null, $image['mime_type'] ?? null);

        return [
            'bytes' => $bytes,
            'path' => 'products/'.$product->uuid.'/'.Str::uuid()->toString().'.'.$extension,
            'original_name' => $image['original_name'] ?? 'product-image.'.$extension,
            'mime_type' => $image['mime_type'] ?? $this->mimeType($extension),
        ];
    }

    private function extension(?string $originalName, ?string $mimeType): string
    {
        $extension = strtolower(pathinfo((string) $originalName, PATHINFO_EXTENSION));
        if (in_array($extension, ['jpg', 'jpeg', 'png', 'webp', 'heic'], true)) {
            return $extension;
        }

        return match ($mimeType) {
            'image/png' => 'png',
            'image/webp' => 'webp',
            'image/heic' => 'heic',
            default => 'jpg',
        };
    }

    private function mimeType(string $extension): string
    {
        return match ($extension) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            'heic' => 'image/heic',
            default => 'image/jpeg',
        };
    }

    private function disk(): string
    {
        return (string) config('kistbook.product_image_disk', 'public');
    }
}
