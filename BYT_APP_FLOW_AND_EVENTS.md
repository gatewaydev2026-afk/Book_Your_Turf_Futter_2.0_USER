# Book Your Turf — App Flow & Meta Event Map
**User app (Flutter) · September 2026 build**

This document shows every screen of the app, what the user does there, which
Meta (Facebook) event fires, and which API is called. It also lists the
tracking-sheet items (Sep 2026) and whether they are done.

---

## 1. Main funnel — install to booking

```
App open            → fb_mobile_activate_app  (+ App Install, automatic)
   ↓
Home                → home_view                       (10-min throttle)
   ↓ search
Search a place      → fb_mobile_search
   ↓ tap a turf
Turf details        → fb_mobile_content_view  (View Content)
   ↓ Book Now
Slot screen         → slot_view
   ↓ tap a slot
Slot selected       → fb_mobile_add_to_cart   (Add to Cart)
   ↓ Proceed
Booking Summary     → fb_mobile_initiated_checkout  (Initiate Checkout)
   ↓ Pay
Pay tapped          → payment_initiated       (payment_method = online | wallet)
   ↓
Success             → fb_mobile_purchase  (Purchase)
                      + online_booking_success / wallet_booking_success
Failure / cancel    → payment_failed          (with reason)
```

Login can happen at any point (guest can browse; booking needs login):

```
Send OTP            → otp_requested            (user_type = new_user | existing_user)
OTP verified — new  → fb_mobile_complete_registration + new_user_signup
OTP verified — old  → existing_user_login
Both                → fb_mobile_login          (+ user_type)
```

`new / existing` comes from the send-otp response field **`is_registered`**
(`true` = old user, `false` = new user).

---

## 2. Screen by screen

### 2.1 Splash → Home
| What happens | Event | API |
|---|---|---|
| App opens | `fb_mobile_activate_app` (not awaited — never delays start-up) | — |
| Home list loads | `home_view` (params: user_type, location_label, visit_count) | `turfs` list — **one** call per start-up |
| Pull to refresh | — | turfs list (user-initiated) |
| Scroll to bottom | — | next page — **appends**, nothing on screen disappears |
| Search a place | `fb_mobile_search` (fb_search_string, result_count) | turfs list with `search` |
| Category chip | — | no API (local filter) |
| Heart icon | `fb_mobile_add_to_wishlist` / `favorite_removed` | toggle-favourite |

`home_view` is throttled to 10 minutes so tab switches / app resumes are not
counted as new visits. Location is only re-fetched when the user moves > 1 km.

### 2.2 Turf details
| What happens | Event | Params |
|---|---|---|
| Screen opens | `fb_mobile_content_view` | content_type=turf, content_id=turf_id, content_name, content_category=sport, city, state, currency=INR, visit_count |
| Book Now | — | goes to slot screen |
| Call button | — | phone dialer |

### 2.3 Slot selection
| What happens | Event | Params |
|---|---|---|
| Screen opens | `slot_view` | turf_id, city, sport, visit_count |
| Slot tapped (turns green) | `fb_mobile_add_to_cart` | content_type=turf_slot, turf_id, turf_name, sport, city, slot_time, slot_date, court_number, num_items, payment_type (advance/full), value = slot price, currency=INR |
| Slot un-tapped | no event | — |
| Date / court change | — | slots API for that date |

### 2.4 Booking Summary
| What happens | Event | Notes |
|---|---|---|
| Screen opens | `fb_mobile_initiated_checkout` | content_type=turf_booking_summary, turf_id, turf_name, sport, num_items, booking_type, value = total, visit_count |
| Offer applied | `discount_applied` (`auto_applied` = 1 when auto) | best offer is applied automatically |
| "Pay ₹X with UPI" | `payment_initiated` (payment_method=online) | Razorpay opens **directly** — no profile popup, no confirm popup |
| "Pay from BYT Wallet" | `payment_initiated` (payment_method=wallet) | button only visible when balance > 0 |
| Wallet balance too low | `payment_failed` (reason=wallet_insufficient) | — |
| Razorpay fail / cancel | `payment_failed` (reason, error_code) | user_cancelled, network_error, … |
| Payment success (online) | `fb_mobile_purchase` + `online_booking_success` | — |
| Payment success (wallet) | `fb_mobile_purchase` + `wallet_booking_success` | — |
| Paid but confirm API failed | `booking_confirm_failed` | watch this number |

Purchase / booking-success params include `booking_count`,
`wallet_booking_count`, `online_booking_count`, `is_first_booking`,
`amount_paid`, `total_amount`, `discount_amount`.
Purchase is logged **once per payment** (dedupe by payment id / order id).

