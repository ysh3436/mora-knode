import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mora_knode_app/main.dart';

void main() {
  testWidgets('App boots to Mora Knode title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MoraKnodeApp()));
    await tester.pump();
    expect(find.text('Mora Knode'), findsOneWidget);
  });
}
