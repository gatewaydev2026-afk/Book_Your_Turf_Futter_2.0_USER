# Book Your Turf – Sep 2026 changes

## Home search / load-more bug
- lib/view_models/home_view_model.dart – load-more now APPENDS (search + nearby), duplicates dropped,
  category filter kept, stale responses ignored, nearby pagination restored after clearing search,
  header location label fallback / sanity check, fb_mobile_search event.
- lib/views/home_view.dart – pull-to-refresh fixed (notifications no longer swallowed),
  scroll position kept, bottom padding for glass nav bar, home_view event.

## Meta events (NEW lib/services/meta_events_service.dart)
| Screen | Event |
|---|---|
| Home | home_view (+visit_count), fb_mobile_search |
| Turf details | fb_mobile_content_view (turf_id, city, sport, visit_count) |
| Slot screen | slot_view (+visit_count), fb_mobile_add_to_cart on slot select |
| Booking summary | fb_mobile_initiated_checkout (was fb_mobile_view_content) |
| Payment | payment_initiated, payment_failed |
| New phone number | fb_mobile_complete_registration |
| Booking success | fb_mobile_purchase (unchanged + fb_currency, fb_content_type) |

Phone number is no longer sent in the login event.

## Payment flow (BYT_Funnel_Leakages_and_Fixes.html)
- Profile popup removed from payment path (booking_summary_view_model.dart)
- Confirm-online-payment popup removed; single green "Pay ₹X with UPI" button
- Wallet button hidden when balance is ₹0
- Fees shown on summary by default ("No extra charge on UPI")
- Best eligible offer auto-applied

## Changed files
lib/services/meta_events_service.dart (new)
lib/view_models/home_view_model.dart
lib/view_models/slot_view_model.dart
lib/view_models/auth_view_model.dart
lib/view_models/booking_summary_view_model.dart
lib/views/home_view.dart
lib/views/turf_details_view.dart
lib/views/slot_view.dart
lib/views/booking_summary_view.dart

---

# Round 2 – duplicate API calls, crashes, RenderFlex (Sep 2026)

## Crashes
- routes/route_generator.dart – `/login`, `/register`, `/forgot-password` registered (were used in 18 places but missing); `unknownRoute` fallback added (main.dart)
- services/notification_service.dart – notification tap used non-existent routes (/my-bookings, /wallet, /coins) → real screens now; safe date parsing; no second tray notification when opened from tray
- views/home_view.dart – `Expanded` inside `Obx` (ParentDataWidget error) fixed
- main.dart – 401 handled once only, never for guest requests; auth token no longer printed in logs
- services/firebase_messaging_service.dart + device_manager.dart – single background handler (the second one overrode the first); remote logout handled there; no duplicate background notifications; one forced-logout dialog only

## Duplicate / unnecessary API calls
- NEW services/api_dedupe_interceptor.dart – identical running GETs are merged (POSTs untouched)
- view_models/home_view_model.dart – single-flight turfs fetch & location lookup; refetch only if moved > 1 km; geocoding skipped for same place; turfs load even without location
- view_models/profile_view_model.dart – single-flight fetchUser (waiters get fresh data); refresh() awaitable, clears profile only
- view_models/booking_view_model.dart – single-flight loadBookings / refreshBookings
- views/booking_history_view.dart – no API call on every rebuild
- views/main_page.dart – tab data loads once per tab change (also from code); guests stay on Home
- services/app_initializer.dart + auth_view_model.dart – login no longer waits for turfs / device registration (runs in background)
- main.dart – location permission asked once (HomeViewModel)

## RenderFlex / UI
- widgets/turf_card.dart – no overflow on small phones (image flexes)
- views/home_view.dart – category collapse animation clipped; header Guest/Login chips scale down

---

# Round 3 – New vs existing user count for Meta (send-otp `is_registered`)

`POST /api/user/phone/send-otp/` → `data.is_registered`
- `true`  = old / existing user
- `false` = new user

| Step | Event | Params |
|---|---|---|
| Send OTP success | `otp_requested` | user_type (new_user / existing_user), is_registered, is_resend |
| Verify OTP – new user | `fb_mobile_complete_registration` + `new_user_signup` | user_type=new_user |
| Verify OTP – old user | `existing_user_login` | user_type=existing_user |
| Verify OTP – both | `fb_mobile_login` | user_type added |

