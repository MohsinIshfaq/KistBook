<?php

namespace App\Http\Requests\Products;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $uuid = $this->route('uuid');

        return [
            'brand_name' => ['sometimes', 'string', 'max:255'],
            'product_name' => ['sometimes', 'string', 'max:255'],
            'code' => ['sometimes', 'string', 'max:100', Rule::unique('products', 'code')->ignore($uuid, 'uuid')],
            'sales_price' => ['sometimes', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
            'category_uuids' => ['nullable', 'array'],
            'category_uuids.*' => ['uuid', 'exists:product_categories,uuid'],
        ];
    }
}
