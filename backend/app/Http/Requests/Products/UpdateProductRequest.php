<?php

namespace App\Http\Requests\Products;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProductRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        $aliases = [];
        foreach ([
            'brand_name' => 'brandName',
            'product_name' => 'productName',
            'code' => 'skuCode',
            'sales_price' => 'salesPrice',
            'primary_category_uuid' => 'categoryId',
            'category_uuids' => 'categoryIds',
            'image_uuids' => 'imageUuids',
            'remove_image_uuids' => 'removeImageUuids',
        ] as $field => $alias) {
            if (! $this->has($field) && $this->has($alias)) {
                $aliases[$field] = $this->input($alias);
            }
        }
        if (! $this->has('category_uuids') && ! array_key_exists('category_uuids', $aliases) && $this->has('categoryUuids')) {
            $aliases['category_uuids'] = $this->input('categoryUuids');
        }
        if (! $this->has('base_price') && $this->has('basePrice')) {
            $aliases['base_price'] = $this->input('basePrice');
        }
        if (! $this->has('sales_price') && (array_key_exists('base_price', $aliases) || $this->has('base_price'))) {
            $aliases['sales_price'] = $aliases['base_price'] ?? $this->input('base_price');
        }
        if ($this->has('variants')) {
            $aliases['variants'] = $this->normalizeVariants($this->input('variants'));
        }
        $this->merge($aliases);

        if ($this->hasFile('productImages') && ! $this->hasFile('images')) {
            $this->files->set('images', $this->file('productImages'));
        }
    }

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $uuid = $this->route('uuid');

        return [
            'brand_name' => ['sometimes', 'nullable', 'string', 'max:255'],
            'product_name' => ['sometimes', 'string', 'max:255'],
            'code' => ['sometimes', 'string', 'max:100', Rule::unique('products', 'code')->where('company_id', $this->user()?->company_id)->ignore($uuid, 'uuid')],
            'sales_price' => ['sometimes', 'numeric', 'min:0'],
            'base_price' => ['sometimes', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
            'primary_category_uuid' => ['nullable', 'uuid', Rule::exists('product_categories', 'uuid')->where('company_id', $this->user()?->company_id)],
            'category_uuids' => ['nullable', 'array'],
            'category_uuids.*' => ['uuid', Rule::exists('product_categories', 'uuid')->where('company_id', $this->user()?->company_id)],
            'images' => ['nullable', 'array', 'max:12'],
            'images.*' => ['file', 'image', 'mimes:jpg,jpeg,png,webp,heic', 'max:5120'],
            'image_uuids' => ['nullable', 'array'],
            'image_uuids.*' => [
                'uuid',
                'distinct',
                Rule::exists('product_images', 'uuid')->where(fn ($query) => $query->where('product_uuid', $uuid)),
            ],
            'remove_image_uuids' => ['nullable', 'array'],
            'remove_image_uuids.*' => [
                'uuid',
                'distinct',
                Rule::exists('product_images', 'uuid')->where(fn ($query) => $query->where('product_uuid', $uuid)),
            ],
            'variants' => ['nullable', 'array'],
            'variants.*.uuid' => ['nullable', 'uuid'],
            'variants.*.sku_code' => ['required', 'string', 'max:100', 'distinct'],
            'variants.*.sale_price' => ['required', 'numeric', 'min:0'],
            'variants.*.attributes' => ['nullable', 'array'],
            'variants.*.attributes.*.name' => ['required', 'string', 'max:100'],
            'variants.*.attributes.*.value' => ['required', 'string', 'max:255'],
        ];
    }

    private function normalizeVariants(mixed $variants): mixed
    {
        if (! is_array($variants)) {
            return $variants;
        }

        return array_map(fn (mixed $variant): mixed => is_array($variant) ? [
            ...$variant,
            'sku_code' => $variant['sku_code'] ?? $variant['skuCode'] ?? null,
            'sale_price' => $variant['sale_price'] ?? $variant['salePrice'] ?? null,
        ] : $variant, $variants);
    }
}
