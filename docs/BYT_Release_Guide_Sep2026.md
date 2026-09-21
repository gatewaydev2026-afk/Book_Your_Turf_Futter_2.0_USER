# Book Your Turf — User App
## Release guide: what it was, what it is now, and how to run it
September 2026 · covers builds v1 → v12 of this work

---

# 1. How to run the app

## Requirements
- Flutter 3.38 (the version used for these builds)
- Android Studio + Android SDK, with **NDK 28.2.13676358** if you switch to it (see note below)
- The keystore files that ship with the project: `android/app/BookYourTurf.jks`, `android/key.properties`
  (never share these — they sign your Play Store releases)

## Commands
```bash
flutter pub get          # download packages
flutter analyze          # check for code errors before building
flutter run              # debug build on a connected phone
flutter build apk        # release APK
flutter build appbundle  # AAB for the Play Store
```

Build output:
- APK → `build/app/outputs/flutter-apk/app-release.apk`
- AAB → `build/app/outputs/bundle/release/app-release.aab`

## Known build warning
```
jni requires Android NDK 28.2.13676358
```
The build still succeeds. To silence it, install that NDK from Android Studio →
SDK Manager → SDK Tools → NDK, then add to `android/app/build.gradle`:
```gradle
android {
    ndkVersion = "28.2.13676358"
}
```
Don't add the line before installing the NDK, or the build will fail.

## Where things live
```
lib/
  main.dart               app start-up, Dio setup, routes
  config/app_config.dart  API base URL, all endpoints, feature flags
  models/                 data classes (turf, slot, booking…)
  views/                  screens
  view_models/            screen logic (GetX)
  services/               API helpers, notifications, Meta events, OTP autofill
  widgets/                reusable UI pieces
docs/                     this guide + the flow & event documents
tools/                    SMS app-hash script, backend instructions
```

---

# 2. How the app runs (flow)

```
App open
  └─ Firebase, storage, Dio, view-models start
  └─ Token present?  yes → Main page      no → Login screen

Login
  └─ enter mobile number → send-otp (app_hash sent along)
  └─ SMS arrives → OTP fills itself → verify → Main page

Main page (4 tabs)
  Home        turf list, search, categories, favourites
  Bookings    upcoming/past bookings, pay balance, cancel
  Dashboard   profile, wallet, coins, referral, settings
  (tab data loads once per tab switch)

Booking
  Home → Turf details → Slot screen (date, court, advance/full, slots)
       → Booking summary (offers, fees, total)
       → Pay with UPI  (or wallet, when balance > 0)
       → Razorpay → booking confirmed
```

Every step also sends a Meta event — the full list is in
`docs/BYT_App_Flow_and_Meta_Events.md`.

---

# 3. What changed — before vs now

## 3.1 Meta tracking
| | Before | Now |
|---|---|---|
| Events sent | 4 (app launch, login, view content, purchase) | Full funnel: home, search, turf view, slot screen, add to cart, checkout, payment start/fail, purchase, history, wallet, favourites, referral |
| Registration event | Broken — it belonged to the old email sign-up screen | Fires on the first login of a new number, using `is_registered` from send-otp |
| View Content | Fired on the booking summary (wrong screen) | Fires on the turf details page; the summary now sends Initiate Checkout |
| New vs old users | Not tracked | `customer_type` = first_time / repeat, plus per-user booking counts |
| Wallet vs online bookings | Not separated | `wallet_booking_success` / `online_booking_success` with counts |
| Phone number in events | Sent to Meta | Removed (Meta does not allow personal data) |
| Crash risk | Event code ran inline | Every event is error-wrapped and fire-and-forget — Meta can never crash or slow the app |

## 3.2 Payment flow
| | Before | Now |
|---|---|---|
| After tapping Pay | Profile popup (name + email) → confirm popup → Razorpay | Razorpay opens straight away |
| Wallet button | First, green, even at ₹0 balance | Hidden at ₹0; UPI is the primary green button |
| Fees | A fee appeared only inside Razorpay | Shown on the summary: "No extra charge on UPI" |
| Offers | "No discounts available", user had to tap | Best eligible offer applies automatically |
| Booking confirm | — | One request per order, in the API's documented format; a repeat success callback cannot send it twice |

## 3.3 Home screen
| | Before | Now |
|---|---|---|
| Search + scroll | Loading the next page replaced the list — earlier results vanished | Next page is appended; what is on screen stays |
| Pull to refresh | Did not work (scroll events were swallowed) | Works |
| Location label | Could show a different city than the turfs listed | Falls back to the nearest turf's district |
| No location permission | Home stayed empty | Turfs still load, without distances |

