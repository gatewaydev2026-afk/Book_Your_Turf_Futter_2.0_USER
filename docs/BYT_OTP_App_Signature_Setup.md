# Book Your Turf — OTP Auto-Read (App Signature) Setup

**Who does what: Flutter (app) · Backend (Django) · DLT / SMS provider**
User app · September 2026

---

## What we are building

Today the user reads the OTP from the SMS and types it, or taps "Allow" on a popup.
With the SMS Retriever API, Android hands the OTP SMS **directly to our app** — no
permission, no popup — and the app fills the OTP and verifies it by itself.

For this to work, one thing must be true:

> **The OTP SMS must end with our app's 11-character signature hash.**

That's the whole trick. Android checks the hash at the end of the SMS, finds the app
it belongs to, and gives the message only to that app.

### The hashes for BookYourTurf (`com.bookyourturf.app`)

| Build | Signed with | App hash |
|---|---|---|
| **Play Store / internal testing** | Google Play App Signing key (`F7:F9:1E:A8…`) | **`1GFzLwKhC5/`** |
| Debug (`flutter run`) | `android/debug.keystore` | `KvA9lEjbX0Q` |
| Upload key (AAB signing only) | `android/app/BookYourTurf.jks` (`8D:E7:F4:44…`) | `u+sghRhXgBb` — **never use in SMS** |

To recompute at any time:
```bash
./tools/sms_app_hash.sh deployment_cert.der            # Play Console → App integrity → App signing → Download certificates
./tools/sms_app_hash.sh --keystore android/debug.keystore androiddebugkey android
```

### Final SMS format

```
Your BookYourTurf OTP is 123456. Valid for 5 minutes. Do not share it.
1GFzLwKhC5/
```

Rules: OTP inside the text · hash on the **last line** · nothing after the hash ·
whole SMS ≤ 140 bytes.

---

## Part 1 — Flutter (app) · ✅ ALREADY DONE

No further app work is needed. This is what the app now does, for reference.

| File | What it does |
|---|---|
| `lib/services/otp_autofill_service.dart` (new) | Reads the app's own signature hash, starts the SMS Retriever **before** send-otp is called, waits for the SMS, extracts the 6-digit OTP, stops cleanly |
| `lib/view_models/auth_view_model.dart` | Starts the listener and sends `app_hash` with send-otp / resend |
| `lib/views/phone_otp_verification_view.dart` | OTP fills and verifies automatically; falls back to the old "Allow" popup if no hash |
| `lib/views/demoview/GuestOrLoginView.dart` | Loads the hash early so "Send OTP" is not delayed |
| `lib/config/app_config.dart` | `useSmsRetriever = true` — set to `false` to return to the old popup behaviour |

Two things worth knowing:

- **The app reads its own hash at runtime**, so debug and Play Store builds each use
  the correct one. Nothing is hard-coded in the app.
- The app sends that hash to the backend as `app_hash`. The backend *may* use it —
  see Part 2 — but if the hash is already inside the DLT template, the backend can
  ignore the field. The app works either way.

Everything here is wrapped in try/catch: if the hash cannot be read, or Play Services
is missing, the user simply types the OTP. OTP reading can never crash the app.

---

## Part 2 — Backend (Django) · ⚠️ DEPENDS ON YOUR SMS SETUP

First find out **how your backend talks to the SMS provider**. Open the code that
sends the OTP SMS and look at the request:

### Case A — backend sends the full message text
```python
requests.post(url, data={"message": f"Your BookYourTurf OTP is {otp}...", ...})
```
Here the SMS contains exactly what the backend sends, so **the backend must append
the hash**. Adding it only to the DLT template changes nothing.

```python
import re

HASH_RE = re.compile(r'^[A-Za-z0-9+/]{11}$')

# send-otp view
app_hash = (request.data.get('app_hash') or '').strip()

msg = f"Your BookYourTurf OTP is {otp}. Valid for 5 minutes. Do not share it."
if HASH_RE.match(app_hash):          # app sends the right hash for its own build
    msg = f"{msg}\n{app_hash}"

send_sms(number, msg)
```

