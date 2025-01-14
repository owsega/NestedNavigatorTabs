library nested_navigator_tabbar;

import 'package:flutter/material.dart';
import 'package:nested_navigator_tabs/route_observer.dart';

class NestedNavigatorTabs extends StatefulWidget {
  /// List of tabs with the initial route's name
  final List<NavigatorTab> tabs;

  /// Custom builder for the bottom bar
  final Widget Function(
      BuildContext context,
      List<BottomNavigationBarItem> navItems,
      int selectedIndex,
      Function(int) onIndexSelected)? bottomBarBuilder;

  /// Custom layout builder
  final Widget Function(BuildContext context, IndexedStack container,
      Widget bottomBar, int currentIndex)? layoutBuilder;

  /// Pops the current nested navigator to the initial route when the selected tab is tapped
  final bool clearStackOnDoubleTap;

  ///  Pops the current nested route on back press
  final bool popNestedRouteOnBack;

  ///  Initial tab index, default is 0
  final int initialTab;

  /// Route generator for the named routes
  final Route Function(RouteSettings routeSettings) generator;

  /// Defines how the tabs and the inner navigation stacks work.
  final BackMode backMode;

  final void Function(
      {required int tab,
      required String routeName,
      required StackEvent type})? onGlobalStackChanged;

  List<String> get _defaultRouteNames =>
      tabs.map((e) => e.defaultRouteName).toList();

  List<BottomNavigationBarItem> get _navItems =>
      tabs.map((e) => e.navItem).toList();

  NestedNavigatorTabs({
    Key? key,
    required this.tabs,
    required this.generator,
    this.bottomBarBuilder,
    this.layoutBuilder,
    this.clearStackOnDoubleTap = true,
    this.popNestedRouteOnBack = true,
    this.initialTab = 0,
    this.backMode = BackMode.globalStack,
    this.onGlobalStackChanged,
  })  : assert(tabs.isNotEmpty, "Tabs must contain at least 1 item"),
        assert(initialTab >= 0 && initialTab < tabs.length),
        super(key: key);

  @override
  _NestedNavigatorTabsState createState() => _NestedNavigatorTabsState();

  static _NestedNavigatorTabsState? of(
    BuildContext context, {
    bool isNullOk = false,
  }) {
    final _NestedNavigatorTabsState? result = context.findAncestorStateOfType();
    if (isNullOk || result != null) {
      return result;
    }
    throw FlutterError(
      'NestedTabNavigator.of() called with a context that does not contain a NestedTabNavigator.\n',
    );
  }

  /// Gets the NavigatorState of the [tabIndex] tab and optionally switches to it.
  static NavigatorState tabNavigatorOf(
    BuildContext context, {
    required int tabIndex,
    required bool setToCurrent,
  }) {
    final tabNavigatorState = of(context)!;
    if (setToCurrent &&
        tabIndex != tabNavigatorState.tabIndex &&
        tabNavigatorState.mounted) {
      tabNavigatorState.onTapNav(tabIndex, noClear: true);
    }
    return tabNavigatorState.navStates[tabIndex].currentState!;
  }

  static void switchTabTo(BuildContext context, {required int tabIndex}) {
    tabNavigatorOf(context, tabIndex: tabIndex, setToCurrent: true);
  }

  /// Pushes the [route] to the current or [tabIndex] tab
  static void navigateTo(
    BuildContext context, {
    int? tabIndex,
    required Route route,
  }) {
    final tabNavigatorState = of(context)!;

    tabNavigatorOf(
      context,
      tabIndex: tabIndex ?? tabNavigatorState.tabIndex,
      setToCurrent: true,
    ).push(
      route,
    );
  }

  ///Popping the current tab's route and switchis to the previous tab if needed
  ///(example: backMode is globalStack and the previous page was on a different tab)
  static void back(BuildContext context) {
    final scaffoldState = of(context)!;
    scaffoldState.back();
  }
}

class _NestedNavigatorTabsState extends State<NestedNavigatorTabs> {
  int tabIndex = 0;

  late List<GlobalKey<NavigatorState>> navStates;
  late List<RouteObserver<PageRoute>> routeObservers;
  late List<NavigatorObserver> navigatorObservers;

  List<TabNavigatorStackItem> globalStack = [];

  final String _emptyRoute = "nestedNavigatorTab.empty";

