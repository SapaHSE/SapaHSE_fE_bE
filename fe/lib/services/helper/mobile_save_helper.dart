import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

Future<void> saveAndLaunchFile(List<int> bytes, String fileName) async {
  final Directory? directory = await getExternalStorageDirectory();
  if (directory == null) return;
  
  final String path = '${directory.path}/$fileName';
  final File file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  await OpenFilex.open(path);
}
