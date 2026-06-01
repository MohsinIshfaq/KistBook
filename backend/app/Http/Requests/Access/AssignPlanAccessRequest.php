<?php

namespace App\Http\Requests\Access;

use App\Http\Requests\Concerns\NormalizesCamelCaseInput;
use Illuminate\Foundation\Http\FormRequest;

class AssignPlanAccessRequest extends FormRequest
{
    use NormalizesCamelCaseInput;

    protected function prepareForValidation(): void
    {
        $this->mergeCamelCaseAliases([
            'user_uuid' => 'userId',
            'plan_uuid' => 'planId',
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
            'plan_uuid' => ['required', 'uuid', 'exists:plans,uuid'],
        ];
    }
}
