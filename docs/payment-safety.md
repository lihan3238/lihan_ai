# Payment Safety

## Phase One: Manual Confirmation

Payment mode is manual confirmation. The user submits or reports payment, and an administrator grants quota only after checking the actual received amount. Keep a separate payment ledger with order id, user id, amount, package, operator, and timestamp.

## Required Order State Machine

Future automatic payment must use this state flow:

`created -> pending_payment -> paid_uncredited -> credited -> closed`

Failure states are `expired`, `cancelled`, `refunded`, and `chargeback`.

## Automatic Payment Gate

Do not enable automatic top-up until the implementation verifies:

- Provider webhook signature.
- Order id exists and belongs to the user.
- Amount, currency, and payment method match the created order.
- The order has not already been credited.
- Webhook handling is idempotent.
- Repeated callbacks do not create repeated quota grants.
- Manual and automatic credit paths cannot both credit the same order.
- Daily abnormal recharge thresholds notify the operator and freeze suspicious orders.

## Manual Ledger Fields

Minimum ledger fields:

`order_id,user_id,email,package_id,amount_cny,payment_channel,payment_reference,operator,status,created_at,credited_at,note`
