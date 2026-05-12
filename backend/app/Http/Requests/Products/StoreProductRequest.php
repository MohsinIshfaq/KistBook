<?php

namespace App\Http\Requests\Products;

use Illuminate\Foundation\Http\FormRequest;

class StoreProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'brand_name' => ['required', 'string', 'max:255'],
            'product_name' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'max:100', 'unique:products,code'],
            'sales_price' => ['required', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
            'category_uuids' => ['nullable', 'array'],
            'category_uuids.*' => ['uuid', 'exists:product_categories,uuid'],
        ];
    }
}
