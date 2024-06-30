import 'package:flutter/material.dart';

import '../../client/client.dart';
import '../../shared/exceptions/client_status_exceptions.dart';
import '../../shared/types/dateispeicher_node.dart';
import 'file_listtile.dart';

class DataStorageNodeView extends StatefulWidget {
  final int nodeID;
  final String title;

  const DataStorageNodeView(
      {super.key, required this.nodeID, required this.title});

  @override
  State<StatefulWidget> createState() => _DataStorageNodeViewState();
}

class _DataStorageNodeViewState extends State<DataStorageNodeView> {
  var loading = true;
  var error = false;
  late List<FileNode> files;
  late List<FolderNode> folders;

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  void loadItems() async {
    try {
      var items = await client.dataStorage.getNode(widget.nodeID);
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
      listTiles.add(ListTile(
          title: Text(folder.name),
          subtitle: Text(
            folder.desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          leading: const Icon(Icons.folder_outlined),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    DataStorageNodeView(nodeID: folder.id, title: folder.name),
              ),
            );
          }));
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
        title: Text(widget.title),
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
