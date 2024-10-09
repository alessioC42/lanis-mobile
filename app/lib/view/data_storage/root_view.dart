import 'package:flutter/material.dart';
import 'package:sph_plan/view/data_storage/folder_listtile.dart';

import '../../client/client.dart';
import '../../shared/exceptions/client_status_exceptions.dart';
import '../../shared/types/dateispeicher_node.dart';
import 'file_listtile.dart';

class DataStorageRootView extends StatefulWidget {
  const DataStorageRootView({super.key});

  @override
  State<StatefulWidget> createState() => _DataStorageRootViewState();
}

class _DataStorageRootViewState extends State<DataStorageRootView> {
  var loading = true;
  var error = false;
  late List<FileNode> files;
  late List<FolderNode> folders;
  final SearchController searchController = SearchController();

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void loadItems() async {
    try {
      var items = await client.dataStorage.getRoot();
      var (fileList, folderList) = items;
      files = fileList;
      folders = folderList;

      setState(() {
        loading = false;
      });
    } on LanisException {
      setState(() {
        error = true;
        loading = false;
      });
    }
  }

  List<Widget> getListTiles() {
    var listTiles = <Widget>[];

    for (var folder in folders) {
      listTiles.add(FolderListTile(context: context, folder: folder));
    }
    for (var file in files) {
      listTiles.add(FileListTile(context: context, file: file));
    }
    return listTiles;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Datenspeicher"),
        actions: const [
          AsyncSearchAnchor(),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : error
              ? const Center(
                  child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 100),
                    SizedBox(height: 10),
                    Text("Fehler beim Laden der Dateien"),
                  ],
                ))
              : ListView(
                  children: getListTiles(),
                ),
    );
  }
}

class AsyncSearchAnchor extends StatefulWidget {
  const AsyncSearchAnchor({super.key});

  @override
  State<AsyncSearchAnchor> createState() => _AsyncSearchAnchorState();
}

class _AsyncSearchAnchorState extends State<AsyncSearchAnchor> {
  String? _searchingWithQuery;
  late Iterable<Widget> _lastOptions = <Widget>[];

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
        builder: (BuildContext context, SearchController controller) {
      return IconButton(
        icon: const Icon(Icons.search),
        onPressed: () {
          controller.openView();
        },
      );
    }, suggestionsBuilder:
            (BuildContext context, SearchController controller) async {
      _searchingWithQuery = controller.text;
      var options = await client.dataStorage.searchFiles(_searchingWithQuery??'');

      if (_searchingWithQuery != controller.text) {
        return _lastOptions;
      }

      _lastOptions = List<Widget>.generate(options?.length??0, (int index) {
        final Map item = options[index];
        return SearchFileListTile(
            context: context,
            name: item["text"],
            downloadUrl:
                "https://start.schulportal.hessen.de/dateispeicher.php?a=download&f=${item["id"]}");
      });

      if (_lastOptions.isEmpty) {
        _lastOptions = <Widget>[
          const ListTile(
            title: Text("Keine Ergebnisse"),
          )
        ];
      }

      return _lastOptions;
    });
  }
}
