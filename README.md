This package is a proof-of-concept (POC) of suspendable `Widget`s which can
`await` `Future`s.

The goal is to explore how to bring concepts like React's `Suspense` component
and the planned `use` hook to Flutter.

Before continuing, take a look at
[Suspense for data Fetching](https://17.reactjs.org/docs/concurrent-mode-suspense.html)
and the
[React RFC for first class support for Promises](https://github.com/reactjs/rfcs/pull/229)
for the motivating use cases.

At least one known issue in this POC is that the result of an already resolved
`Future`, that is created during a build phase, can only be accessed in the next
frame. This can cause a single frame flicker of the loading state. Resolving
this requires some kind of change to the Dart language and how `Future`s are
handled or a change in the Flutter framework.

## Usage

Within `SuspendableWidget` and `SuspendableStatefulWidget` you can use the
`await` function in the `build` method to await `Future`s.

The `await` function returns the value or throws the error the `Future`
completed with. Try-catch blocks that contain `await` calls must **not catch**
`SuspendException`s.

```dart
class PrintFuture extends SuspendableWidget {
  const PrintFuture({super.key, required this.future});

  final Future future;

  @override
  Widget build(BuildContext context) {
    try {
      final value = await(future);
      return Text(value.toString());
    } on SuspendException {
      rethrow;
    } catch (e, s) {
      return Text('Error: $e\n$s');
    }
  }
}
```

The widget above handles the completed `Future` but it does not care about what
happens while the `Future` is still pending. Until all awaited `Future`s are
completed, the widget is suspended. Suspended widgets cannot be shown in the UI
since they cannot be built.

Providing a fallback UI is the responsibility of the `Suspense` widget. All
suspendable widgets must be descendants of a `Suspense` widget.

```dart
class Page extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Suspense(
      fallback: const CircularProgressIndicator(),
      child: Column(
        children: const [
          UserProfile(),
          Suspense(
            fallback: CircularProgressIndicator(),
            child: UserTimeLine(),
          )
        ],
      ),
    );
  }
}

class UserProfile extends SuspendableStatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  final _userName = loadUserName();

  @override
  Widget build(BuildContext context) {
    return Text("This is ${await(_userName)}'s profile!");
  }
}

class UserTimeLine extends SuspendableStatefulWidget {
  const UserTimeLine({super.key});

  @override
  State<UserTimeLine> createState() => _UserTimeLineState();
}

class _UserTimeLineState extends State<UserTimeLine> {
  final _timeLine = loadUserTimeLine();

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      for (final entry in await(_timeLine)) Text(entry),
    ]);
  }
}

Future<String> loadUserName() => throw UnimplementedError();

Future<List<String>> loadUserTimeLine() => throw UnimplementedError();
```


