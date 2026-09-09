import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/main.dart';

void main() {
  testWidgets('MarthApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MarthApp());

    expect(find.text('MarthApp'), findsWidgets);
    expect(find.text('Estado de Supabase'), findsOneWidget);
  });
}
