/// The only fields an event may carry. Names, phone numbers, amounts and free text are never allowed.
const allowedEventKeys = {'date', 'count', 'kind', 'status', 'module'};

/// Keeps only allowed fields, drops empty values, and drops long text or long numbers
/// (phone numbers and account numbers are long digit runs).
Map<String, Object> sanitizeEventFields(Map<String, Object?> raw) {
  final out = <String, Object>{};
  for (final entry in raw.entries) {
    if (!allowedEventKeys.contains(entry.key)) continue;
    final value = entry.value;
    if (value == null) continue;
    if (value is String) {
      if (value.length > 40) continue;
      if (RegExp(r'\d{6,}').hasMatch(value)) continue;
      out[entry.key] = value;
    } else if (value is num || value is bool) {
      out[entry.key] = value;
    }
  }
  return out;
}
