/// Compass heading for Android from the rotation-vector sensors, with pitch,
/// roll, calibration accuracy, angle smoothing and optional true north.
library;

export 'src/angles.dart'
    show AngleLowPassFilter, normalizeDegrees, signedAngleDifference;
export 'src/capabilities.dart' show HeadingCapabilities;
export 'src/heading_event.dart'
    show HeadingAccuracy, HeadingEvent, HeadingSource;
export 'src/heading_sensor.dart'
    show DeclinationProvider, HeadingSensor, HeadingSensorException;
export 'src/options.dart' show HeadingSmoothing, SensorRate, SmoothingLocation;
