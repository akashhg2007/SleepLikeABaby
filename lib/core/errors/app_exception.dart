/// Strongly typed application exceptions.
sealed class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic cause;

  const AppException(this.message, {this.code, this.cause});

  @override
  String toString() =>
      '$runtimeType: $message${code != null ? ' (code: $code)' : ''}';
}

class LocationPermissionDeniedException extends AppException {
  final bool isPermanentlyDenied;
  const LocationPermissionDeniedException(
    super.message, {
    this.isPermanentlyDenied = false,
    super.code = 'PERMISSION_DENIED',
    super.cause,
  });
}

class LocationServicesDisabledException extends AppException {
  const LocationServicesDisabledException(
    super.message, {
    super.code = 'SERVICES_DISABLED',
    super.cause,
  });
}

class GpsAccuracyPoorException extends AppException {
  final double currentAccuracy;
  final double threshold;
  const GpsAccuracyPoorException(
    super.message, {
    required this.currentAccuracy,
    required this.threshold,
    super.code = 'ACCURACY_POOR',
  });
}

class GpsSignalLostException extends AppException {
  final Duration elapsedSinceLastFix;
  const GpsSignalLostException(
    super.message, {
    required this.elapsedSinceLastFix,
    super.code = 'SIGNAL_LOST',
  });
}

class PlatformBridgeException extends AppException {
  const PlatformBridgeException(
    super.message, {
    super.code = 'PLATFORM_BRIDGE_ERROR',
    super.cause,
  });
}

class StorageException extends AppException {
  const StorageException(
    super.message, {
    super.code = 'STORAGE_ERROR',
    super.cause,
  });
}

class NetworkGeocodingException extends AppException {
  const NetworkGeocodingException(
    super.message, {
    super.code = 'GEOCODING_ERROR',
    super.cause,
  });
}
