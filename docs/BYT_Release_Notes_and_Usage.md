# Book Your Turf — User App
## Running the app, how it works, and what changed (Sep 2026 update)

Prepared for the BYT development and marketing team.
Covers everything between the version you sent (baseline) and the current build (v12).

---

# Part 1 — Running the app

## 1.1 What you need
| Item | Value |
|---|---|
| Flutter | 3.38.0 (the version this build was compiled with) |
| Package id | `com.bookyourturf.app` |
| Backend | `https://backend.arcmedialabs.in` (set in `lib/config/app_config.dart`) |
| Release keystore | `android/app/BookYourTurf.jks` + `android/key.properties` |
| Play App Signing | On — Google re-signs the upload |

## 1.2 Build commands
```bash
flutter pub get
flutter analyze          # should finish with no errors
flutter run              # debug build on a connected phone
flutter build apk        # release APK
flutter build appbundle  # AAB for the Play Store
```

If Gradle warns that `jni requires Android NDK 28.2.13676358`: install that NDK in
Android Studio → SDK Manager, then set `ndkVersion = "28.2.13676358"` in
`android/app/build.gradle`. The warning does not block the build.

## 1.3 Start-up sequence (what happens when the app opens)
1. Firebase, Meta SDK, SharedPreferences and the API client (Dio) start up.
   The Meta launch event is not awaited, so a slow SDK cannot delay the app.
2. Splash checks the saved token: token present → Main page, otherwise → Login.
3. Home shows cached turfs immediately, asks for location once, then makes
   **one** turfs API call.
4. Profile, bookings, wallet and coins load only when their tab is opened.

## 1.4 Reading the debug console
| Log line | Meaning |
|---|---|
| `🏟️ FETCH TURFS API CALL #1` | Turfs list call (should be 1 at start-up) |
| `✅ Home data still fresh (…s old) - no API call` | A duplicate call was avoided |
| `🔁 duplicate GET merged` | Two identical requests were merged into one |
| `📊 [META] <event> → {…}` | An event was sent to Meta |
| `❌ SERVER SAID: {…}` | The backend's own error message (use this to debug 400s) |
| `📩 SMS APP HASH: …` | This build's SMS Retriever hash |

---

# Part 2 — How a user uses the app

### 2.1 Login
Enter mobile number → OTP SMS arrives → **OTP fills in by itself** and the app
verifies and opens Home. No "Allow" popup, no permission.
(This needs the backend to add the app hash to the SMS — see Part 4.)
First-time numbers and returning numbers are both handled by the same screen.

### 2.2 Home
Search bar, category chips (All / Cricket & Football / Badminton / Pickleball),
and a 2-column turf grid sorted by distance.
- Scroll to the bottom → the next page is **added below**; cards already on screen stay.
- Pull down → refresh.
- Heart icon → add to favourites.
- Guests can browse. Tapping Bookings or Dashboard asks them to log in first.

### 2.3 Turf details → Slots
Photos, address, amenities, price, "Book Now" → slot screen with date strip,
court selector, Advance / Full payment toggle and the slot grid.
Tap slots (they turn green) → "Proceed to Pay".

### 2.4 Booking summary and payment
Turf card, slot list, offers, fees and total. Then:
1. Tap the green **"Pay ₹X with UPI"** button.
2. Razorpay opens straight away.
3. Pay → success screen → booking appears in the Bookings tab.

The best available offer is applied automatically. Wallet appears as a second
option only when the balance is above ₹0.

### 2.5 Bookings tab
Upcoming and past bookings, balance payment (wallet or UPI) and cancellation
(refund goes to the BYT wallet).

### 2.6 Dashboard tab
Profile, wallet, coins, notifications, referral share and support.

---

# Part 3 — What changed (before → now)

## 3.1 Payment flow — the biggest change
| Before | Now |
|---|---|
| Tap Pay → "Complete your profile" popup asking name + email | Popup removed — nothing is asked before paying |
| → "Confirm online payment" popup | Removed — Razorpay opens on the first tap |
| "Pay via Wallet" was the first green button even at ₹0 balance | UPI is the primary button; wallet only shows when the balance is above ₹0 |
| Razorpay showed a fee that was never on the summary | Fees are shown on the summary ("No extra charge on UPI") |
| "No discounts available" for first-time users | The best eligible offer is applied automatically |
| 5 steps after tapping Pay | 1 step |

## 3.2 Meta tracking — full funnel
| Before | Now |
|---|---|
| 4 events; registration event dead since phone login | Full funnel, all live |
| View Content fired on the summary page | Fires on the turf page, where Meta expects it |
| No event for turf view, slot tap or payment start | All present |
| No new-vs-returning user split | `is_registered` from send-otp drives it |

