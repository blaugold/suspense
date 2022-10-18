import 'package:flutter/material.dart';
import 'package:suspense/suspense.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Home(),
    );
  }
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Suspense(
        fallback: spinner,
        child: Column(
          children: [
            const Delayed(delay: Duration(seconds: 1)).expanded(),
            const SizedBox(height: 16),
            Suspense(
              fallback: spinner,
              child: const Delayed(delay: Duration(seconds: 2)),
            ).expanded(),
          ],
        ),
      ).padding(spacing),
    );
  }
}

class Delayed extends SuspendableStatefulWidget {
  const Delayed({super.key, required this.delay});

  final Duration delay;

  @override
  State<Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<Delayed> with TickerProviderStateMixin {
  late final _future = Future<void>.delayed(widget.delay);

  @override
  Widget build(BuildContext context) {
    await(_future);
    return Card(
      child: Text('Delayed by ${widget.delay}.').padding(spacing).center(),
    );
  }
}

const spacing = EdgeInsets.all(16.0);

final spinner = const CircularProgressIndicator().center();

extension on Widget {
  Widget padding(EdgeInsetsGeometry padding) =>
      Padding(padding: padding, child: this);

  Widget center() => Center(child: this);

  Widget expanded() => Expanded(child: this);
}
