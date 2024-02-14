import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

final ImagePicker _picker = ImagePicker();

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MathNote',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'MathNote'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  String latext = "";
  late final WebViewController _controller;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = WebViewController();
    //_controller.loadFlutterAsset('assets/help.html');
  }

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  Future<String> get _localPath async {
    await Permission.storage.request();
    var status = await Permission.camera.status;
    if (status.isDenied) {
      // We haven't asked for permission yet or the permission has been denied before, but not permanently.
      await Permission.storage.request();
    }

// You can also directly ask permission about its status.
    final directory = await getExternalStorageDirectory();
    print("app dir is: $directory");

    if (directory != null) {
      return directory.path;
    } else {
      return (await getApplicationDocumentsDirectory()).path;
    }
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    print("local path in which its being saved is: $path");

    return File('$path/doc-${DateTime.now().toIso8601String()}.html');
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Choose an Image to convert to notes',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            ElevatedButton(
              onPressed: () async {
                final XFile? pickedFile = await _picker.pickImage(
                  source: ImageSource.gallery,
                );

                // Handle the picked image here
                if (pickedFile != null) {
                  final bytes = await pickedFile.readAsBytes();
                  final base64String = base64Encode(bytes);

                  print("base 64 conversion done!!");
                  print("base64 => $base64");

                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Sending Request to API...")));

                  final dio = Dio();
                  final mathnoteKey = dotenv.env["MATHNOTE_KEY"];
                  final response = await dio.post(
                      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent?key=$mathnoteKey',
                      data: {
                        "contents": [
                          {
                            "parts": [
                              {
                                "text":
                                    "Explain this mathematical equation and convert this into latex format and also include the relevant derivation and solution of it. please use \$\$ delimeters around mathematical equations"
                              },
                              {
                                "inline_data": {
                                  "mime_type": "image/jpeg",
                                  "data": base64String
                                }
                              }
                            ]
                          }
                        ]
                      });
                  print("grepped:");
                  // response text
                  final String responseText = response.data["candidates"][0]
                      ["content"]["parts"][0]["text"];
                  print(responseText);
                  final String htmlString = '''
				  <!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>Document</title>
	<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css" integrity="sha384-n8MVd4RsNIU0tAv4ct0nTaAbDJwPJzDEaqSD1odI+WdtXRGWt2kTvGFasHpSy3SV" crossorigin="anonymous">
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js" integrity="sha384-XjKyOOlGwcjNTAIQHIpgOno0Hl1YQqzUOEleOLALmuqehneUG+vnGctmUb0ZY0l8" crossorigin="anonymous"></script>
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js" integrity="sha384-+VBxd3r6XgURycqtZ117nYw44OOcIax56Z4dCRWbxyPt0Koah1uHoK0o4+/RRE05" crossorigin="anonymous"
    onload="renderMathInElement(document.body);"></script>
</head>
<body>
$responseText
</body>
</html>

				''';
                  final file = await _localFile;
                  file.writeAsString(htmlString);

                  setState(() {
                    latext = responseText;
                  });

                  _controller.loadFile(file.path);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Webpage stored in ${file.path}")));
                }
              },
              child: Text('Select Image'),
            ),
            latext == ""
                ? SizedBox()
                : Container(
                    height: 300,
                    width: 300,
                    child: WebViewWidget(controller: _controller))
            /*
                : Expanded(
                    child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Text(latext),
                  )),
	    */
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
