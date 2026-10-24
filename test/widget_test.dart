
import 'package:flutter_test/flutter_test.dart';
import 'package:alumini_app/app.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const EdcAdminApp());

    expect(find.byType(EdcAdminApp), findsOneWidget);
  });
}
