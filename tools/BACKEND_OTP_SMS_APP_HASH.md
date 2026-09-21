# Backend change – OTP SMS auto-read (app signature hash)

The app now sends an extra field to **POST /api/user/phone/send-otp/**:

```json
{ "number": "8148063180", "referral_code": "ABC", "app_hash": "FA+9qCX9VSu" }
```

`app_hash` is optional (iOS / old app versions don't send it).

## What the backend must do
1. Accept `app_hash` (optional). Validate: `^[A-Za-z0-9+/]{11}$` – ignore anything else.
2. Put it as the **last line** of the OTP SMS:

```
Your BookYourTurf OTP is 123456. Valid for 5 minutes. Do not share it.
FA+9qCX9VSu
```

Rules (Google SMS Retriever):
- whole SMS ≤ 140 bytes
- contains the 6-digit OTP
- ends with the 11-character hash
- (`<#>` at the start is no longer required)

### Django example
```python
import re
HASH_RE = re.compile(r'^[A-Za-z0-9+/]{11}$')

app_hash = (request.data.get('app_hash') or '').strip()
msg = f"Your BookYourTurf OTP is {otp}. Valid for 5 minutes. Do not share it."
if HASH_RE.match(app_hash):
    msg = f"{msg}\n{app_hash}"
send_sms(number, msg)
```

## ⚠️ DLT (India)
The SMS text must match the approved DLT template. Add a variable at the end,
e.g. `Your BookYourTurf OTP is {#var#}. Valid for 5 minutes. Do not share it. {#var#}`
and get it approved, otherwise the operator will block the SMS.
Without the hash the app still works – the user just types the OTP (or taps "Allow").

## Hashes
- Debug build and Play Store build have **different** hashes – the app always
  sends the correct one for itself.
- To see the Play Store hash: install from Play Store / internal testing and read
  the log line `📩 SMS APP HASH: ...`, or run `tools/sms_app_hash.sh deployment_cert.der`.