### 2.5 Bookings tab
| What happens | Event | Notes |
|---|---|---|
| Tab opened | `booking_history_view` | total / upcoming / cancelled / pending_payment counts |
| Pay balance (online) | `balance_payment_success` / `balance_payment_failed` | payment_method=online |
| Pay balance (wallet) | `balance_payment_success` / `balance_payment_failed` | payment_method=wallet |
| Cancel booking | `booking_cancelled` | refund_amount, cancel_count |

### 2.6 Dashboard / wallet / coins / notifications
| Screen | Event |
|---|---|
| Dashboard (profile tab) | `dashboard_view` |
| Wallet history | `wallet_history_view` |
| Coin history | `coin_history_view` |
| Notifications | `notifications_view` |
| Wallet recharge | `wallet_recharge_initiated` → `_success` / `_failed` |
| Refer & share | `app_shared` |

Screen events are throttled to 30 seconds so rebuilds are not counted twice.

---

## 3. Login / OTP flow

```
Phone number screen
   ↓ Send OTP
   app reads its SMS app-signature hash  →  sent as `app_hash`
   SMS Retriever starts BEFORE the SMS is sent
   ↓ otp_requested
SMS arrives with the hash on the last line
   ↓ OTP fills by itself, verifies automatically (no "Allow" popup)
   ↓ fb_mobile_complete_registration + new_user_signup   (new number)
     existing_user_login                                 (old number)
     fb_mobile_login                                     (both)
Home
```

If the backend does not add the hash, the screen falls back to the old SMS
User-Consent popup, and the user can always type the OTP by hand.
Play Store app hash: **`1GFzLwKhC5/`** (debug build: `KvA9lEjbX0Q`).
Backend steps: `tools/BACKEND_OTP_SMS_APP_HASH.md`.

---

## 4. API call optimisation (what was reduced)

| Before | Now |
|---|---|
| Turfs list called 3–5 times on start-up | **1** call (single-flight + 10-second same-request window) |
| Every GPS refresh called the turfs API | Only when the user moved **> 1 km** |
| Google Geocoding called on every location refresh (paid API) | Skipped when within 500 m of the last lookup |
| Bookings API called on every rebuild, even on Home | Only when the Bookings tab is opened |
| Parallel identical GET requests | Merged by `ApiDedupeInterceptor` (POST never merged) |
| Profile fetch during another fetch returned stale data | Waits for the running fetch; forced refresh always gets fresh data |
| Location permission asked twice at start-up | Once |
| Login waited for turfs + device registration (~17 s) | Both run in the background |
| 401 on several requests → several redirects + snackbars | Handled once |

Load-more now **appends** results, so cards already on screen never disappear —
in search mode the old code replaced the list with only the new page.

---

## 5. Tracking sheet (Sep 2026) — status

**Part A — tracking**

| Item | Status |
|---|---|
| A2 #1 Complete Registration on first phone login | ✅ Done (uses send-otp `is_registered`) |
| A2 #2 View Content on turf page | ✅ Done (`fb_mobile_content_view`) |
| A2 #3 Add to Cart on slot tap | ✅ Done |
| A2 #4 Initiate Checkout on Booking Summary | ✅ Done (renamed from view_content) |
| A3 payment_initiated / payment_failed | ✅ Done (incl. wallet-insufficient) |
| A3 profile_popup_shown | ➖ Not needed — that popup was removed |
| A4 Server-side Purchase (Conversions API) | ❌ Backend work, not done |
| A5 Verification in Test Events | Your step after release |

**Part B — app**

| Item | Status |
|---|---|
| B2 #1 Remove profile popup from payment path | ✅ Done |
| B2 #2 Hide wallet button at ₹0, UPI primary | ✅ Done |
| B2 #3 Remove confirm popup | ✅ Done |
| B2 #4 Show fee on summary / "no extra charge on UPI" | ✅ Done |
| B2 #5 Auto-apply first-booking discount | ✅ Done in app — the ₹100 offer must be created in admin |
| B2 #6 Extend Razorpay timeout | ⚠️ Left at 120 s — the backend slot lock is also 120 s; raising only the app side can cause double booking |
| B2 #7 Home header location label | ✅ Done |

**Event name note:** the sheet writes `fb_mobile_view_content`. The Meta SDK's
real name for View Content is **`fb_mobile_content_view`** — that is what the
app sends, and Events Manager shows it as "View Content".

---

## 6. Test checklist after release

1. Events Manager → BYT dataset → **Test events**, fresh install:
   new number login → turf page → slot tap → summary → pay.
   Expect: Complete Registration → View Content → Add to Cart →
   Initiate Checkout → payment_initiated → Purchase.
2. Wallet booking and UPI booking — check `wallet_booking_success` and
   `online_booking_success` counts.
3. Bookings tab → `booking_history_view`; cancel one → `booking_cancelled`.
4. Console: turfs API should appear **once** at start-up;
   `🔁 duplicate GET merged` shows the interceptor working.
5. Search a place, scroll, load more — earlier cards must stay.
6. Small phone (320–360 px) — no yellow/black overflow stripes.
