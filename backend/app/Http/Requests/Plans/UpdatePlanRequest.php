<?php

namespace App\Http\Requests\Plans;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdatePlanRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'customer_uuid' => ['sometimes', 'uuid', 'exists:customers,uuid'],
            'product_uuid' => ['sometimes', 'uuid', 'exists:products,uuid'],
            'quantity' => ['sometimes', 'integer', 'min:1'],
            'unit_price' => ['sometimes', 'numeric', 'min:0'],
            'total_amount' => ['sometimes', 'numeric', 'min:0'],
            'deposit_amount' => ['sometimes', 'numeric', 'min:0'],
            'installment_amount' => ['sometimes', 'numeric', 'min:0'],
            'installment_count' => ['sometimes', 'integer', 'min:1'],
            'frequency_days' => ['sometimes', 'integer', 'min:1'],
            'start_date' => ['sometimes', 'date'],
            'notes' => ['nullable', 'string'],
            'status' => ['sometimes', Rule::in(['active', 'completed', 'cancelled'])],
        ];
    }
}
