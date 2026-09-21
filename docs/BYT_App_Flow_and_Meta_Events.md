# Book Your Turf — App Flow & Meta Event Map
**User app (Flutter) · September 2026 · covers every change made in v1–v5**

This document answers two questions:
1. What does the user go through, screen by screen?
2. Which Meta event fires at each step, with which parameters?

---

## 1. Funnel at a glance

```
App open                 fb_mobile_activate_app  (+ App Install, automatic)
   │
Login screen             —
   │  send OTP           otp_requested            (user_type = new_user / existing_user)
   │  OTP verified       new  → fb_mobile_complete_registration + new_user_signup
   │                     old  → existing_user_login
   │                     both → fb_mobile_login
   ▼
HOME                     home_view                (10 min throttle)
   │  search             fb_mobile_search
   ▼
TURF DETAILS             fb_mobile_content_view   (View Content)
   ▼
SLOT SCREEN              slot_view
   │  tap a slot         fb_mobile_add_to_cart    (value = slot price)
   ▼
BOOKING SUMMARY          fb_mobile_initiated_checkout   (value = total)
   │  offer applied      discount_applied         (auto_applied = 1/0)
   │  tap Pay            payment_initiated        (payment_method = online / wallet)
   │  payment failed     payment_failed           (reason)
   ▼
BOOKING SUCCESS          fb_mobile_purchase (value = amount paid)
                         + wallet_booking_success  or  online_booking_success
```

---

## 2. Screen-by-screen flow

### 2.1 App start
1. Firebase, Meta SDK, SharedPreferences, Dio start up. The Meta launch event is **not awaited**, so a slow SDK cannot delay the app.
2. Splash decides: token present → Main page, else → Login screen.
3. Home view model loads cached turfs instantly, asks for location once, then makes **one** turfs API call.

**Events:** `fb_mobile_activate_app`, App Install (automatic).

### 2.2 Login (phone + OTP)
1. User enters the mobile number → `POST /api/user/phone/send-otp/`.
2. Before the request, the app starts the **SMS Retriever** and sends its `app_hash`.
3. Backend replies with `is_registered`: `true` = old user, `false` = new user.
4. SMS arrives → OTP fills automatically (no popup) → verify → Main page.
   Device registration and turf refresh happen in the background, so Home opens immediately.

| Step | Event | Key params |
|---|---|---|
| Send OTP success | `otp_requested` | user_type, is_registered, is_resend, method |
| Verify — new number | `fb_mobile_complete_registration` + `new_user_signup` | fb_registration_method = phone_otp |
| Verify — old number | `existing_user_login` | user_type = existing_user |
| Verify — both | `fb_mobile_login` | user_type, user_id (no phone number) |

### 2.3 Home
- Greeting + location label, search bar, category chips, turf grid (2 columns).
- Scrolling to the bottom loads the next page and **appends** it; cards already on screen stay.
- Pull down = refresh.
- Guests can browse; tapping another tab asks them to log in.

| Action | Event | Key params |
|---|---|---|
| Screen opened / resumed | `home_view` (max once per 10 min) | user_type, location_label, visit_count |
| Search | `fb_mobile_search` | fb_search_string, result_count, fb_success |
| Favourite on / off | `fb_mobile_add_to_wishlist` / `favorite_removed` | turf_id, turf_name |

### 2.4 Turf details
Photos, address, amenities, price, "Book Now".

| Event | Key params |
|---|---|
| `fb_mobile_content_view` (View Content) | content_type = turf, content_id = turf_id, content_name, content_category = sport, city, currency = INR, visit_count |

> Note: the SDK's real name for View Content is `fb_mobile_content_view` (the tracking sheet wrote `fb_mobile_view_content`). Events Manager shows it as **View Content** either way.

### 2.5 Slot selection
Date strip, court selector, advance/full payment toggle, slot grid.

| Action | Event | Key params |
|---|---|---|
| Screen opened | `slot_view` | turf_id, city, sport, visit_count |
| Slot tapped (selected) | `fb_mobile_add_to_cart` | content_type = turf_slot, content_id, content_name, content_category, city, slot_time, date, num_items, payment_type, **value = slot price**, currency |

De-selecting a slot fires nothing.

### 2.6 Booking summary
Turf card, slot list, offers, fees, total, payment buttons.

| Action | Event | Key params |
|---|---|---|
| Screen opened | `fb_mobile_initiated_checkout` | content_type = turf_booking_summary, turf_id, turf_name, sport, num_items, booking_type, **value = total**, visit_count |
| Offer applied | `discount_applied` | discount ids, amount, auto_applied |
| Pay tapped | `payment_initiated` | payment_method = online / wallet, amount, turf_id |
| Payment failed / cancelled | `payment_failed` | payment_method, reason (user_cancelled, network_error, wallet_insufficient…), amount, turf_id |

**Payment path now:** tap Pay → Razorpay. No profile popup, no confirm popup. Wallet appears only when the balance is above ₹0, as a second option. Fees are shown on the summary ("No extra charge on UPI"). The best eligible offer is applied automatically.

