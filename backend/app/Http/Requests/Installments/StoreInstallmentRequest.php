<?php

namespace App\Http\Requests\Installments;

use App\Http\Requests\Concerns\NormalizesCamelCaseInput;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreInstallmentRequest extends FormRequest
{
    use NormalizesCamelCaseInput;

    protected function prepareForValidation(): void
    {
        $this->mergeCamelCaseAliases([
            'plan_uuid' => 'planId',
            'sequence_number' => 'sequenceNumber',
            'scheduled_due_date' => 'scheduledDueDate',
            'current_due_date' => 'currentDueDate',
            'previous_due_date' => 'previousDueDate',
            'paid_amount' => 'paidAmount',
            'reschedule_note' => 'rescheduleNote',
            'rescheduled_at' => 'rescheduledAt',
        ]);
    }

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
            'previous_due_date' => ['nullable', 'date'],
            'amount' => ['required', 'numeric', 'min:0'],
            'paid_amount' => ['nullable', 'numeric', 'min:0'],
            'status' => ['nullable', Rule::in(['pending', 'partial', 'paid', 'overdue', 'rescheduled'])],
            'reschedule_note' => ['nullable', 'string'],
            'rescheduled_at' => ['nullable', 'date'],
        ];
    }
}
