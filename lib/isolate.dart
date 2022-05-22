import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:async/async.dart';

// List of json file
const List<String> jsonFileNameList = [
  'assets/a.json',
  'assets/b.json',
  'assets/c.json',
];

/// Parse files to get json data
Stream<Map<String, dynamic>> getJsonDataFromFiles() async* {
  print('getJsonFilesContent() - Start');

  // Message receiver for getting text from other isolates
  final ReceivePort receivePort = ReceivePort();

  // Convert the ReceivePort into a StreamQueue to receive messages from the
  // spawned isolate using a pull-based interface. Events are stored in this
  // queue until they are accessed by `events.next`.
  final StreamQueue streamQueue = StreamQueue(receivePort);

  // Create a isolate to dealwith file parsing in the background.
  await Isolate.spawn(isolateParsingFile, receivePort.sendPort);

  // This port is resposible for communicating with the spawned isolate.
  // The first message from the spawned isolate is a SendPort.
  final SendPort workerIsolateSendPort = await streamQueue.next;

  // Do parsing json files
  for (String fileName in jsonFileNameList) {
    // Send file name to worker isoalte that it will parse the file.
    workerIsolateSendPort.send(fileName);

    // Get json data of file from worker isoalte.
    final Map<String, dynamic> jsonData = await streamQueue.next;

    // Add the result to the stream returned.
    yield jsonData;
  }
  print('getJsonFilesContent() - Json file parsing finished');

  // Send a null message to worker isolate that it should do exit().
  workerIsolateSendPort.send(null);
  print('getJsonFilesContent() - Request worker isolate to exit()');

  // Dispose the StreamQueue.
  // Cancel event listening of stream.
  await streamQueue.cancel();
  print('getJsonFilesContent() - Dispose the StreamQueue');
}

void isolateParsingFile(SendPort sendPort) async {
  print('isolateParsingFile() - Worker isolate - Start');

  // ReceivePort for receiving message from main isolate.
  final ReceivePort receivePort = ReceivePort();
  // Send a SendPort to main isolate that it can send file name to this isolate.
  sendPort.send(receivePort.sendPort);

  // Wait and dealwith message from main isolate.
  await for (dynamic message in receivePort) {
    if (message is String) {
      // If message is String type, it is file name.
      // Read the content of file, and decode it.
      final String fileContent = await File(message).readAsString();
      final Map<String, dynamic> jsonData = jsonDecode(fileContent);

      // Send json data to main isolate.
      print('isolateParsingFile() - Worker isolate - Send data to main isolate');
      sendPort.send(jsonData);
    } else if (message == null) {
      // Exit if the message from main isolate is null.
      // Indicates that all files have been processed.
      break;
    }
  }

  // Kill the isolate.
  Isolate.current.kill();
  print('isolateParsingFile() - Worker isolate - Finished');
}
