<?php

namespace App\Http\Requests\Access;

use App\Http\Requests\Concerns\NormalizesCamelCaseInput;
use Illuminate\Foundation\Http\FormRequest;

class ReplaceAssignmentsRequest extends FormRequest
{
    use NormalizesCamelCaseInput;

    protected function prepareForValidation(): void
    {
        $this->mergeCamelCaseAliases([
            'user_uuid' => 'userId',
            'customer_uuids' => 'customerIds',
            'plan_uuids' => 'planIds',
        ]);
    }

    public function authorize(): bool
    {
        return $this->user()?->isOwner() === true;
    }

    public function rules(): array
    {
        return [
            'user_uuid' => ['required', 'uuid', 'exists:users,uuid'],
            'customer_uuids' => ['present', 'array'],
            'customer_uuids.*' => ['uuid', 'distinct', 'exists:customers,uuid'],
            'plan_uuids' => ['present', 'array'],
            'plan_uuids.*' => ['uuid', 'distinct', 'exists:plans,uuid'],
        ];
    }
}
