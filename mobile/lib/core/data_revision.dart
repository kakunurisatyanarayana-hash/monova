import 'dart:async';

import 'package:flutter/foundation.dart';

/// Goes up after saves settle. The open page rebuilds when it changes, so lists, totals and dashboards show the new data.
/// Several saves in a row (for example, a restore or recurring entries) cause one rebuild instead of one each.
final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

Timer? _pending;

void markDataChanged() {
  _pending?.cancel();
  _pending = Timer(const Duration(milliseconds: 250), () {
    dataRevision.value++;
  });
}
