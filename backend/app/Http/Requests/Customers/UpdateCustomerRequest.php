<?php

namespace App\Http\Requests\Customers;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateCustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $uuid = $this->route('uuid');

        return [
            'card_no' => ['sometimes', 'string', 'max:50', Rule::unique('customers', 'card_no')->ignore($uuid, 'uuid')],
            'name' => ['sometimes', 'string', 'max:255'],
            'phone' => ['sometimes', 'string', 'max:20'],
            'cnic' => ['sometimes', 'string', 'max:50', Rule::unique('customers', 'cnic')->ignore($uuid, 'uuid')],
            'address' => ['nullable', 'string'],
            'reference' => ['nullable', 'string', 'max:255'],
        ];
    }
}
