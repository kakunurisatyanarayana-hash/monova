import 'package:flutter/foundation.dart';

/// Goes up by one every time something is saved on this device.
/// The shell rebuilds the open page when it changes, so lists, totals and dashboards show the new data at once.
final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

void markDataChanged() => dataRevision.value++;
