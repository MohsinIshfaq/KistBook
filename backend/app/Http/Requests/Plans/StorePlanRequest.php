<?php

namespace App\Http\Requests\Plans;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePlanRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'customer_uuid' => ['required', 'uuid', 'exists:customers,uuid'],
            'product_uuid' => ['required', 'uuid', 'exists:products,uuid'],
            'quantity' => ['required', 'integer', 'min:1'],
            'unit_price' => ['required', 'numeric', 'min:0'],
            'total_amount' => ['required', 'numeric', 'min:0'],
            'deposit_amount' => ['nullable', 'numeric', 'min:0'],
            'installment_amount' => ['required', 'numeric', 'min:0'],
            'installment_count' => ['required', 'integer', 'min:1'],
            'frequency_days' => ['required', 'integer', 'min:1'],
            'start_date' => ['required', 'date'],
            'notes' => ['nullable', 'string'],
            'status' => ['nullable', Rule::in(['active', 'completed', 'cancelled'])],
        ];
    }
}
