<?php

return [
    'customer_sync' => [
        'default_limit' => (int) env('KISTBOOK_CUSTOMER_SYNC_DEFAULT_LIMIT', 10),
        'max_limit' => (int) env('KISTBOOK_CUSTOMER_SYNC_MAX_LIMIT', 10),
        'max_upload_records' => (int) env('KISTBOOK_CUSTOMER_SYNC_MAX_UPLOAD_RECORDS', 10),
    ],
    'product_sync' => [
        'default_limit' => (int) env('KISTBOOK_PRODUCT_SYNC_DEFAULT_LIMIT', 10),
        'max_limit' => (int) env('KISTBOOK_PRODUCT_SYNC_MAX_LIMIT', 10),
        'max_upload_records' => (int) env('KISTBOOK_PRODUCT_SYNC_MAX_UPLOAD_RECORDS', 10),
        'max_images_per_product' => (int) env('KISTBOOK_PRODUCT_SYNC_MAX_IMAGES_PER_PRODUCT', 12),
        'max_image_size_kb' => (int) env('KISTBOOK_PRODUCT_SYNC_MAX_IMAGE_SIZE_KB', 5120),
    ],
    'installment_plan_sync' => [
        'default_limit' => (int) env('KISTBOOK_INSTALLMENT_PLAN_SYNC_DEFAULT_LIMIT', 10),
        'max_limit' => (int) env('KISTBOOK_INSTALLMENT_PLAN_SYNC_MAX_LIMIT', 10),
        'max_upload_records' => (int) env('KISTBOOK_INSTALLMENT_PLAN_SYNC_MAX_UPLOAD_RECORDS', 10),
    ],
    'customer_image_disk' => env('KISTBOOK_CUSTOMER_IMAGE_DISK', 'public'),
    'product_image_disk' => env('KISTBOOK_PRODUCT_IMAGE_DISK', 'public'),
];
