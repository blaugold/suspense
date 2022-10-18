import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suspense/suspense.dart';

void main() {
  testWidgets('smoke', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Suspense(
        fallback: ColoredBox(color: Colors.red),
        child: TestSuspendable(),
      ),
    ));

    await tester.pump(const Duration(seconds: 1));
  });
}

class TestSuspendable extends SuspendableStatefulWidget {
  const TestSuspendable({Key? key}) : super(key: key);

  @override
  State<TestSuspendable> createState() => _FooState();
}

class _FooState extends State<TestSuspendable> {
  final _future =
      Future.delayed(const Duration(seconds: 1), () => 'Hello, World!');

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(await(_future)),
    );
  }
}
