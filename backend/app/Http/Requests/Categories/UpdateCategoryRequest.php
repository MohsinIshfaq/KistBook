<?php

namespace App\Http\Requests\Categories;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateCategoryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $uuid = $this->route('uuid');

        return [
            'name' => ['sometimes', 'string', 'max:255', Rule::unique('product_categories', 'name')->where('company_id', $this->user()?->company_id)->ignore($uuid, 'uuid')],
        ];
    }
}
