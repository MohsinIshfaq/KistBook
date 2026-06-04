# KistBook Laravel Backend

Laravel 13 API backend for installment, customer, product, payment, and sync-ready operations. The codebase follows a layered structure:

- Controllers
- Form Requests
- Services
- Repositories
- Interfaces
- API Resources
- Unit / Feature Tests

Normal REST APIs return camelCase keys only. CamelCase request fields are the public standard, while existing snake_case request aliases remain accepted for backward compatibility. The legacy Flutter transports at `/api/sync/upload` and `/api/sync/download` retain their snake_case contract.

## Stack

- PHP 8.3+
- Laravel 13
- MySQL
- Laravel Sanctum
- UUID-based business records
- Soft deletes for business entities
- Company-scoped owner and salesman access
- Generic product variants with dynamic attributes
- Offline-first customer synchronization
- Multi-product common and separate installment plans

## Project Structure

- `app/Http/Controllers/Api` API controllers
- `app/Http/Requests` request validation
- `app/Http/Resources` response transformers
- `app/Contracts/Repositories` repository interfaces
- `app/Contracts/Services` service interfaces
- `app/Repositories` data access classes
- `app/Services` business logic
- `app/Models` Eloquent models and relationships
- `database/migrations` MySQL schema
- `database/seeders` demo data seeders
- `tests/Feature` API tests
- `tests/Unit` service-level tests

## Setup

```bash
cd backend
cp .env.example .env
/opt/homebrew/bin/php artisan key:generate
```

Update `.env` if your local MySQL credentials differ:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=kistbook_backend
DB_USERNAME=root
DB_PASSWORD=
```

## Run Commands

Install dependencies:

```bash
/opt/homebrew/bin/composer install
```

Run migrations:

```bash
/opt/homebrew/bin/php artisan migrate
```

Create the public storage symlink for product image URLs:

```bash
/opt/homebrew/bin/php artisan storage:link
```

Customer and product images are stored on the `public` disk by default. The disk and customer-sync batch limits can be changed with the `KISTBOOK_*` variables in `.env`.

Seed demo data:

```bash
/opt/homebrew/bin/php artisan db:seed
```

Fresh migrate with seed:

```bash
/opt/homebrew/bin/php artisan migrate:fresh --seed
```

Start API server:

```bash
/opt/homebrew/bin/php artisan serve
```

Run tests:

```bash
/opt/homebrew/bin/php artisan test
```

## Demo Credentials

- Owner
  - Phone: `03000000001`
  - Password: `password`
- Salesman
  - Phone: `03000000002`
  - Password: `password`

## Main APIs

### Auth

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/profile`
- `POST /api/auth/logout`
- `GET /api/me` (backward-compatible profile alias)
- `PATCH /api/auth/profile`
- `POST /api/company/users` owner-only salesman creation

### Customer Offline Sync

- `GET /api/customers/{uuid}` customer detail
- `GET /api/customers/sync?lastUpdatedAt=...&limit=10` download up to 10 changed customers
- `POST /api/customers/sync` create between 1 and 10 customers
- `PUT /api/customers/sync` update between 1 and 10 customers
- `DELETE /api/customers/sync` delete between 1 and 10 customers

Customer add, edit, and delete operations are intentionally local-first. Mutation requests send only a `customers` array. HTTP methods define the action: `POST` create, `PUT` update, and `DELETE` delete. Update and delete rows send `serverId`; the client does not send `syncStatus`. Mark local rows as synced when the server returns `isSync: true`. Download responses contain active customers only; deleted server objects are excluded. When download returns `hasMore: true`, send the returned `nextCursor.lastUpdatedAt` and `nextCursor.lastServerId` values with the next request.

### CRUD

- `GET|POST /api/categories`
- `GET|PUT|PATCH|DELETE /api/categories/{uuid}`
- `GET|POST /api/plans`
- `GET|PUT|PATCH|DELETE /api/plans/{uuid}`
- `GET|POST /api/installments`
- `GET|PUT|PATCH|DELETE /api/installments/{uuid}`
- `GET|POST /api/payments`
- `GET|PUT|PATCH|DELETE /api/payments/{uuid}`

### Product Offline Sync

- `GET /api/products/{uuid}` product detail
- `GET /api/products/sync?lastUpdatedAt=...&limit=10` download up to 10 changed products
- `POST /api/products/sync` create between 1 and 10 products
- `PUT /api/products/sync` update between 1 and 10 products
- `DELETE /api/products/sync` delete between 1 and 10 products

Product mutation requests send only a `products` array. HTTP methods define the action. Create requires only `productName` and `salesPrice`; `categoryId`, `productImages`, `brandName`, and `skuCode` are optional. Update and delete rows send `serverId`. Product images use optional base64 `productImages` entries. Sending `productImages` in a `PUT` row replaces the current images; omitting it preserves existing images. Sending `variants` in a `PUT` row replaces the active generic variant set.

### Canonical Installment Plans

- `GET|POST /api/installment-plans`
- `GET|PUT|PATCH|DELETE /api/installment-plans/{uuid}`

Canonical installment plans support multiple products, a common schedule, or separate per-product schedules. Existing `/api/plans`, `/api/installments`, and generic `/api/sync/*` routes remain available for Flutter compatibility.

