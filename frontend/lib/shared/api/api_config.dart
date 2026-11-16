import 'package:flutter/foundation.dart';

/// Base URL for the AgriNexus backend (all modules share one FastAPI server).
///
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
///
/// Defaults assume `uvicorn` is running on your computer at port 8000:
///  - Android emulator reaches your computer via 10.0.2.2 (127.0.0.1 would
///    point at the emulator itself and fail)
///  - Physical Android phone: pass your computer's LAN IP with --dart-define
///  - Desktop / web: localhost works directly
class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}
