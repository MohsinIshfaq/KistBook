<?php

namespace App\Http\Requests\Plans;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class UpsertInstallmentPlanRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        $products = $this->input('selected_products', $this->input('selectedProducts', []));
        $this->merge([
            'customer_uuid' => $this->input('customer_uuid', $this->input('customerId')),
            'mode' => $this->input('mode', 'common'),
            'selected_products' => $this->normalizeProducts($products),
            'common_deposit' => $this->input('common_deposit', $this->input('commonDeposit', 0)),
            'common_installment_amount' => $this->input('common_installment_amount', $this->input('commonInstallmentAmount')),
            'common_frequency_days' => $this->input('common_frequency_days', $this->input('commonFrequencyInDays')),
            'common_first_due_date' => $this->input('common_first_due_date', $this->input('commonFirstDueDate')),
            'notes' => $this->input('notes', $this->input('note')),
        ]);
    }

    public function authorize(): bool
    {
        return $this->user()?->company_id !== null;
    }

    public function rules(): array
    {
        return [
            'customer_uuid' => ['required', 'uuid'],
            'mode' => ['required', Rule::in(['common', 'separate'])],
            'selected_products' => ['required', 'array', 'min:1'],
            'selected_products.*.uuid' => ['nullable', 'uuid'],
            'selected_products.*.product_uuid' => ['required', 'uuid'],
            'selected_products.*.variant_uuid' => ['nullable', 'uuid'],
            'selected_products.*.quantity' => ['required', 'integer', 'min:1'],
            'selected_products.*.agreed_price' => ['nullable', 'numeric', 'min:0'],
            'selected_products.*.deposit' => ['nullable', 'numeric', 'min:0'],
            'selected_products.*.installment_amount' => ['nullable', 'numeric', 'gt:0'],
            'selected_products.*.frequency_days' => ['nullable', 'integer', 'min:1'],
            'selected_products.*.first_due_date' => ['nullable', 'date'],
            'common_deposit' => ['nullable', 'numeric', 'min:0'],
            'common_installment_amount' => ['nullable', 'numeric', 'gt:0'],
            'common_frequency_days' => ['nullable', 'integer', 'min:1'],
            'common_first_due_date' => ['nullable', 'date'],
            'notes' => ['nullable', 'string'],
            'status' => ['nullable', Rule::in(['active', 'completed', 'cancelled'])],
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator): void {
                if ($this->input('mode') === 'common') {
                    foreach (['common_installment_amount', 'common_frequency_days', 'common_first_due_date'] as $field) {
                        if (! $this->filled($field)) {
                            $validator->errors()->add($field, 'The '.$field.' field is required for common plans.');
                        }
                    }

                    return;
                }

                foreach ($this->input('selected_products', []) as $index => $product) {
                    foreach (['installment_amount', 'frequency_days', 'first_due_date'] as $field) {
                        if (! isset($product[$field]) || $product[$field] === '') {
                            $validator->errors()->add("selected_products.$index.$field", 'This field is required for separate plans.');
                        }
                    }
                }
            },
        ];
    }

    private function normalizeProducts(mixed $products): mixed
    {
        if (! is_array($products)) {
            return $products;
        }

        return array_map(fn (mixed $product): mixed => is_array($product) ? [
            ...$product,
            'product_uuid' => $product['product_uuid'] ?? $product['productId'] ?? null,
            'variant_uuid' => $product['variant_uuid'] ?? $product['variantId'] ?? null,
            'quantity' => $product['quantity'] ?? 1,
            'agreed_price' => $product['agreed_price'] ?? $product['agreedPrice'] ?? null,
            'deposit' => $product['deposit'] ?? 0,
            'installment_amount' => $product['installment_amount'] ?? $product['installmentAmount'] ?? null,
            'frequency_days' => $product['frequency_days'] ?? $product['frequencyInDays'] ?? null,
            'first_due_date' => $product['first_due_date'] ?? $product['firstDueDate'] ?? null,
        ] : $product, $products);
    }
}