Using the `app_hash` from the request (instead of a hard-coded string) means debug
builds and Play Store builds both auto-fill. The regex check keeps junk out of the SMS.

> The `app_hash` field is optional — iOS and older app versions don't send it.
> Never fail the request when it is missing.

### Case B — backend sends template id + variables
```python
requests.post(url, data={"template_id": "16071...", "var1": otp, ...})
```
Here the provider builds the text from the approved template, so the hash must live
**inside the template** (Part 3). The backend needs **no change** — but then only the
build whose hash is in the template (the Play Store build) will auto-fill.

If your provider allows an extra variable at the end of the template, the best of both:
pass `app_hash` as that variable and every build works.

### Backend checklist
- [ ] Accept `app_hash` in `POST /api/user/phone/send-otp/` (optional field)
- [ ] Validate it: `^[A-Za-z0-9+/]{11}$`, otherwise ignore it
- [ ] Case A: append it as the last line of the SMS
- [ ] Keep the total SMS under 140 bytes
- [ ] Don't strip or escape `/` and `+` anywhere in the pipeline
- [ ] Log the exact final SMS string once, so you can confirm what left the server

---

## Part 3 — DLT / SMS provider

Indian operators only deliver SMS whose text matches an approved DLT template, so the
hash has to be part of that template.

### Option 1 (recommended) — hash as a variable
```
Your BookYourTurf OTP is {#var#}. Valid for 5 minutes. Do not share it. {#var#}
```
- Works for debug **and** Play Store builds (the app sends its own hash).
- Some operators limit the number of variables or reject a variable at the very end —
  check with your provider before submitting.

### Option 2 — hash as fixed text
```
Your BookYourTurf OTP is {#var#}. Valid for 5 minutes. Do not share it. 1GFzLwKhC5/
```
- Use the **Play Store hash `1GFzLwKhC5/`** only.
- Debug builds will not auto-fill — that is expected, not a bug.
- If the app is ever re-signed with a new key (Play "Upgrade key"), the template must
  be re-approved with the new hash.

### DLT checklist
- [ ] Register/update the template on the DLT portal under your header (sender id)
- [ ] Hash is the **last thing** in the template — no full stop, no "Team BYT" after it
- [ ] `/` and `+` kept exactly as they are
- [ ] Template approved and mapped to the sender id on the provider dashboard
- [ ] Provider's template id updated in the backend if it changed
- [ ] Approval usually takes a few hours to 2 days — plan for it

---

## Testing

1. **Play Store / internal testing build** (debug build only works with Option 1).
2. Enter the mobile number → tap Send OTP.
3. Look at the SMS in the Messages app. The last line must read exactly `1GFzLwKhC5/`
   (or the debug hash for a debug build).
4. Expected behaviour: no "Allow" popup, OTP fills by itself, the app verifies and
   opens Home within a second or two.
5. Also test: no internet, wrong OTP, resend OTP, "Change number" — all should still work.

### If it does not auto-fill

| Symptom | Likely cause |
|---|---|
| SMS has no hash at the end | Case A backend not updated, or the provider is using a template without the hash |
| Hash shows as `%2F` or `1GFzLwKhC5` (10 chars) | The `/` was URL-encoded or trimmed somewhere in the pipeline |
| Works on debug, not on Play Store | Template has the debug hash — use `1GFzLwKhC5/` |
| Nothing happens on any build | Google Play Services missing/old on the phone, or SMS arrived more than 5 minutes after Send OTP |
| "Allow" popup still appears | The app could not read its hash — it fell back to the User Consent flow; check the log line `📩 SMS APP HASH:` |

The OTP screen always allows manual typing, so nothing above blocks a user from logging in.

---

## Who does what — summary

| Work | Owner | Status |
|---|---|---|
| App reads hash, listens for SMS, auto-fills OTP | App | ✅ Done (v5 build) |
| Accept + validate `app_hash`, append to SMS (Case A) | Backend | ⬜ To do |
| Register DLT template with the hash | Marketing / SMS provider | ⬜ To do |
| Verify with a Play Store build | App + Marketing | ⬜ After the above |
