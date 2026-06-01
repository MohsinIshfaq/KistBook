# KistBook Laravel Backend

Laravel 13 API backend for installment, customer, product, payment, and sync-ready operations. The codebase follows a layered structure:

- Controllers
- Form Requests
- Services
- Repositories
- Interfaces
- API Resources
- Unit / Feature Tests

## Stack

- PHP 8.3+
- Laravel 13
- MySQL
- Laravel Sanctum
- UUID-based business records
- Soft deletes for business entities

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
- `POST /api/company/users` owner-only salesman creation

### CRUD

- `GET|POST /api/customers`
- `GET|PUT|PATCH|DELETE /api/customers/{uuid}`
- `GET|POST /api/products`
- `GET|PUT|PATCH|DELETE /api/products/{uuid}`
- `POST /api/products/{uuid}` multipart update alias for product image uploads
- `GET|POST /api/categories`
- `GET|PUT|PATCH|DELETE /api/categories/{uuid}`
- `GET|POST /api/plans`
- `GET|PUT|PATCH|DELETE /api/plans/{uuid}`
- `GET|POST /api/installments`
- `GET|PUT|PATCH|DELETE /api/installments/{uuid}`
- `GET|POST /api/payments`
- `GET|PUT|PATCH|DELETE /api/payments/{uuid}`

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
    "name": "New Owner",
    "email": "owner@example.com",
    "phone": "03001234567",
    "password": "password",
    "password_confirmation": "password",
    "company_name": "KistBook Demo Company",
    "company_phone": "03001234567",
    "company_address": "Bahawalpur"
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
    "name": "Sales Man",
    "email": "salesman@example.com",
    "phone": "03123456789",
    "password": "password",
    "password_confirmation": "password"
  }'
```

Create customer:

```bash
curl -X POST http://127.0.0.1:8000/api/customers \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "card_no": "CARD-9001",
    "name": "Ali Khan",
    "phone": "03005551234",
    "cnic": "12345-1234567-1",
    "address": "Lahore",
    "reference": "Friend"
  }'
```

Create plan:

```bash
curl -X POST http://127.0.0.1:8000/api/plans \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_uuid": "CUSTOMER_UUID",
    "product_uuid": "PRODUCT_UUID",
    "quantity": 1,
    "unit_price": 25000,
    "total_amount": 25000,
    "deposit_amount": 5000,
    "installment_amount": 5000,
    "installment_count": 4,
    "frequency_days": 30,
    "start_date": "2026-05-12",
    "notes": "New installment plan",
    "status": "active"
  }'
```

Create product with images:

```bash
curl -X POST http://127.0.0.1:8000/api/products \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "brand_name=Oppo" \
  -F "product_name=Reno 13" \
  -F "code=REN-13" \
  -F "sales_price=118000" \
  -F "category_uuids[]=CATEGORY_UUID" \
  -F "images[]=@/absolute/path/front.jpg" \
  -F "images[]=@/absolute/path/back.jpg"
```

Update product images:

```bash
curl -X POST http://127.0.0.1:8000/api/products/PRODUCT_UUID \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "product_name=Reno 13 Pro" \
  -F "image_uuids[]=EXISTING_IMAGE_UUID_TO_KEEP_FIRST" \
  -F "remove_image_uuids[]=IMAGE_UUID_TO_REMOVE" \
  -F "images[]=@/absolute/path/new-angle.jpg"
```

Product image rules:

- `images[]` is optional, max 12 files per request.
- Supported image types: `jpg`, `jpeg`, `png`, `webp`, `heic`.
- Max image size: 5 MB each.
- The first image by `sort_order` is returned as `primary_image`.
- Send `image_uuids[]` on update to keep and reorder existing images.
- Send `remove_image_uuids[]` on update to remove specific existing images.

Create payment:

```bash
curl -X POST http://127.0.0.1:8000/api/payments \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "operation_uuid": "7d6bd214-c813-42e1-9804-6ed9b7f4f603",
    "customer_uuid": "CUSTOMER_UUID",
    "plan_uuid": "PLAN_UUID",
    "installment_uuid": "INSTALLMENT_UUID",
    "amount": 2500,
    "paid_on": "2026-05-12",
    "note": "Partial payment",
    "source": "mobile"
  }'
```

## Example Success Response

```json
{
  "success": true,
  "message": "Customer created successfully.",
  "data": {
    "uuid": "019f3b6e-5637-72fe-8dc5-1c5fbf4ab999",
    "card_no": "CARD-9001",
    "name": "Ali Khan",
    "phone": "03005551234",
    "cnic": "12345-1234567-1",
    "address": "Lahore",
    "reference": "Friend",
    "plans": [],
    "payments": [],
    "users": [],
    "created_at": "2026-05-12T10:00:00.000000Z",
    "updated_at": "2026-05-12T10:00:00.000000Z"
  }
}
```

## Business Rules Implemented

- Sanctum token authentication
- UUID-based records for syncable entities
- Soft deletes on business records
- Automatic plan installment generation
- Payment idempotency via `operation_uuid`
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
