<?php

namespace App\Http\Requests\Customers;

use Illuminate\Foundation\Http\FormRequest;

class StoreCustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'card_no' => ['required', 'string', 'max:50', 'unique:customers,card_no'],
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'max:20'],
            'cnic' => ['required', 'string', 'max:50', 'unique:customers,cnic'],
            'address' => ['nullable', 'string'],
            'reference' => ['nullable', 'string', 'max:255'],
        ];
    }
}
