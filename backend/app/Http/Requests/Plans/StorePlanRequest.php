<?php

namespace App\Http\Requests\Plans;

use App\Http\Requests\Concerns\NormalizesCamelCaseInput;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePlanRequest extends FormRequest
{
    use NormalizesCamelCaseInput;

    protected function prepareForValidation(): void
    {
        $this->mergeCamelCaseAliases([
            'customer_uuid' => 'customerId',
            'product_uuid' => 'productId',
            'unit_price' => 'unitPrice',
            'total_amount' => 'totalAmount',
            'deposit_amount' => 'depositAmount',
            'installment_amount' => 'installmentAmount',
            'installment_count' => 'installmentCount',
            'frequency_days' => 'frequencyInDays',
            'start_date' => 'firstDueDate',
            'notes' => 'note',
        ]);
    }

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
