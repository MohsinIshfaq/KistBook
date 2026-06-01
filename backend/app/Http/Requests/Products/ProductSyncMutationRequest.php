<?php

namespace App\Http\Requests\Products;

use Illuminate\Foundation\Http\FormRequest;

class ProductSyncMutationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->company_id !== null;
    }

    public function rules(): array
    {
        $maxUploadRecords = max(1, min(10, (int) config('kistbook.product_sync.max_upload_records', 10)));

        return [
            'products' => ['required', 'array', 'min:1', 'max:'.$maxUploadRecords],
            'products.*' => ['required', 'array'],
        ];
    }
}
