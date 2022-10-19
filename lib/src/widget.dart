import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'future.dart';

enum _SuspendState {
  resumed,
  suspended,
}

class Suspense extends RenderObjectWidget {
  const Suspense({
    super.key,
    required this.fallback,
    required this.child,
  });

  final Widget fallback;
  final Widget child;

  @override
  RenderObjectElement createElement() => _SuspenseElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSuspense(
        element: context as _SuspenseElement,
        suspendState: _SuspendState.resumed,
      );
}

enum _SuspenseSlot {
  fallback,
  child,
}

class _SuspenseElement extends RenderObjectElement {
  _SuspenseElement(Suspense super.widget);

  @override
  _RenderSuspense get renderObject => super.renderObject as _RenderSuspense;

  Suspense get _widget => super.widget as Suspense;

  Element? _fallback;
  Element? _child;

  _SuspendState _suspendState = _SuspendState.resumed;

  set suspendState(_SuspendState value) {
    if (value != _suspendState) {
      _suspendState = value;
      renderObject._suspendState = value;
    }
  }

  final _suspendables = <SuspendableMixin>[];

  void registerSuspendable(SuspendableMixin suspendable) {
    _suspendables.add(suspendable);
    _updateSuspense();
  }

  void unregisterSuspendable(SuspendableMixin suspendable) {
    _suspendables.remove(suspendable);
    _updateSuspense();
  }

  void suspendableChanged() {
    _updateSuspense();
  }

  void _updateSuspense() => suspendState = _computeSuspenseState();

  _SuspendState _computeSuspenseState() {
    for (final suspendable in _suspendables) {
      if (suspendable._suspenseState == _SuspendState.suspended) {
        return _SuspendState.suspended;
      }
    }
    return _SuspendState.resumed;
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _updateChildren();
  }

  @override
  void update(covariant RenderObjectWidget newWidget) {
    super.update(newWidget);
    _updateChildren();
  }

  @override
  void forgetChild(Element child) {
    if (_fallback == child) {
      _fallback = null;
    } else if (_child == child) {
      _child = null;
    }
    super.forgetChild(child);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_fallback != null) {
      visitor(_fallback!);
    }
    if (_child != null) {
      visitor(_child!);
    }
  }

  @override
  void insertRenderObjectChild(RenderBox child, _SuspenseSlot slot) {
    switch (slot) {
      case _SuspenseSlot.fallback:
        renderObject.fallback = child;
        break;
      case _SuspenseSlot.child:
        renderObject.child = child;
        break;
    }
  }

  @override
  void removeRenderObjectChild(RenderBox child, _SuspenseSlot slot) {
    switch (slot) {
      case _SuspenseSlot.fallback:
        renderObject.fallback = null;
        break;
      case _SuspenseSlot.child:
        renderObject.child = null;
        break;
    }
  }

  @override
  void moveRenderObjectChild(
    RenderBox child,
    _SuspenseSlot oldSlot,
    _SuspenseSlot newSlot,
  ) {
    removeRenderObjectChild(child, oldSlot);
    insertRenderObjectChild(child, newSlot);
  }

  void _updateChildren() {
    _fallback =
        updateChild(_fallback, _buildFallback(), _SuspenseSlot.fallback);
    _child = updateChild(_child, _buildChild(), _SuspenseSlot.child);
  }

  Widget? _buildFallback() {
    if (_suspendState == _SuspendState.suspended) {
      return _widget.fallback;
    }
    return null;
  }

  Widget _buildChild() {
    // While the child is suspended we disable:
    //
    // - Semantics
    // - Focus
    // - Animations

    final isResumed = _suspendState == _SuspendState.resumed;
    return ExcludeSemantics(
      excluding: !isResumed,
      child: Focus(
        descendantsAreFocusable: isResumed,
        descendantsAreTraversable: isResumed,
        child: TickerMode(
          enabled: isResumed,
          child: _SuspenseScope(
            state: this,
            child: _widget.child,
          ),
        ),
      ),
    );
  }
}

class _RenderSuspense extends RenderBox {
  _RenderSuspense({
    required _SuspenseElement element,
    required _SuspendState suspendState,
  })  : _element = element,
        _suspendState = suspendState;

  final _SuspenseElement _element;

  _SuspendState _suspendState;

  set suspendState(_SuspendState suspendState) {
    if (suspendState != _suspendState) {
      _suspendState = suspendState;
      markNeedsLayout();
    }
  }

  RenderBox? _fallback;

  set fallback(RenderBox? value) {
    if (_fallback != value) {
      if (_fallback != null) {
        dropChild(_fallback!);
      }
      _fallback = value;
      if (_fallback != null) {
        adoptChild(_fallback!);
      }
      markNeedsLayout();
    }
  }

  RenderBox? _child;

  set child(RenderBox? value) {
    if (_child != value) {
      if (_child != null) {
        dropChild(_child!);
      }
      _child = value;
      if (_child != null) {
        adoptChild(_child!);
      }
      markNeedsLayout();
    }
  }

