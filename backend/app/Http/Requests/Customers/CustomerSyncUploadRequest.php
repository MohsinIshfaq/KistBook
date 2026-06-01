<?php

namespace App\Http\Requests\Customers;

use Illuminate\Foundation\Http\FormRequest;

class CustomerSyncUploadRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->company_id !== null;
    }

    public function rules(): array
    {
        $maxUploadRecords = max(1, min(10, (int) config('kistbook.customer_sync.max_upload_records', 10)));

        return [
            'deviceId' => ['nullable', 'string', 'max:191'],
            'device_id' => ['nullable', 'string', 'max:191'],
            'customers' => ['required', 'array', 'min:1', 'max:'.$maxUploadRecords],
            'customers.*' => ['required', 'array'],
        ];
    }
}