Funnel now: `app open → otp_requested → complete_registration / existing_user_login
→ home_view → fb_mobile_search → fb_mobile_content_view → slot_view →
fb_mobile_add_to_cart → fb_mobile_initiated_checkout → payment_initiated →
fb_mobile_purchase + wallet/online_booking_success`

Also tracked: booking history views, balance payments, cancellations, wallet
recharges, favourites, dashboard/wallet/coin/notification screens, referral shares,
`payment_failed` with the reason, and `booking_confirm_failed`.
The booking summary event carries the user's overall booking count and
`customer_type` (first_time / repeat) — for Meta only, never shown in the app.

## 3.3 Crashes fixed
| Before | Now |
|---|---|
| `/login`, `/register`, `/forgot-password` used in 18 places but never registered — session expiry and logout hit a dead route | Registered, plus a safe fallback for any unknown route |
| Notification taps pointed at routes that don't exist | Open the real Bookings / Wallet / Coins screens |
| `Expanded` inside `Obx` on the home category bar | Fixed |
| Two Firebase background handlers — the second silently replaced the first | One handler; remote logout handled there |
| One 401 produced several login redirects and snackbars | Handled once; guests are never redirected |
| A bad record from the server emptied the whole bookings list | Bad records are skipped, the rest still show |

## 3.4 Duplicate and wasted API calls
| Before | Now |
|---|---|
| 3–5 turfs calls at start-up | 1 |
| Bookings API fired on every rebuild while Home was visible | Only when the Bookings tab is opened |
| Parallel identical GETs each hit the server | Merged automatically (`ApiDedupeInterceptor`) |
| A second caller got stale data instead of waiting | Waits for the running request (profile, bookings, turfs) |
| Google Geocoding called on every location refresh | Skipped when the user hasn't moved |
| Login waited for turfs + device registration (up to ~17 s) | Both run in the background; Home opens immediately |
| Every push notification re-fetched the whole notification list | No call — the push already carries the notification |
| Booking confirm was sent twice | Once per Razorpay order, enforced by a guard |

## 3.5 UI and performance
| Before | Now |
|---|---|
| Search results above disappeared when loading more | Load-more appends; nothing above is lost |
| Pull-to-refresh on Home did nothing | Works |
| Turf card overflowed on 320 px phones (RenderFlex) | Image flexes to the cell |
| Category bar overflowed during its animation | Clipped properly |
| Home header chips overflowed on narrow screens | Scale down |
| ~2,500 log lines per launch (also in release builds) | Debug builds only — fewer skipped frames |
| Home header showed the wrong city | Falls back to the nearest turf's district |

## 3.6 OTP and referral
| Before | Now |
|---|---|
| "Allow" popup to read the OTP SMS | SMS Retriever with the app signature — fills silently |
| Play Store links used `com.book_your_turf.app` (wrong id → "app not found") | `com.bookyourturf.app` |
| Referral link used `book_your_turf://`, manifest registers `bookyourturf://` | Both fixed, parser handles the real format |

---

# Part 4 — What is still pending (not app work)

| # | Item | Owner |
|---|---|---|
| 1 | OTP SMS must end with the app hash `1GFzLwKhC5/` (Play Store build). See `tools/BACKEND_OTP_SMS_APP_HASH.md` and the DLT template guide. | Backend + SMS provider |
| 2 | `POST /api/user/bookings/confirm/` and `/confirm-balance/` return **400** even though the booking gets created. Send us the `❌ SERVER SAID:` message from the log. | Backend |
| 3 | The ₹100 first-booking offer must be created in the admin panel — the app applies it automatically once it exists. | Admin |
| 4 | Server-side Purchase via Conversions API (so purchases are not lost if the app closes). | Backend, later |
| 5 | Razorpay checkout timeout is still 120 s because the backend slot lock is also 120 s. Raising only the app side risks double bookings. | Backend, if needed |

---

# Part 5 — Test checklist before release

**Login**
- [ ] New number → OTP fills by itself → Home opens
- [ ] Old number → same, and `existing_user_login` appears in Test Events
- [ ] Resend OTP and "Change number" still work

**Home**
- [ ] One `FETCH TURFS API CALL` at start-up
- [ ] Search, scroll to bottom — results above stay in place
- [ ] Pull-to-refresh works
- [ ] Location permission denied → turfs still load
- [ ] 320 px phone → no yellow/black overflow stripes

**Booking**
- [ ] Slot tap → `fb_mobile_add_to_cart` in Test Events
- [ ] Summary → one tap on Pay opens Razorpay (no popups)
- [ ] Wallet button hidden at ₹0 balance
- [ ] Payment success → booking in the Bookings tab, `fb_mobile_purchase` fired
- [ ] Cancel a booking → refund in wallet, `booking_cancelled` fired

**Other**
- [ ] Session expiry / logout → login screen, no crash
- [ ] Notification tap → correct screen opens
- [ ] Referral share → Play Store link opens the right app
