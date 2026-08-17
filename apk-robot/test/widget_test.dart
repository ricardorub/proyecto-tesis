import 'package:flutter_test/flutter_test.dart';
import 'package:rover_slam_control/main.dart';

void main() {
  testWidgets('RoverControlApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RoverControlApp());
    expect(find.text('ROVER SLAM CONTROL'), findsOneWidget);
  });
}
