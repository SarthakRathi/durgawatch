// lib/recordings_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({Key? key}) : super(key: key);

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  List<FileSystemEntity> _videoFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    setState(() => _isLoading = true);

    final dir = await getApplicationDocumentsDirectory();
    final recDir = Directory('${dir.path}/recordings');
    if (!recDir.existsSync()) {
      recDir.createSync(recursive: true);
    }

    final files =
        recDir.listSync().where((f) => f.path.endsWith('.mp4')).toList();

    setState(() {
      _videoFiles = files;
      _isLoading = false;
    });
  }

  Future<void> _openVideo(FileSystemEntity file) async {
    // Use open_file to launch the device's default media player
    await OpenFile.open(file.path);
  }

  Future<void> _deleteVideo(FileSystemEntity file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Recording'),
        content: const Text('Are you sure you want to delete this video?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final localFile = File(file.path);
        if (await localFile.exists()) {
          await localFile.delete();
        }
        // TODO: optionally delete from Firebase storage if you want:
        // await _deleteFromFirebaseStorage(fileName);

        // Then refresh
        _loadRecordings();
      } catch (e) {
        debugPrint('Error deleting file: $e');
      }
    }
  }

  // Optional: if you store references in Firebase, remove them here.
  /*
  Future<void> _deleteFromFirebaseStorage(String fileName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final storageRef = FirebaseStorage.instance.ref();
    final fileRef = storageRef.child('recordings/${user.uid}/$fileName');
    await fileRef.delete();
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videoFiles.isEmpty
              ? const Center(child: Text('No recordings found.'))
              : ListView.builder(
                  itemCount: _videoFiles.length,
                  itemBuilder: (ctx, index) {
                    final file = _videoFiles[index];
                    final fileName = file.path.split('/').last;
                    return ListTile(
                      leading: const Icon(Icons.video_file),
                      title: Text(fileName),
                      onTap: () => _openVideo(file),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: () => _deleteVideo(file),
                      ),
                    );
                  },
                ),
    );
  }
}
