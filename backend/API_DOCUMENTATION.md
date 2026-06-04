# KistBook Laravel API

Base URL: `http://127.0.0.1:8000/api`

Protected routes require:

```http
Authorization: Bearer <sanctum-token>
Accept: application/json
```

## Compatibility

- Normal REST API responses use camelCase keys only. CamelCase request fields are the documented public standard.
- Existing snake_case request aliases remain accepted for backward compatibility.
- `/api/sync/upload` and `/api/sync/download` remain legacy snake_case transports for the existing Flutter application.
- Business records remain isolated by company. Owners can access all company customers. Salesmen can access assigned customers only; customers they create are assigned automatically.

## Authentication And Profile

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `POST` | `/auth/register` | Create owner, shop, and Sanctum token |
| `POST` | `/auth/login` | Login with email or phone number |
| `POST` | `/auth/logout` | Revoke current token |
| `GET` | `/auth/profile` | Fetch current profile |
| `PATCH` | `/auth/profile` | Update current profile |

Register body:

```json
{
  "firstName": "Ali",
  "lastName": "Raza",
  "email": "ali@example.com",
  "phoneNumber": "03001234567",
  "password": "password",
  "companyName": "Ali Electronics"
}
```

`companyName`, `companyPhone`, and `companyAddress` are optional. If omitted, the shop name defaults to `<full name> Shop`.

## Customers

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/customers/{uuid}` | Customer detail |
| `GET` | `/customers/sync?lastUpdatedAt=...&limit=10` | Download customer changes |
| `POST` | `/customers/sync` | Create local customers on the server |
| `PUT` | `/customers/sync` | Update server customers |
| `DELETE` | `/customers/sync` | Soft-delete server customers |

Customer add, edit, and delete operations happen in the local application database first. Send only the `customers` array. The HTTP method defines the operation: `POST` creates, `PUT` updates, and `DELETE` deletes. Update and delete rows include `serverId`. The client does not send `syncStatus`.

Recommended local customer sync columns:

| Field | Purpose |
| --- | --- |
| `localId` | Optional stable local database row ID or UUID. It is not required for create uploads when the app maps returned `mappings[].index` values back to the input array |
| `serverId` | Server UUID returned after a successful create upload |
| `isSync` | Local boolean: `false` while a change is waiting for upload, then `true` after acknowledgement |
| `syncStatus` | Local-only operation state: `pending_create`, `pending_update`, `pending_delete`, or `synced`. Do not include it in customer sync mutation requests |
| `isDeleted` | Local soft-delete boolean used to hide a deleted row before sending it through `DELETE /customers/sync` |

### Customer Sync Download

```http
GET /customers/sync?lastUpdatedAt=2026-06-01T10:00:00.000Z&limit=10
```

- `limit` defaults to `10`; the maximum is `10`.
- Initial incremental requests use strict database `updated_at > lastUpdatedAt`. When `hasMore` is `true`, pass the returned `nextCursor.lastUpdatedAt` and `nextCursor.lastServerId` values to fetch the next batch safely.
- Records use ascending timestamp order with a stable server ID tie-breaker, so records sharing the same timestamp are not skipped.
- Only active customers are returned. Deleted server customer objects are excluded from download responses.

### Customer Sync Upload

```json
{
  "customers": [
    {
      "cardNumber": "CARD-42",
      "customerName": "Ahmed Khan",
      "phoneNumber": "03001112223",
      "cnic": "42101-1234567-1",
      "address": "Lahore",
      "reference": "Friend",
      "customerImageBase64": "BASE64_IMAGE_DATA",
      "customerImageOriginalName": "customer.jpg",
      "customerImageMimeType": "image/jpeg"
    }
  ]
}
```

Each mutation accepts between `1` and `10` customer records. For create uploads, send only customer fields. The response returns `mappings[].index` and `mappings[].serverId`, so the app can save the server UUID against the matching input row. Update and delete rows must send `serverId`; `syncStatus` is inferred from the HTTP method. Responses return `mappings`, `synced`, `failed`, and `conflicts`. Each successfully synced row contains `isSync: true`. Optional offline images use `customerImageBase64`, `customerImageOriginalName`, and `customerImageMimeType`; use `removeCustomerImage: true` in a `PUT` row to remove an existing image. Remove the image fields when no image is selected.

## Products

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/products/{uuid}` | Product detail |
| `GET` | `/products/sync?lastUpdatedAt=...&limit=10` | Download active product changes |
| `POST` | `/products/sync` | Create local products on the server |
| `PUT` | `/products/sync` | Update server products |
| `DELETE` | `/products/sync` | Soft-delete server products |

Product add, edit, and delete operations follow the same local-first contract as customers. Send only a `products` array. The HTTP method defines the operation. Update and delete rows must include `serverId`. Each mutation accepts between `1` and `10` products. Create requires only `productName` and `salesPrice`. `categoryId`, `productImages`, `brandName`, and `skuCode` are optional; when `skuCode` is omitted, the server generates a unique SKU.

Example generic variants:

```json
{
  "productName": "Inverter AC",
  "salesPrice": 185000,
  "variants": [
    {
      "skuCode": "GREE-AC-15T-PULAR",
      "salePrice": 190000,
      "attributes": [
        { "name": "Capacity", "value": "1.5 Ton" },
        { "name": "Series", "value": "Pular" },
        { "name": "Inverter", "value": "Yes" }
      ]
    }
  ]
}
```

Product SKU is optional; when supplied it must be unique within the company. Variant SKUs are unique within each company. Sending `variants` during update replaces the active variant set; omitted variants are soft deleted.

Optional product images use:

```json
{
  "productImages": [
    {
      "imageBase64": "BASE64_IMAGE_DATA",
      "originalName": "product.jpg",
      "mimeType": "image/jpeg"
    }
  ]
}
```

When `productImages` is included in a `PUT` row, it replaces the active image set. Omit `productImages` to preserve current images. Downloads return active products only with `serverId`, `isSync`, `syncStatus`, and `isDeleted`. Use the returned `nextCursor` when `hasMore` is `true`.

## Installment Plans

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/installment-plans?search=ali&perPage=15` | Canonical plan list |
| `POST` | `/installment-plans` | Create common or separate plan |
| `GET` | `/installment-plans/{uuid}` | Plan detail with items and schedules |
| `PUT` | `/installment-plans/{uuid}` | Replace plan configuration |
| `DELETE` | `/installment-plans/{uuid}` | Soft delete plan, items, and schedules |

Common plan body:

```json
{
  "customerId": "CUSTOMER_UUID",
  "mode": "common",
  "selectedProducts": [
    { "productId": "PRODUCT_UUID", "variantId": null, "quantity": 1 }
  ],
  "commonDeposit": 10000,
  "commonInstallmentAmount": 5000,
  "commonFrequencyInDays": 30,
  "commonFirstDueDate": "2026-06-15",
  "note": "Common schedule"
}
```

Separate mode moves `deposit`, `installmentAmount`, `frequencyInDays`, and `firstDueDate` into each selected product. `agreedPrice` is optional; otherwise the variant sale price or product base price is used. The final installment is reduced to the exact remaining balance. Paid schedules remain immutable during plan edits; future unpaid rows are rebuilt.

## Legacy Endpoints

The Flutter application can continue using `/plans`, `/installments`, `/payments`, `/categories`, `/access/*`, `/dashboard`, and the generic `/sync/*` endpoints without UI changes.
