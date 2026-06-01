<?php

namespace App\Http\Requests\CompanyUsers;

use App\Http\Requests\Concerns\NormalizesCamelCaseInput;
use Illuminate\Foundation\Http\FormRequest;

class StoreCompanyUserRequest extends FormRequest
{
    use NormalizesCamelCaseInput;

    protected function prepareForValidation(): void
    {
        $this->mergeCamelCaseAliases([
            'phone' => 'phoneNumber',
            'password_confirmation' => 'passwordConfirmation',
        ]);

        if (! $this->has('name') && $this->has('firstName')) {
            $this->merge([
                'name' => trim(implode(' ', array_filter([
                    $this->input('firstName'),
                    $this->input('lastName'),
                ]))),
            ]);
        }
    }

    public function authorize(): bool
    {
        return $this->user()?->isOwner() === true && $this->user()?->company_id !== null;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:150'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['required', 'string', 'max:30', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ];
    }
}
