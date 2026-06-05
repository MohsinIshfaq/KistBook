<?php

namespace App\Http\Requests\Plans;

use Illuminate\Foundation\Http\FormRequest;

class InstallmentPlanSyncMutationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->company_id !== null;
    }

    public function rules(): array
    {
        $maxUploadRecords = max(1, min(10, (int) config('kistbook.installment_plan_sync.max_upload_records', 10)));

        return [
            'plans' => ['required', 'array', 'min:1', 'max:'.$maxUploadRecords],
            'plans.*' => ['required', 'array'],
        ];
    }
}
