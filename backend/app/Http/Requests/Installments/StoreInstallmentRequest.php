<?php

namespace App\Http\Requests\Installments;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreInstallmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'plan_uuid' => ['required', 'uuid', 'exists:plans,uuid'],
            'sequence_number' => ['required', 'integer', 'min:1'],
            'scheduled_due_date' => ['required', 'date'],
            'current_due_date' => ['required', 'date'],
            'amount' => ['required', 'numeric', 'min:0'],
            'paid_amount' => ['nullable', 'numeric', 'min:0'],
            'status' => ['nullable', Rule::in(['pending', 'partial', 'paid', 'overdue'])],
        ];
    }
}
