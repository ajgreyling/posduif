# Posduif Mobile Container App

Flutter mobile container app with offline-first architecture and Flutter Remote Widgets support.

## Structure

- `lib/core/` - Core functionality (API, database, sync, enrollment)
- `lib/features/` - Feature modules (auth, enrollment, messaging)
- `lib/shared/` - Shared utilities and widgets

## Development

```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Generate code (for drift, json_serializable)
flutter pub run build_runner build

# Run tests
flutter test
```

## Dependencies

All dependencies are FOSS (Free and Open Source Software) with permissive licenses.

