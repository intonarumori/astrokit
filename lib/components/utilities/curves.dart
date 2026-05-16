import 'dart:math';

import 'package:flutter/material.dart';

/// Custom spring curve with slight overshoot, similar to iOS's default animation curve
class SpringCurve extends Curve {
  const SpringCurve();

  @override
  double transformInternal(double t) {
    // Damped spring with slight overshoot
    return 1 - pow(e, -6 * t) * cos(1.8 * pi * t);
  }
}
