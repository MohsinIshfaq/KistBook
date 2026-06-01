<?php

namespace App\Http\Requests\Payments;

use App\Http\Requests\Concerns\NormalizesCamelCaseInput;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdatePaymentRequest extends FormRequest
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
        $uuid = $this->route('uuid');

        return [
            'operation_uuid' => ['sometimes', 'uuid', Rule::unique('payments', 'operation_uuid')->ignore($uuid, 'uuid')],
            'customer_uuid' => ['sometimes', 'uuid', 'exists:customers,uuid'],
            'plan_uuid' => ['sometimes', 'uuid', 'exists:plans,uuid'],
            'installment_uuid' => ['sometimes', 'uuid', 'exists:installments,uuid'],
            'amount' => ['sometimes', 'numeric', 'min:0.01'],
            'paid_on' => ['sometimes', 'date'],
            'note' => ['nullable', 'string'],
            'source' => ['nullable', 'string', 'max:50'],
            'created_by' => ['sometimes', 'uuid', 'exists:users,uuid'],
        ];
    }
}
