<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class RegisterRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        $firstName = $this->input('first_name', $this->input('firstName'));
        $lastName = $this->input('last_name', $this->input('lastName'));
        $name = $this->input('name', trim(implode(' ', array_filter([$firstName, $lastName]))));

        $this->merge([
            'name' => $name,
            'email' => $this->input('email'),
            'phone' => $this->input('phone', $this->input('phoneNumber')),
            'company_name' => $this->input('company_name', $this->input('companyName')),
            'company_phone' => $this->input('company_phone', $this->input('companyPhone')),
            'company_address' => $this->input('company_address', $this->input('companyAddress')),
            'password_confirmation' => $this->input('password_confirmation', $this->input('password')),
        ]);
    }

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:150'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['required', 'string', 'max:30', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'company_name' => ['nullable', 'string', 'max:150'],
            'company_phone' => ['nullable', 'string', 'max:30'],
            'company_address' => ['nullable', 'string', 'max:500'],
        ];
    }
}
