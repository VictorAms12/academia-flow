import 'package:flutter_test/flutter_test.dart';
import 'package:academia_flow/app.dart';

void main() {
  testWidgets('Academia Flow abre o dashboard', (tester) async {
    await tester.pumpWidget(const AcademiaFlowApp());
    await tester.pumpAndSettle();
    expect(find.text('Academia Flow'), findsWidgets);
    expect(find.textContaining('Olá, Victor'), findsOneWidget);
  });
}
