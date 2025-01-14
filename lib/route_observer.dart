import 'package:flutter/material.dart';

class RouteObserverProvider extends InheritedWidget {
  const RouteObserverProvider({
    Key? key,
    required this.routeObserver,
    required Widget child,
  })   : assert(routeObserver != null),
        super(key: key, child: child);

  final RouteObserver? routeObserver;

  @override
  bool updateShouldNotify(covariant RouteObserverProvider oldWidget) =>
      routeObserver != oldWidget.routeObserver;

  static RouteObserverProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RouteObserverProvider>();
  }
}

class VisibilityObserver extends StatefulWidget {
  final Widget child;

  final Function(bool fromPop) onVisible;
  final Function(bool isPopped) onInvisible;

  const VisibilityObserver(
      {Key? key,
      required this.onVisible,
      required this.onInvisible,
      required this.child})
      : super(key: key);

  @override
  _VisibilityObserverState createState() => _VisibilityObserverState();
}

class _VisibilityObserverState extends State<VisibilityObserver>
    with RouteAware {
  late RouteObserver<Route> routeObserver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = RouteObserverProvider.of(context);
    if (provider == null) return;
    final _routeObserver = provider.routeObserver;
    assert(_routeObserver != null);
    final _modalRoute = ModalRoute.of(context);
    assert(_modalRoute != null);
    routeObserver = _routeObserver!;
    routeObserver.subscribe(this, _modalRoute!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  // Called when the current route has been pushed.
  void didPush() {
    widget.onVisible.call(false);
  }

  @override
  // Called when the top route has been popped off, and the current route shows up.
  void didPopNext() {
    widget.onVisible.call(true);
  }

  @override
  // current route is popped
  void didPop() {
    widget.onInvisible.call(true);
    super.didPop();
  }

  @override
  // new route has been pushed
  void didPushNext() {
    widget.onInvisible.call(false);
    super.didPushNext();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
