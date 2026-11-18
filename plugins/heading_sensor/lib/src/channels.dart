import 'package:flutter/services.dart';

/// Event channel carrying heading samples from Kotlin.
const headingEventChannel =
    EventChannel('dev.abdeldjalilchougui.heading_sensor/events');

/// Method channel for one-off queries such as capabilities.
const headingMethodChannel =
    MethodChannel('dev.abdeldjalilchougui.heading_sensor/methods');