  @override
  void initState() {
    navStates = widget._defaultRouteNames
        .map((p) => GlobalKey<NavigatorState>())
        .toList();
    routeObservers = widget._defaultRouteNames
        .map((e) => RouteObserver<PageRoute>())
        .toList();
    navigatorObservers = widget._defaultRouteNames
        .map(withIndex((navigator, index) => TabNavigatorObserver(
              emptyName: _emptyRoute,
              globalStack: globalStack,
              tab: index,
              onGlobalStackChanged: ({required routeName, required type}) =>
                  widget.onGlobalStackChanged
                      ?.call(tab: index, routeName: routeName, type: type),
            )))
        .toList();

    onWillPopForStayOnTab = () async {
      if (true == navStates[tabIndex].currentState?.canPop()) {
        navStates[tabIndex].currentState!.pop();
        return false;
      }
      return true;
    };
    onWillPopForGlobalStack = () async {
      if (globalStack.last.tab != tabIndex) {
        //shouldn't be possible
        onTapNav(globalStack.last.tab);
        return false;
      } else if (globalStack.length > 1 &&
          globalStack.last.tab == tabIndex &&
          globalStack[globalStack.length - 2].tab != tabIndex) {
        // previous route is on a different tab
        var newTab = globalStack[globalStack.length - 2].tab;
        if (true == navStates[tabIndex].currentState?.canPop()) {
          navStates[tabIndex].currentState!.pop();
        }
        onTapNav(newTab);
        return false;
      } else if (globalStack.length > 1 &&
          globalStack.last.tab == tabIndex &&
          globalStack[globalStack.length - 2].tab == tabIndex) {
        // previous route is on the same tab
        if (true == navStates[tabIndex].currentState?.canPop()) {
          navStates[tabIndex].currentState!.pop();
        }
        return false;
      } else if (true == navStates[tabIndex].currentState?.canPop()) {
        navStates[tabIndex].currentState!.pop();
        return false;
      }
      return true;
    };
    onWillPopForEmptySwitch = () async {
      if (true != navStates[tabIndex].currentState?.canPop() &&
          globalStack.length > 1) {
        onTapNav(
            globalStack.where((element) => element.tab != tabIndex).last.tab);
        return false;
      } else if (true == navStates[tabIndex].currentState?.canPop()) {
        navStates[tabIndex].currentState!.pop();
        return false;
      }
      return true;
    };

    super.initState();
  }

  late Future<bool> Function() onWillPopForStayOnTab;
  late Future<bool> Function() onWillPopForGlobalStack;
  late Future<bool> Function() onWillPopForEmptySwitch;

  Future<bool> Function() get popHandler {
    switch (widget.backMode) {
      case BackMode.stayOnTab:
        return onWillPopForStayOnTab;
      case BackMode.globalStack:
        return onWillPopForGlobalStack;
      case BackMode.switchTabWhenEmpty:
        return onWillPopForEmptySwitch;
    }
  }

  @override
  Widget build(BuildContext context) {
    var bottomBar = widget.bottomBarBuilder
            ?.call(context, widget._navItems, tabIndex, onTapNav) ??
        BottomNavigationBar(
          items: widget._navItems,
          currentIndex: tabIndex,
          onTap: onTapNav,
        );

    return WillPopScope(
      onWillPop: widget.popNestedRouteOnBack ? popHandler : () async => true,
      child: VisibilityObserver(
        onVisible: (fromPop) {
          if (fromPop) {
            navStates[tabIndex]
                .currentState
                ?.popUntil((route) => route.settings.name != _emptyRoute);
          } else {
            //runs when initialized
            WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
              navStates.forEach((element) {
                if (element != navStates[tabIndex]) {
                  element.currentState?.pushNamed(_emptyRoute);
                }
              });
            });
          }
        },
        onInvisible: (isPopped) {
          if (!isPopped) {
            navStates[tabIndex].currentState?.pushNamed(_emptyRoute);
          }
        },
        child: widget.layoutBuilder
                ?.call(context, _buildContainer(), bottomBar, tabIndex) ??
            Scaffold(
              backgroundColor: Theme.of(context).backgroundColor,
              body: _buildContainer(),
              bottomNavigationBar: bottomBar,
            ),
      ),
    );
  }

  IndexedStack _buildContainer() {
    return IndexedStack(
      index: tabIndex,
      children: widget._defaultRouteNames.map(
        withIndex(
          (initialPage, index) {
            return RouteObserverProvider(
              routeObserver: routeObservers[index],
              child: Navigator(
                key: navStates[index],
                observers: [navigatorObservers[index], routeObservers[index]],
                initialRoute: initialPage,
                onGenerateRoute: (settings) {
                  if (settings.name == _emptyRoute) {
                    return MaterialPageRoute(
                        settings: settings, builder: (context) => Container());
                  }
                  return widget.generator(settings);
                },
              ),
            );
          },
        ),
      ).toList(),
    );
  }

  void back() {
    popHandler();
  }

  void onTapNav(int index, {bool noClear = false}) {
    if (index == tabIndex) {
      // double tap
      if (widget.clearStackOnDoubleTap && !noClear) {
        navStates[index].currentState?.popUntil((route) => route.isFirst);
      }
    } else if (mounted) {
      var oldInd = tabIndex;
      var newInd = index;
      navStates[oldInd].currentState?.pushNamed(_emptyRoute);
      navStates[newInd]
          .currentState
          ?.popUntil((route) => route.settings.name != _emptyRoute);

      setState(() {
        tabIndex = index;
      });
    }
  }
}

