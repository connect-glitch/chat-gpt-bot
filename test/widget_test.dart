import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_bot/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatBotApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