  RenderBox get _activeChild {
    switch (_suspendState) {
      case _SuspendState.resumed:
        return _child!;
      case _SuspendState.suspended:
        return _fallback!;
    }
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_fallback != null) {
      visitor(_fallback!);
    }
    if (_child != null) {
      visitor(_child!);
    }
  }

  @override
  void attach(covariant PipelineOwner owner) {
    super.attach(owner);
    _fallback?.attach(owner);
    _child?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _fallback?.detach();
    _child?.detach();
  }

  @override
  void redepthChildren() {
    if (_fallback != null) {
      redepthChild(_fallback!);
    }
    if (_child != null) {
      redepthChild(_child!);
    }
  }

  @override
  void performLayout() {
    // TODO: Reduce cost of layout if suspended.
    _child!.layout(constraints, parentUsesSize: true);

    invokeLayoutCallback((_) {
      _element.owner!.buildScope(_element, () {
        _element._updateChildren();
      });
    });

    switch (_suspendState) {
      case _SuspendState.resumed:
        size = _child!.size;
        break;
      case _SuspendState.suspended:
        _fallback!.layout(constraints, parentUsesSize: true);
        size = _fallback!.size;
        break;
    }
  }

  @override
  bool paintsChild(covariant RenderObject child) => _activeChild == child;

  @override
  void paint(PaintingContext context, Offset offset) =>
      context.paintChild(_activeChild, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: null,
        position: position,
        hitTest: (result, transformed) =>
            _activeChild.hitTest(result, position: transformed),
      );

  @override
  double computeMinIntrinsicWidth(double height) =>
      _activeChild.computeMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _activeChild.computeMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _activeChild.computeMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _activeChild.computeMaxIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _activeChild.getDistanceToActualBaseline(baseline);
}

class _SuspenseScope extends InheritedWidget {
  const _SuspenseScope({required this.state, required super.child});

  final _SuspenseElement state;

  static _SuspenseElement of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SuspenseScope>()?.state ??
      // TODO: Throw better error.
      (throw Exception('No Suspense found in ancestors.'));

  @override
  bool updateShouldNotify(_SuspenseScope oldWidget) => state != oldWidget.state;
}

mixin SuspendableMixin on ComponentElement {
  _SuspendState _suspenseState = _SuspendState.resumed;
  final _awaitedFutures = <Future>[];
  int _currentFutureIndex = 0;
  bool _disposed = false;
  bool _firstBuild = true;
  _SuspenseElement? _suspendScope;

  void _updateSuspenseScope(_SuspenseElement? scope) {
    if (_suspendScope != scope) {
      _suspendScope?.unregisterSuspendable(this);
      _suspendScope = scope;
      _suspendScope?.registerSuspendable(this);
    }
  }

  void _buildInputsChanged() {
    _awaitedFutures.clear();
  }

  void _markSuspended() {
    if (_suspenseState != _SuspendState.suspended) {
      _suspenseState = _SuspendState.suspended;
      _suspendScope?.suspendableChanged();
    }
  }

  void _markResumed() {
    if (_suspenseState != _SuspendState.resumed) {
      _suspenseState = _SuspendState.resumed;
      _suspendScope?.suspendableChanged();
    }
  }

  Future<T> _onAwaitFuture<T>(Future<T> future) {
    Future<T> result;
    if (_awaitedFutures.length > _currentFutureIndex) {
      final awaitedFuture = _awaitedFutures[_currentFutureIndex];
      result = awaitedFuture as Future<T>;
    } else {
      result = future;
      initFuture(future);
      _awaitedFutures.add(future);
      if (future.status == FutureStatus.pending) {
        future.whenComplete(() {
          if (!_disposed && _awaitedFutures.contains(future)) {
            markNeedsBuild();
          }
        });
      }
    }

    _currentFutureIndex++;
    return result;
  }

  @override
  void didChangeDependencies() {
    _buildInputsChanged();
    _updateSuspenseScope(_SuspenseScope.of(this));
    super.didChangeDependencies();
  }

  @override
  void update(covariant Widget newWidget) {
    _buildInputsChanged();
    super.update(newWidget);
  }

  @override
  Widget build() {
    if (_firstBuild) {
      _firstBuild = false;
      _updateSuspenseScope(_SuspenseScope.of(this));
    }
    awaitFutureInterceptor = _onAwaitFuture;
    try {
      final widget = super.build();
      _markResumed();
      return widget;
    } on SuspendException {
      _markSuspended();
      return const SizedBox();
    } finally {
      _currentFutureIndex = 0;
      awaitFutureInterceptor = null;
    }
  }

  @override
  void unmount() {
    super.unmount();
    _updateSuspenseScope(null);
    _disposed = true;
  }
}

abstract class SuspendableWidget extends StatelessWidget {
  const SuspendableWidget({super.key});

  @override
  StatelessElement createElement() => SuspendableElement(this);
}

class SuspendableElement extends StatelessElement with SuspendableMixin {
  SuspendableElement(SuspendableWidget super.widget);
}

abstract class SuspendableStatefulWidget extends StatefulWidget {
  const SuspendableStatefulWidget({super.key});

  @override
  StatefulElement createElement() => SuspendableStatefulElement(this);
}

class SuspendableStatefulElement extends StatefulElement with SuspendableMixin {
  SuspendableStatefulElement(SuspendableStatefulWidget super.widget);

  @override
  void markNeedsBuild() {
    // setState calls this method, which means that the inputs to the build
    // method have changed.
    _buildInputsChanged();
    super.markNeedsBuild();
  }
}

class SuspendableBuilder extends SuspendableWidget {
  const SuspendableBuilder({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => builder(context);
}
