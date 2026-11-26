import 'package:flutter/material.dart';

import '../../core/card_store.dart';

/// Colours for each card network, as a gradient from top-left to bottom-right.
List<Color> networkColors(String network) {
  switch (network) {
    case 'Visa':
      return const [Color(0xFF1A1F71), Color(0xFF2F6FE0)];
    case 'Mastercard':
      return const [Color(0xFF1F2937), Color(0xFFEB5E28)];
    case 'Amex':
      return const [Color(0xFF006FCF), Color(0xFF00A3E0)];
    case 'RuPay':
      return const [Color(0xFF0B6E4F), Color(0xFF00A896)];
    default:
      return const [Color(0xFF334155), Color(0xFF0F172A)];
  }
}

/// A card drawn like a real one: network colours, a chip, the masked number, the name and the valid-thru date.
/// Only the last four digits are ever shown.
class CardVisual extends StatelessWidget {
  const CardVisual({super.key, required this.card, this.height = 190});

  final CardRecord card;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = networkColors(card.network);
    final small = height < 170;
    final numberSize = small ? 16.0 : 20.0;
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: small ? 9 : 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    );
    final valueStyle = TextStyle(
      color: Colors.white,
      fontSize: small ? 12 : 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );

    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        padding: EdgeInsets.all(small ? 14 : 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Stack(
          children: [
            // Decorative rings, as on printed cards.
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 22)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        card.bank.isEmpty ? 'Bank card' : card.bank,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: small ? 13 : 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(card.network.toUpperCase(), style: TextStyle(color: Colors.white, fontSize: small ? 11 : 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: small ? 30 : 38,
                      height: small ? 22 : 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFDE68A), Color(0xFFD4A24C)]),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('•••• •••• •••• ${card.last4}', style: TextStyle(color: Colors.white, fontSize: numberSize, fontWeight: FontWeight.w600, letterSpacing: 2)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CARD HOLDER', style: labelStyle),
                          Text(card.holder.isEmpty ? '-' : card.holder.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: valueStyle),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('VALID THRU', style: labelStyle),
                        Text(card.expiryLabel, style: valueStyle),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