Files: lib/services/meta_events_service.dart, lib/view_models/auth_view_model.dart
(verify's `is_new_user` is used only if the send-otp value is missing)

---

# Round 4 – Wallet / online booking counts, booking history & more → Meta

All events live in `lib/services/meta_events_service.dart`. Every method catches its own
errors and is fired without `await` in payment/UI code → Meta can never crash or slow the app.

| Action | Event(s) | Key params |
|---|---|---|
| Booking success (wallet) | `fb_mobile_purchase` + `wallet_booking_success` | payment_method=wallet, amount_paid, booking_count, wallet_booking_count, online_booking_count, is_first_booking |
| Booking success (online/UPI) | `fb_mobile_purchase` + `online_booking_success` | payment_method=online, fb_order_id, same counts |
| Paid but confirm API failed | `booking_confirm_failed` | reason, order_id |
| Booking history opened | `booking_history_view` | total / upcoming / cancelled / pending_payment bookings, visit_count |
| Balance payment | `balance_payment_success` / `balance_payment_failed` | payment_method wallet/online, amount |
| Cancel booking | `booking_cancelled` | refund_amount, cancel_count |
| Wallet recharge | `wallet_recharge_initiated` / `_success` / `_failed` | amount, recharge_count |
| Favourite | `fb_mobile_add_to_wishlist` / `favorite_removed` | turf_id |
| Dashboard / wallet history / coin history / notifications | `dashboard_view`, `wallet_history_view`, `coin_history_view`, `notifications_view` | visit_count |
| Referral share | `app_shared` | share_type |

Purchase is logged only once per payment (dedupe by payment id / order id).

## Crash-safety in the same flows
- booking_view_model.dart – non-JSON / error responses handled; one bad booking record no longer empties the list; Razorpay amount parsed safely; wallet balance error shows server message (not raw exception)
- wallet_view_model.dart – safe response parsing, double-tap guard, correct Razorpay error codes
- main.dart – `fb_mobile_activate_app` no longer blocks app start

## Referral link fixes
- Play Store links used `com.book_your_turf.app` – real id is `com.bookyourturf.app` (profile, app_config, deep_link_service, support assistant)
- Custom link was `book_your_turf://` but the manifest registers `bookyourturf://refer/...` – link and parser fixed

---

# Round 5 – OTP auto-read with app signature (SMS Retriever API)

- NEW `lib/services/otp_autofill_service.dart` – gets app hash, starts the SMS Retriever
  **before** send-otp, returns the OTP, safe stop/cleanup (never crashes).
- `auth_view_model.dart` – send-otp / resend now send `app_hash`; listener stopped on failure.
- `phone_otp_verification_view.dart` – OTP fills + verifies automatically, no "Allow" popup.
  Falls back to the old User Consent popup only if the hash is not available.
- `GuestOrLoginView.dart` – hash loaded early.
- `app_config.dart` – `useSmsRetriever` flag (false = old popup behaviour).
- `tools/BACKEND_OTP_SMS_APP_HASH.md` – backend + DLT steps; `tools/sms_app_hash.sh` – compute hash.

⚠️ Needs the backend to append `app_hash` to the SMS (see tools/BACKEND_OTP_SMS_APP_HASH.md).

---

# Round 6 – tracking sheet alignment + flow document
- Event params now also carry the sheet's readable names (content_type, content_id,
  content_name, content_category, currency, num_items) beside the standard fb_* ones
- Initiate Checkout content_type = "turf_booking_summary" (as in the sheet)
- payment_method value is now "online" (was "upi_online")
- Wallet balance too low → payment_failed (reason = wallet_insufficient)
- NEW `BYT_APP_FLOW_AND_EVENTS.md` – full screen-by-screen flow, event map,
  API-optimisation list and tracking-sheet status

---

# Round 6 – remove wasted API calls

- booking_summary_view_model.dart – booking confirm is now ONE request, sent as
  multipart/form-data exactly as the API documents it (the JSON attempt + form-data
  retry meant two requests per payment).
- notification_service.dart – an incoming push no longer re-fetches the whole
  notification list from the server. The push already carries the notification and it
  is added to the list locally; the list refreshes when the user opens the
  Notifications screen or pulls to refresh. (Was 1 extra API call per push.)
- main.dart – API errors now log the server's response body (`❌ SERVER SAID: ...`)
  so a 400 can actually be diagnosed.
- booking confirm: one request per Razorpay order id, enforced by a static guard
  (a repeated success callback or a second view-model can no longer send it twice);
  a 400 whose message says the booking is already confirmed is treated as success.
- Booking summary: fb_mobile_initiated_checkout (and payment_initiated) now carry the
  user's overall booking history — user_booking_count / booking_count,
  wallet_booking_count, online_booking_count, is_first_booking, customer_type
  (first_time | repeat). Sent to Meta only; nothing is shown in the app UI.

---

# Round 7 – "Complete Your Profile" restored (on request)

The name/email dialog is back in the payment path (booking_summary_view_model.dart):
- Shown only when the name or email is missing (existing users go straight to payment)
- "Save & Continue" saves the profile and the payment continues automatically
- The rest of the Sep 2026 payment fixes stay: no confirm popup, UPI-first button,
  wallet hidden at ₹0, fees on the summary, auto-applied offer

---

# Round 8 – Confirm after Razorpay webhook (backend already live)

Flow kept exactly: initiate → Razorpay (120 s, aligned with slot hold) → confirm;
later pay-balance → Razorpay → confirm-balance. Webhook stays on, confirm stays as backup.

booking_summary_view_model.dart
- confirm is sent ONCE per Razorpay order, in the original JSON body
  (same razorpay_payment_id, razorpay_order_id, turf, court, date, slots, amounts, discount ids)
  – the multipart experiment is removed.
- 200 + result success = booking OK, whether first-time ({booking_id, id}) or
  "Booking already confirmed" (full booking object).
- 400 "No pending reservation found. It may have expired." / "Invalid booking":
  GET /bookings once; if the booking for these slots exists → success.
- The success screen and post-payment refresh always run (the old early `return`s
  could skip them and leave the UI locked).

booking_view_model.dart (balance)
- confirm-balance sent ONCE per payment id; 200 + result success = OK ({booking_id}).
- 400 "Invalid booking" / "No pending reservation found": reload bookings once and
  accept only if THIS booking's pending balance dropped by the amount just paid
  (Advance Paid is never treated as Fully Paid).
- Real failure after Razorpay took the money shows "Payment received – updating your
  booking", not "Payment failed".
