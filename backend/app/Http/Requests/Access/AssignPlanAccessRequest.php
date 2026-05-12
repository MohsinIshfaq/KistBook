<?php

namespace App\Http\Requests\Access;

use Illuminate\Foundation\Http\FormRequest;

class AssignPlanAccessRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'user_uuid' => ['required', 'uuid', 'exists:users,uuid'],
            'plan_uuid' => ['required', 'uuid', 'exists:plans,uuid'],
        ];
    }
}
