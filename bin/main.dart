
import 'package:dart_isolate/isolate.dart';

void main(List<String> arguments) async {
  await for (Map<String, dynamic> jsonData in getJsonDataFromFiles()) {
    print("Get json data - $jsonData");
  }
}