class NavigatorTab {
  final String defaultRouteName;
  final BottomNavigationBarItem navItem;

  NavigatorTab({required this.defaultRouteName, required this.navItem});
}

typedef MapFn<A, B> = B Function(A a);

typedef IndexedMapFn<A, B> = B Function(A a, int index);

/// helper for mapping with an index
MapFn<A, B> withIndex<A, B>(IndexedMapFn<A, B> mapFn) {
  int index = -1;
  return (A a) => mapFn(a, ++index);
}

class TabNavigatorStackItem {
  final int tab;
  final String routeName;
  final bool isFirst;

  TabNavigatorStackItem(this.tab, this.routeName, {this.isFirst = false});
}

enum StackEvent { becameVisible, becameInvisible }

class TabNavigatorObserver extends NavigatorObserver {
  final int tab;
  final List<TabNavigatorStackItem> stack = [];
  final List<TabNavigatorStackItem> globalStack;
  final void Function({required String routeName, required StackEvent type})
      onGlobalStackChanged;
  final String emptyName;

  TabNavigatorObserver(
      {required this.globalStack,
      required this.onGlobalStackChanged,
      required this.tab,
      required this.emptyName});

  @override
  void didPop(Route route, Route? previousRoute) {
    // print("item popped on tab: $tab with name: ${route.settings.name}");
    assert(previousRoute?.settings != null);

    if (route.settings.name != emptyName) {
      stack.removeLast();
      var last = globalStack.where((element) => element.tab == tab).last;
      globalStack.remove(last);
      onGlobalStackChanged(
          routeName: route.settings.name!, type: StackEvent.becameInvisible);
      onGlobalStackChanged(
          routeName: previousRoute!.settings.name!,
          type: StackEvent.becameVisible);
    } else {
      if (!globalStack.any((element) => element.tab == tab)) {
        globalStack.add(TabNavigatorStackItem(
            tab, previousRoute!.settings.name!,
            isFirst: previousRoute.isFirst));
      }
      onGlobalStackChanged(
          routeName: previousRoute!.settings.name!,
          type: StackEvent.becameVisible);
    }
    // print("items: " + globalStack.toString());

    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    // print("item replaced on tab: $tab with name: ${newRoute.settings.name}");
    assert(newRoute?.settings != null);
    assert(oldRoute?.settings != null);

    stack.removeLast();
    globalStack.remove(globalStack.where((element) => element.tab == tab).last);

    stack.add(TabNavigatorStackItem(tab, newRoute!.settings.name!));
    globalStack.add(TabNavigatorStackItem(tab, newRoute.settings.name!));
    onGlobalStackChanged(
        routeName: oldRoute!.settings.name!, type: StackEvent.becameInvisible);
    onGlobalStackChanged(
        routeName: newRoute.settings.name!, type: StackEvent.becameVisible);
    // print("items: " + globalStack.toString());
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // print("item removed on tab: $tab with name: ${route.settings.name}");
    stack.removeLast();
    var last = globalStack.where((element) => element.tab == tab).last;
    globalStack.remove(last);
    onGlobalStackChanged(
        routeName: route.settings.name!, type: StackEvent.becameInvisible);
    if (previousRoute != null) {
      onGlobalStackChanged(
          routeName: previousRoute.settings.name!,
          type: StackEvent.becameVisible);
    }
    // print("items: " + globalStack.toString());

    super.didRemove(route, previousRoute);
  }


  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // print("item pushed on tab: $tab with name: ${route.settings.name}");
    if (route.settings.name != emptyName) {
      stack.add(TabNavigatorStackItem(tab, route.settings.name!,
          isFirst: route.isFirst));
      globalStack.add(TabNavigatorStackItem(tab, route.settings.name!,
          isFirst: route.isFirst));
      onGlobalStackChanged(
          routeName: route.settings.name!, type: StackEvent.becameVisible);
      if (previousRoute != null) {
        onGlobalStackChanged(
            routeName: previousRoute.settings.name!,
            type: StackEvent.becameInvisible);
      }
    } else if (route.settings.name == emptyName &&
        previousRoute?.isFirst == true) {
      //remove wrong initial items
      globalStack
          .removeWhere((element) => element.tab == tab && element.isFirst);
    }
    if (route.settings.name == emptyName && previousRoute != null) {
      onGlobalStackChanged(
          routeName: previousRoute.settings.name!,
          type: StackEvent.becameInvisible);
    }

    // print("items: " + globalStack.toString());

    super.didPush(route, previousRoute);
  }
}

enum BackMode {
  /// Stays on the same tab, uses the inner stack only
  stayOnTab,

  /// Follows the global stacks, switches among the tabs
  globalStack,

  /// Stays on the same tab until the inner stack is empty,
  /// then switches to previously visited tab
  switchTabWhenEmpty
}
