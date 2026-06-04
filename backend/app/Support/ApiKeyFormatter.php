<?php

namespace App\Support;

use Illuminate\Support\Str;

class ApiKeyFormatter
{
    /** @var array<string, string> */
    private const ALIASES = [
        'phone' => 'phoneNumber',
        'card_no' => 'cardNumber',
        'company_id' => 'companyId',
        'owner_id' => 'ownerId',
        'first_name' => 'firstName',
        'last_name' => 'lastName',
        'access_level' => 'accessLevel',
        'is_active' => 'isActive',
        'is_deleted' => 'isDeleted',
        'created_at' => 'createdAt',
        'updated_at' => 'updatedAt',
        'deleted_at' => 'deletedAt',
        'brand_name' => 'brandName',
        'product_name' => 'productName',
        'code' => 'skuCode',
        'sales_price' => 'salesPrice',
        'base_price' => 'salesPrice',
        'primary_category_uuid' => 'categoryId',
        'category_uuids' => 'categoryIds',
        'customer_uuid' => 'customerId',
        'product_uuid' => 'productId',
        'variant_uuid' => 'variantId',
        'plan_uuid' => 'planId',
        'plan_item_uuid' => 'planItemId',
        'installment_uuid' => 'installmentId',
        'operation_uuid' => 'operationId',
        'user_uuid' => 'userId',
        'created_by' => 'createdBy',
        'unit_price' => 'unitPrice',
        'total_amount' => 'totalAmount',
        'deposit_amount' => 'depositAmount',
        'remaining_amount' => 'remainingAmount',
        'installment_amount' => 'installmentAmount',
        'installment_count' => 'installmentCount',
        'frequency_days' => 'frequencyInDays',
        'start_date' => 'firstDueDate',
        'sequence_number' => 'sequenceNumber',
        'item_sequence_number' => 'itemSequenceNumber',
        'scheduled_due_date' => 'scheduledDueDate',
        'current_due_date' => 'currentDueDate',
        'schedule_group' => 'scheduleGroup',
        'paid_amount' => 'paidAmount',
        'paid_on' => 'paidOn',
        'device_id' => 'deviceId',
        'local_id' => 'localId',
        'server_id' => 'serverId',
        'sync_status' => 'syncStatus',
        'customer_image' => 'customerImage',
        'remove_customer_image' => 'removeCustomerImage',
        'customer_image_base64' => 'customerImageBase64',
        'customer_image_original_name' => 'customerImageOriginalName',
        'customer_image_mime_type' => 'customerImageMimeType',
        'image_uuids' => 'imageUuids',
        'remove_image_uuids' => 'removeImageUuids',
        'password_confirmation' => 'passwordConfirmation',
        'selected_products' => 'selectedProducts',
        'common_deposit' => 'commonDeposit',
        'common_installment_amount' => 'commonInstallmentAmount',
        'common_frequency_days' => 'commonFrequencyInDays',
        'common_first_due_date' => 'commonFirstDueDate',
    ];

    /**
     * @param  array<string, mixed>  $errors
     * @return array<string, mixed>
     */
    public static function validationErrors(array $errors): array
    {
        $formatted = [];

        foreach ($errors as $key => $messages) {
            $formatted[self::path($key)] = $messages;
        }

        return $formatted;
    }

    public static function path(string $key): string
    {
        return collect(explode('.', $key))
            ->map(fn (string $segment): string => ctype_digit($segment)
                ? $segment
                : (self::ALIASES[$segment] ?? Str::camel($segment)))
            ->implode('.');
    }
}
