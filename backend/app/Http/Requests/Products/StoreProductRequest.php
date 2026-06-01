<?php

namespace App\Http\Requests\Products;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreProductRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        $basePrice = $this->input('base_price', $this->input('basePrice', $this->input('sales_price')));
        $this->merge([
            'brand_name' => $this->input('brand_name', $this->input('brandName')),
            'product_name' => $this->input('product_name', $this->input('productName')),
            'code' => $this->input('code', $this->input('skuCode')),
            'base_price' => $basePrice,
            'sales_price' => $this->input('sales_price', $basePrice),
            'primary_category_uuid' => $this->input('primary_category_uuid', $this->input('categoryId')),
            'category_uuids' => $this->input('category_uuids', $this->input('categoryIds', $this->input('categoryUuids'))),
            'variants' => $this->normalizeVariants($this->input('variants', [])),
        ]);

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
        return [
            'brand_name' => ['required', 'string', 'max:255'],
            'product_name' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'max:100', Rule::unique('products', 'code')->where('company_id', $this->user()?->company_id)],
            'sales_price' => ['required', 'numeric', 'min:0'],
            'base_price' => ['required', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
            'primary_category_uuid' => ['nullable', 'uuid', Rule::exists('product_categories', 'uuid')->where('company_id', $this->user()?->company_id)],
            'category_uuids' => ['nullable', 'array'],
            'category_uuids.*' => ['uuid', Rule::exists('product_categories', 'uuid')->where('company_id', $this->user()?->company_id)],
            'images' => ['nullable', 'array', 'max:12'],
            'images.*' => ['file', 'image', 'mimes:jpg,jpeg,png,webp,heic', 'max:5120'],
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
