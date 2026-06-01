<?php

namespace App\Http\Requests\Payments;

use App\Http\Requests\Concerns\NormalizesCamelCaseInput;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePaymentRequest extends FormRequest
{
    use NormalizesCamelCaseInput;

    protected function prepareForValidation(): void
    {
        $this->mergeCamelCaseAliases([
            'operation_uuid' => 'operationId',
            'customer_uuid' => 'customerId',
            'plan_uuid' => 'planId',
            'installment_uuid' => 'installmentId',
            'paid_on' => 'paidOn',
            'created_by' => 'createdBy',
        ]);
    }

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'operation_uuid' => ['required', 'uuid', 'unique:payments,operation_uuid'],
            'customer_uuid' => ['required', 'uuid', 'exists:customers,uuid'],
            'plan_uuid' => ['required', 'uuid', 'exists:plans,uuid'],
            'installment_uuid' => ['required', 'uuid', 'exists:installments,uuid'],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'paid_on' => ['required', 'date'],
            'note' => ['nullable', 'string'],
            'source' => ['nullable', 'string', 'max:50'],
            'created_by' => ['nullable', 'uuid', 'exists:users,uuid'],
        ];
    }
}
