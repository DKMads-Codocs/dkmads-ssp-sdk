# DKMads SSP Flutter example

## Run

```bash
cd sdk/flutter/example
flutter pub get
flutter run
```

## What this example validates

- SDK initialize path
- Consent + user data bridge
- Video lifecycle registration
- Event forwarding from Flutter -> native SDK telemetry
- Callback/event stream in Flutter

## Suggested QA sequence

1. Press **Initialize**
2. Press **Start lifecycle**
3. Press **Emit sample events**
4. Verify event logs in app and server-side telemetry stream
5. Press **Stop lifecycle** and confirm no further callbacks for that ad unit
