// Where imported recordings are kept on the phone.
//
// Their own folder rather than the one the takes go in. A take is
// something the app recorded and can write again; a recording is
// somebody's session, is a hundred times the size, and deleting the
// wrong one is not the same kind of mistake.

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../practice/recording_store.dart';

class DeviceRecordingFiles implements RecordingFiles {
  Future<Directory> _folder() async {
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory('${documents.path}/recordings');
    if (!folder.existsSync()) await folder.create(recursive: true);
    return folder;
  }

  @override
  Future<String> save(String name, Uint8List bytes) async {
    final folder = await _folder();
    await File('${folder.path}/$name').writeAsBytes(bytes, flush: true);
    return name;
  }

  @override
  Future<String?> pathOf(String name) async {
    final folder = await _folder();
    final file = File('${folder.path}/$name');
    return file.existsSync() ? file.path : null;
  }

  @override
  Future<void> remove(String name) async {
    final folder = await _folder();
    final file = File('${folder.path}/$name');
    if (file.existsSync()) await file.delete();
  }
}
