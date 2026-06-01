<?php

namespace App\Services;

use App\Models\Customer;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use InvalidArgumentException;

class CustomerImageStorageService
{
    public function storeBase64(Customer $customer, string $encoded, ?string $originalName = null, ?string $mimeType = null): array
    {
        $encoded = preg_replace('/^data:[^;]+;base64,/', '', $encoded) ?? $encoded;
        $bytes = base64_decode($encoded, true);

        if ($bytes === false) {
            throw new InvalidArgumentException('Invalid customer image payload.');
        }

        $extension = $this->extension($originalName, $mimeType);
        $path = 'customers/'.$customer->uuid.'/'.Str::uuid()->toString().'.'.$extension;
        Storage::disk($this->disk())->put($path, $bytes);

        return [
            'image_disk' => $this->disk(),
            'image_path' => $path,
            'image_original_name' => $originalName ?? 'customer-image.'.$extension,
            'image_mime_type' => $mimeType ?? $this->mimeType($extension),
            'image_size' => strlen($bytes),
        ];
    }

    public function deleteCurrent(Customer $customer): void
    {
        if ($customer->image_disk && $customer->image_path) {
            Storage::disk($customer->image_disk)->delete($customer->image_path);
        }
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
        return (string) config('kistbook.customer_image_disk', 'public');
    }
}
