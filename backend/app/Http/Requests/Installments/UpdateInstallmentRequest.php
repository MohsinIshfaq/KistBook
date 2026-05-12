<?php

namespace App\Http\Requests\Installments;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateInstallmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'plan_uuid' => ['sometimes', 'uuid', 'exists:plans,uuid'],
            'sequence_number' => ['sometimes', 'integer', 'min:1'],
            'scheduled_due_date' => ['sometimes', 'date'],
            'current_due_date' => ['sometimes', 'date'],
            'amount' => ['sometimes', 'numeric', 'min:0'],
            'paid_amount' => ['sometimes', 'numeric', 'min:0'],
            'status' => ['sometimes', Rule::in(['pending', 'partial', 'paid', 'overdue'])],
        ];
    }
}