### API Documentation And Postman

- Full API guide: `API_DOCUMENTATION.md`
- Postman collection: `KistBook_Laravel_API.postman_collection.json`
- Postman environment: `KistBook_Environment.postman_environment.json`

Import both Postman files, select `KistBook Environment`, run signup or use seeded credentials, then run login. The login test script automatically stores the Sanctum bearer token.

### Access and Dashboard

- `POST /api/access/customer`
- `POST /api/access/plan`
- `GET /api/dashboard`

## Example Requests

Register:

```bash
curl -X POST http://127.0.0.1:8000/api/auth/register \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "New",
    "lastName": "Owner",
    "email": "owner@example.com",
    "phoneNumber": "03001234567",
    "password": "password",
    "companyName": "KistBook Demo Company",
    "companyPhone": "03001234567",
    "companyAddress": "Bahawalpur"
  }'
```

Login:

```bash
curl -X POST http://127.0.0.1:8000/api/auth/login \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
    "login": "03000000001",
    "password": "password"
  }'
```

Create salesman as an authenticated owner:

```bash
curl -X POST http://127.0.0.1:8000/api/company/users \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Sales",
    "lastName": "Man",
    "email": "salesman@example.com",
    "phoneNumber": "03123456789",
    "password": "password",
    "passwordConfirmation": "password"
  }'
```

Upload locally created customer:

```bash
curl -X POST http://127.0.0.1:8000/api/customers/sync \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "customers": [
      {
        "cardNumber": "CARD-9001",
        "customerName": "Ali Khan",
        "phoneNumber": "03005551234",
        "cnic": "12345-1234567-1",
        "address": "Lahore",
        "reference": "Friend",
        "customerImageBase64": "BASE64_IMAGE_DATA",
        "customerImageOriginalName": "customer.jpg",
        "customerImageMimeType": "image/jpeg"
      }
    ]
  }'
```

Create plan:

```bash
curl -X POST http://127.0.0.1:8000/api/plans \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "CUSTOMER_UUID",
    "productId": "PRODUCT_UUID",
    "quantity": 1,
    "unitPrice": 25000,
    "totalAmount": 25000,
    "depositAmount": 5000,
    "installmentAmount": 5000,
    "installmentCount": 4,
    "frequencyInDays": 30,
    "firstDueDate": "2026-05-12",
    "note": "New installment plan",
    "status": "active"
  }'
```

Upload locally created product:

```bash
curl -X POST http://127.0.0.1:8000/api/products/sync \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "products": [
      {
        "productName": "Reno 13",
        "salesPrice": 118000,
        "productImages": [
          {
            "imageBase64": "BASE64_IMAGE_DATA",
            "originalName": "front.jpg",
            "mimeType": "image/jpeg"
          }
        ]
      }
    ]
  }'
```

Update product:

```bash
curl -X PUT http://127.0.0.1:8000/api/products/sync \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "products": [
      {
        "serverId": "PRODUCT_UUID",
        "productName": "Reno 13 Pro",
        "salesPrice": 120000
      }
    ]
  }'
```

Product image rules:

- `productImages` is optional, max 12 base64 images per product.
- Supported image MIME types: `image/jpeg`, `image/png`, `image/webp`, `image/heic`.
- Max decoded image size: 5 MB each.
- Sending `productImages` in `PUT /api/products/sync` replaces the active image set.
- Omitting `productImages` in an update preserves current images.

Create payment:

```bash
curl -X POST http://127.0.0.1:8000/api/payments \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "operationId": "7d6bd214-c813-42e1-9804-6ed9b7f4f603",
    "customerId": "CUSTOMER_UUID",
    "planId": "PLAN_UUID",
    "installmentId": "INSTALLMENT_UUID",
    "amount": 2500,
    "paidOn": "2026-05-12",
    "note": "Partial payment",
    "source": "mobile"
  }'
```

## Example Success Response

```json
{
  "success": true,
  "message": "Customer sync upload completed",
  "mappings": [
    {
      "index": 0,
      "serverId": "019f3b6e-5637-72fe-8dc5-1c5fbf4ab999"
    }
  ],
  "synced": [
    {
      "serverId": "019f3b6e-5637-72fe-8dc5-1c5fbf4ab999",
      "customerName": "Ali Khan",
      "isSync": true,
      "syncStatus": "synced"
    }
  ],
  "failed": [],
  "conflicts": []
}
```

## Business Rules Implemented

- Sanctum token authentication
- UUID-based records for syncable entities
- Soft deletes on business records
- Owner-scoped product and variant SKU uniqueness
- Assigned-only salesman customer access with automatic assignment on sync create
- Device-scoped customer local ID mappings and timestamp conflict responses
- Dynamic product variant attributes
- Common and per-item installment schedule generation
- Paid schedule preservation when canonical plans are edited
- Automatic plan installment generation
- Payment idempotency via `operationId`
- Installment paid amount and status recalculation
- Dashboard aggregate metrics
- Sync-ready tables:
  - `sync_change_log`
  - `device_sync_state`
  - `sync_conflicts`

## Verification

Verified locally with:

- `php artisan migrate:fresh --seed`
- `php artisan route:list`
- `php artisan test`
