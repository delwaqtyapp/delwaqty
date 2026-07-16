# API Plan

## Overview

Delwaqty uses Supabase as the primary backend, providing a PostgreSQL database, authentication, real-time subscriptions, edge functions, and storage.

## Base URLs

| Environment | URL |
|-------------|-----|
| Development | https://your-dev-project.supabase.co |
| Staging | https://your-staging-project.supabase.co |
| Production | https://your-prod-project.supabase.co |

## Authentication

All API calls require a valid JWT token from Supabase Auth.

### Headers
```
Authorization: Bearer <jwt-token>
apikey: <supabase-anon-key>
Content-Type: application/json
```

## Database Tables

### Users
- `users` - User profiles
- `admin_users` - Admin user accounts
- `user_preferences` - User settings

### Commerce
- `merchants` - Merchant accounts
- `products` - Product catalog
- `categories` - Product categories
- `orders` - Order history
- `order_items` - Order line items
- `reviews` - Product reviews
- `coupons` - Discount coupons
- `favorites` - User favorites

### Delivery
- `drivers` - Driver accounts
- `deliveries` - Delivery tracking
- `geofences` - Geographic zones

### Platform
- `activity_logs` - Admin activity
- `platform_settings` - App configuration
- `notifications` - Push notifications

## Real-time Subscriptions

```dart
supabase
  .from('orders')
  .stream(primaryKey: ['id'])
  .eq('user_id', userId)
  .listen((data) {
    // Handle real-time order updates
  });
```

## Edge Functions

Planned edge functions:
- `send-notification` - Push notification delivery
- `process-payment` - Payment processing
- `validate-coupon` - Coupon validation
- `calculate-delivery` - Delivery cost calculation

## Storage Buckets

| Bucket | Purpose |
|--------|---------|
| avatars | User profile images |
| merchants | Merchant logos and photos |
| products | Product images |
| documents | Admin documents |

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| Auth endpoints | 30 requests/minute |
| API endpoints | 100 requests/minute |
| Storage uploads | 10 uploads/minute |

## Error Handling

All errors follow Supabase format:
```json
{
  "message": "Error message",
  "code": "ERROR_CODE",
  "details": "Additional info",
  "hint": "Suggestion"
}
```
