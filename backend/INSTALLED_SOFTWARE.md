# Installed Software Note

Laravel backend setup ke liye ye software install aur use kiya gaya:

## Installed Tools

- `PHP`
  - Version: `8.5.6`
  - Path: `/opt/homebrew/bin/php`

- `Composer`
  - Version: `2.9.7`
  - Path: `/opt/homebrew/bin/composer`

- `MySQL`
  - Version: `9.6.0`
  - Path: `/opt/homebrew/bin/mysql`

- `Laravel Sanctum`
  - Project dependency ke taur par install kiya gaya

## Services

- `MySQL service` Homebrew ke through start ki gayi

Start command:

```bash
brew services start mysql
```

Stop command:

```bash
brew services stop mysql
```

## Project Paths

- Backend project:
  `/Users/apptech1/Project/AppTechnologies/Flutter/KistBook/backend`

- Environment file:
  `/Users/apptech1/Project/AppTechnologies/Flutter/KistBook/backend/.env`

- README:
  `/Users/apptech1/Project/AppTechnologies/Flutter/KistBook/backend/README.md`

## Useful Commands

Check PHP version:

```bash
/opt/homebrew/bin/php --version
```

Check Composer version:

```bash
/opt/homebrew/bin/composer --version
```

Check MySQL version:

```bash
/opt/homebrew/bin/mysql --version
```

Run Laravel server:

```bash
cd /Users/apptech1/Project/AppTechnologies/Flutter/KistBook/backend
/opt/homebrew/bin/php artisan serve --host=127.0.0.1 --port=8000
```

Clear Laravel caches:

```bash
/opt/homebrew/bin/php artisan optimize:clear
```

Run migrations and seeders:

```bash
/opt/homebrew/bin/php artisan migrate:fresh --seed
```

Run tests:

```bash
/opt/homebrew/bin/php artisan test
```

## Demo Credentials

- Admin
  - Phone: `03000000001`
  - Password: `password`

- Salesman
  - Phone: `03000000002`
  - Password: `password`

## Reminder

Agar backend ka behavior ajeeb lage to pehle ye 3 steps try karo:

```bash
cd /Users/apptech1/Project/AppTechnologies/Flutter/KistBook/backend
/opt/homebrew/bin/php artisan optimize:clear
/opt/homebrew/bin/php artisan serve --host=127.0.0.1 --port=8000
```