## 3.4 API calls
| | Before | Now |
|---|---|---|
| Turfs at start-up | 3–5 calls | 1 |
| Identical GETs at the same time | Each one hit the server | Merged — the second caller shares the first response |
| Bookings list | Called on every rebuild, even from the Home tab | Only when the Bookings tab opens |
| Profile / bookings | A caller during a running fetch got stale data | Waits for the running fetch; forced refreshes get fresh data |
| Location | Refetched on small GPS jitter; geocoding called every time | Refetch only after 3 km; geocoding skipped for the same spot |
| Notifications | Every push re-fetched the whole list | Push data is used directly; list refreshes when opened |
| Login | Waited for turfs and device registration | Both run in the background — Home opens immediately |

## 3.5 Crashes and UI
| Issue | Status |
|---|---|
| `/login`, `/register`, `/forgot-password` used in 18 places but never registered — session expiry, logout and Login buttons hit a dead route | Registered, plus a safe fallback for unknown routes |
| Notification taps used routes that don't exist | Open the real screens now |
| `Expanded` inside `Obx` on the home category bar | Fixed |
| Two Firebase background handlers (the second replaced the first) | One handler; no duplicate tray notifications |
| One 401 caused several login redirects and snackbars | Handled once |
| Turf cards overflowed on 320 px phones | Fixed (image flexes) |
| Category bar overflowed during its collapse animation | Clipped |
| A bad record from the server emptied the whole bookings list | Bad records are skipped |
| ~2,500 debug log lines per launch (also in release builds) | Debug builds only |

## 3.6 OTP auto-read
| | Before | Now |
|---|---|---|
| Reading the OTP | "Allow" popup, then the user typed it | SMS Retriever with the app signature — OTP fills and verifies by itself |
| Hash | — | Play Store: `1GFzLwKhC5/` · Debug: `KvA9lEjbX0Q` (the app sends its own as `app_hash`) |
| Fallback | — | Old popup if the hash can't be read; manual typing always works |

## 3.7 Referral links
| | Before | Now |
|---|---|---|
| Play Store link | `com.book_your_turf.app` — wrong id, "item not found" | `com.bookyourturf.app` |
| App link | `book_your_turf://` | `bookyourturf://refer/CODE`, matching the manifest |

---

# 4. Still to do (not app-side)

| Item | Owner | Why |
|---|---|---|
| OTP SMS must end with the `app_hash` (or the hash in the DLT template) | Backend + SMS provider | Without it the OTP will not auto-fill. See `tools/BACKEND_OTP_SMS_APP_HASH.md` |
| `/api/user/bookings/confirm/` returns 400 | Backend | Payment succeeds, the confirm call fails. The app now logs `❌ SERVER SAID: …` — send that message |
| Is the booking confirmed by a Razorpay webhook already? | Backend | If yes, the app's confirm call may not be needed at all |
| ₹100 first-booking offer | Admin panel | The app auto-applies whatever offer the API returns |
| Server-side Purchase (Conversions API) | Backend | Recovers purchases lost when the app closes right after payment |
| Razorpay 120 s timeout | Backend | The slot lock is also 120 s — raising only the app side risks double bookings |

---

# 5. Test checklist before a release

1. `flutter analyze` — no errors
2. Fresh install → login with a **new** number → Complete Registration appears in Meta Test Events
3. Home: search a place, scroll down — earlier results must stay; pull to refresh works
4. Turf → slot → summary → pay with UPI: no popups before Razorpay
5. Wallet at ₹0: no wallet button; with balance: wallet shows as the second option
6. Bookings tab: list loads, pay balance works, cancel works
7. Notification tap opens the right screen
8. Small phone (320–360 px): no yellow/black overflow stripes
9. Debug console: turfs API called once at start-up; `🔁 duplicate GET merged` for any repeats
10. Meta Events Manager → Test Events: the whole funnel appears in order

---

# 6. Document index

| File | What's in it |
|---|---|
| `docs/BYT_Release_Guide_Sep2026.md` | This guide |
| `docs/BYT_App_Flow_and_Meta_Events.md` | Screen-by-screen flow with every Meta event and its parameters |
| `docs/BYT_OTP_App_Signature_Setup.md` | OTP auto-read: Flutter / backend / DLT steps |
| `tools/BACKEND_OTP_SMS_APP_HASH.md` | Short backend instruction for the OTP SMS |
| `tools/sms_app_hash.sh` | Computes the app hash from a certificate |
| `CHANGES_SEP2026.md` | Full change list by round, file by file |