### 2.7 Booking success
| Event | Key params |
|---|---|
| `fb_mobile_purchase` | **value = amount paid**, currency, fb_order_id, payment_method, booking_count, wallet_booking_count, online_booking_count, is_first_booking |
| `wallet_booking_success` *or* `online_booking_success` | same params + method_booking_count |
| Paid but confirm API failed | `booking_confirm_failed` (reason, order_id) |

Purchase is logged **once per payment** (de-duplicated by payment / order id).

### 2.8 Bookings tab
| Action | Event | Key params |
|---|---|---|
| Tab opened | `booking_history_view` | total / upcoming / cancelled / pending_payment bookings, visit_count |
| Balance paid | `balance_payment_success` | payment_method, amount, booking_id |
| Balance payment failed | `balance_payment_failed` | reason |
| Booking cancelled | `booking_cancelled` | refund_amount, cancel_count |

### 2.9 Dashboard / wallet / coins / notifications
| Screen | Event |
|---|---|
| Dashboard (profile tab) | `dashboard_view` |
| Wallet history | `wallet_history_view` |
| Coin history | `coin_history_view` |
| Notifications | `notifications_view` |
| Referral share | `app_shared` |
| Wallet recharge | `wallet_recharge_initiated` / `_success` / `_failed` |

Screen events are throttled (30 s) so rebuilds are not counted as new visits.

---

## 3. Tracking sheet (Sep 2026) — status

### Part A — tracking
| # | Required | Status |
|---|---|---|
| A2-1 | Complete Registration on first phone login | ✅ Done — driven by `is_registered` from send-otp |
| A2-2 | View Content on the turf page | ✅ Done, with content_name / content_category / city / currency |
| A2-3 | Add to Cart on slot tap | ✅ Done, value = slot price |
| A2-4 | Rename summary event to Initiated Checkout | ✅ Done (`turf_booking_summary`, value = total) |
| A3 | payment_initiated / payment_failed | ✅ Done (wallet insufficient included) |
| A3 | profile_popup_shown | ➖ Not needed — the popup itself was removed |
| A4 | Server-side Purchase (Conversions API) | ❌ Backend work, not started |

### Part B — app fixes
| # | Required | Status |
|---|---|---|
| B2-1 | Remove profile popup from the payment path | ✅ Done |
| B2-2 | Hide wallet button at ₹0, UPI as primary | ✅ Done |
| B2-3 | Remove the confirm popup | ✅ Done |
| B2-4 | Show fees on the summary | ✅ Done ("No extra charge on UPI") |
| B2-5 | Auto-apply the first-booking offer | ✅ Done in the app — the ₹100 offer must be created in the admin panel |
| B2-6 | Razorpay timeout | ⚠️ Left at 120 s — the backend slot lock is also 120 s; raising only the app side risks double bookings |
| B2-7 | Wrong city in the home header | ✅ Done — falls back to the nearest turf's district |

---

## 4. Other work in the same release

**Crashes fixed**
- `/login`, `/register`, `/forgot-password` were used in 18 places but never registered — any session-expiry or logout hit a dead route. Registered, plus an unknown-route fallback.
- Notification taps pointed at routes that do not exist (`/my-bookings`, `/wallet`, `/coins`).
- `Expanded` inside `Obx` on the home category bar (ParentDataWidget error).
- Two Firebase background handlers — the second silently replaced the first.
- 401 handled once instead of one redirect per failed request.

**Duplicate / unnecessary API calls**
- New `ApiDedupeInterceptor`: identical GETs already in flight are merged (POSTs are never merged).
- Home turfs: 3–5 calls at start-up → **1**. Location refetch only after moving 1 km. Google Geocoding skipped for the same spot.
- Profile / bookings: single-flight, so a second caller waits for fresh data instead of reading stale values.
- Bookings API no longer fires on every rebuild while Home is visible.
- Login no longer waits for turfs or device registration.

**UI / RenderFlex**
- Turf card no longer overflows on 320 px phones.
- Category collapse animation clipped.
- Home header chips scale down instead of overflowing.

**Referral links**
- Play Store links used `com.book_your_turf.app`; the real id is `com.bookyourturf.app`.
- App link was `book_your_turf://`; the manifest registers `bookyourturf://refer/...`.

**OTP auto-read**
- SMS Retriever with app signature. Play Store hash: `1GFzLwKhC5/`, debug hash: `KvA9lEjbX0Q`.
- Backend must append the `app_hash` sent with send-otp to the end of the SMS (see `tools/BACKEND_OTP_SMS_APP_HASH.md`).

---

## 5. How to verify after release

1. **Test Events:** Events Manager → BYT dataset → Test Events. On a fresh install go through: new number login → home → search → turf → slot tap → summary → pay. Every event above must appear in order.
2. **After 3–4 days:** the Overview funnel should read Install → Complete Registration → View Content → Add to Cart → Initiate Checkout → Purchase with counts at each step.
3. **Ads Manager columns:** Registrations completed, Content views, Adds to cart, Checkouts initiated, Purchases.
4. **Duplicate calls:** run the app with the debug console open — the turfs API should be called once at start-up; merged duplicates print `🔁 duplicate GET merged`.
5. **Razorpay dashboard:** compare orders created / attempted / failed / successful against the Initiate Checkout count to confirm where the drop now is.
