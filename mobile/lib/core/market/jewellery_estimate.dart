// Full cost of a gold or silver jewellery purchase from a per-gram rate. Pure Dart, no network.
// The rate can be the national benchmark or a jeweller's quote. A shop's own premium and discounts are
// not in the rate unless the quote includes them.

class JewelleryEstimate {
  const JewelleryEstimate({
    required this.baseValue,
    required this.makingCharges,
    required this.gst,
    required this.otherCharges,
    required this.total,
  });

  /// Grams times the rate per gram.
  final double baseValue;

  /// Making charges, as a percentage of the base value.
  final double makingCharges;

  /// GST on base value plus making charges. Gold jewellery is taxed at 3%.
  final double gst;

  /// Hallmarking, stone or wastage charges and similar, added as the shop quotes them.
  final double otherCharges;

  /// The full final cost.
  final double total;
}

/// [perGram] is the rate per gram in rupees. [makingPercent] is the shop's making charge.
JewelleryEstimate estimateJewellery({
  required double perGram,
  required double grams,
  required double makingPercent,
  double gstPercent = 3,
  double otherCharges = 0,
}) {
  final base = perGram * grams;
  final making = base * makingPercent / 100;
  final gst = (base + making) * gstPercent / 100;
  return JewelleryEstimate(
    baseValue: base,
    makingCharges: making,
    gst: gst,
    otherCharges: otherCharges,
    total: base + making + gst + otherCharges,
  );
}
