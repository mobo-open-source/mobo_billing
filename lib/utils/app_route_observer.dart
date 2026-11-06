import 'package:flutter/widgets.dart';

/// App-wide observer of full-screen page pushes and pops, registered on the
/// root [MaterialApp]. Screens mix in [RouteAware] and subscribe to it to
/// learn when a page pushed over them is popped (`didPopNext`) — e.g. the
/// dashboard reloads then, so it never shows figures from before an edit.
///
/// Typed to [PageRoute] so dialogs, popup menus and bottom sheets don't count.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
