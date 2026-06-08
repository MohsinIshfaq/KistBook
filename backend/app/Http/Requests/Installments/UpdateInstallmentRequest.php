<?php

namespace App\Http\Requests\Installments;

use App\Http\Requests\Concerns\NormalizesCamelCaseInput;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateInstallmentRequest extends FormRequest
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
            'plan_uuid' => ['sometimes', 'uuid', 'exists:plans,uuid'],
            'sequence_number' => ['sometimes', 'integer', 'min:1'],
            'scheduled_due_date' => ['sometimes', 'date'],
            'current_due_date' => ['sometimes', 'date'],
            'previous_due_date' => ['nullable', 'date'],
            'amount' => ['sometimes', 'numeric', 'min:0'],
            'paid_amount' => ['sometimes', 'numeric', 'min:0'],
            'status' => ['sometimes', Rule::in(['pending', 'partial', 'paid', 'overdue', 'rescheduled'])],
            'reschedule_note' => ['nullable', 'string'],
            'rescheduled_at' => ['nullable', 'date'],
        ];
    }
}
