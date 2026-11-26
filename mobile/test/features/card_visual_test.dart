import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/card_store.dart';
import 'package:monova_app/features/cards/card_visual.dart';

void main() {
  CardRecord card(String network) => CardRecord(
        id: '1',
        bank: 'HDFC Bank',
        network: network,
        last4: '1111',
        holder: 'Asha Rao',
        expiryMonth: 8,
        expiryYear: 2029,
        updatedAt: DateTime.utc(2026, 11, 25),
      );

  testWidgets('a card shows its masked number, network, holder and valid-thru date', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: CardVisual(card: card('Visa')))),
    ));
    expect(find.text('•••• •••• •••• 1111'), findsOneWidget);
    expect(find.text('VISA'), findsOneWidget);
    expect(find.text('ASHA RAO'), findsOneWidget);
    expect(find.text('08/29'), findsOneWidget);
    expect(find.text('HDFC Bank'), findsOneWidget);
    expect(find.textContaining('4111'), findsNothing, reason: 'the full number is never shown');
  });

  test('each network gets its own colours, and unknown networks get the neutral ones', () {
    expect(networkColors('Visa'), isNot(equals(networkColors('Mastercard'))));
    expect(networkColors('Amex'), isNot(equals(networkColors('Card'))));
    expect(networkColors('Unknown'), networkColors('Card'));
  });
}
