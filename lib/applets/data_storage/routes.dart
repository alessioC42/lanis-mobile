import 'package:go_router/go_router.dart';
import 'package:lanis/applets/data_storage/definition.dart';
import 'package:lanis/applets/data_storage/node_view.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/utils/deep_link.dart';

List<RouteBase> buildDataStorageRoutes(AppletRouteContext ctx) {
  final home = dataStorageDefinition.homePath();
  return [
    GoRoute(
      path: '/common/storage',
      redirect: (context, state) {
        if (state.uri.path == '/common/storage') return home;
        return null;
      },
      routes: [
        GoRoute(
          path: 'home',
          builder: (context, state) => ctx.homeBody(dataStorageDefinition),
        ),
        GoRoute(
          path: 'folder/:nodeId',
          builder: (context, state) {
            final raw = state.pathParameters['nodeId']!;
            final nodeId = int.tryParse(raw);
            if (nodeId == null) {
              return DeepLinkErrorPage(
                error: DeepLinkException('Invalid folder id: $raw'),
                fallbackPath: home,
              );
            }
            final title = state.uri.queryParameters['title'] ?? '';
            return DeepLinkPopScope(
              fallbackPath: home,
              child: DataStorageNodeView(nodeID: nodeId, title: title),
            );
          },
        ),
      ],
    ),
  ];
}
