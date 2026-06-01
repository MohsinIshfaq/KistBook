<?php

namespace App\Http\Requests\Plans;

use App\Http\Requests\Concerns\NormalizesCamelCaseInput;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdatePlanRequest extends FormRequest
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
