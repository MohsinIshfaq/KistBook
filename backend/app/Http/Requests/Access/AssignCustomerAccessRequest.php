<?php

namespace App\Http\Requests\Access;

use App\Http\Requests\Concerns\NormalizesCamelCaseInput;
use Illuminate\Foundation\Http\FormRequest;

class AssignCustomerAccessRequest extends FormRequest
{
    use NormalizesCamelCaseInput;

    protected function prepareForValidation(): void
    {
        $this->mergeCamelCaseAliases([
            'user_uuid' => 'userId',
            'customer_uuid' => 'customerId',
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
            'customer_uuid' => ['required', 'uuid', 'exists:customers,uuid'],
        ];
    }
}
