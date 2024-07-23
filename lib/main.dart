import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ndi/config.dart';
import 'package:flutter_ndi/ndi.dart';
import 'package:osc/osc.dart';

late NDI ndi;
final appConfig = AppConfig();

void main() async {
  ndi = NDI();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  DateTime lastRefresh = DateTime.now();
  bool loading = false;
  NDISource? selectedSource;
  NDIOutputFrame? currentFrame;
  ByteData? currentFrameBytes;

  @override
  void initState() {
    checkGPU();
    super.initState();
  }

  void checkGPU() {
    final major = calloc<ffi.Int>();
    final minor = calloc<ffi.Int>();
    ndiConvert.getDeviceProperties(major, minor);
    // ignore: avoid_print
    print("GPU version ${major.value}.${minor.value}");
    if (major.value == 0) {
      Future.delayed(const Duration(seconds: 1), () {
        showDialog(
          context: context,
          builder: (context) {
            return SimpleDialog(
              elevation: 0,
              title: const Text(
                "Failed to check GPU version.",
              ),
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "OK",
                    ),
                  ),
                ),
              ],
            );
          },
        );
      });
    } else if (major.value < appConfig.minMajorCC) {
      Future.delayed(const Duration(seconds: 1), () {
        showDialog(
          context: context,
          builder: (context) {
            return SimpleDialog(
              elevation: 0,
              title: const Text(
                "Your GPU might not be supported",
              ),
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "OK",
                    ),
                  ),
                ),
              ],
            );
          },
        );
      });
    }
    calloc.free(major);
    calloc.free(minor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: (() {
                loading = true;
                setState(() {});
                ndi.updateSoures().then((_) {
                  setState(() {
                    loading = false;
                  });
                });
              }),
              color: Colors.black,
              iconSize: 25,
              icon: const Icon(Icons.refresh_sharp),
            ),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            if (!loading && ndi.sources.isEmpty)
              const Center(
                child: Text(
                  "No Sources Found",
                ),
              ),
            SizedBox(
              height: 100,
              width: 300,
              child: ListView.builder(
                itemCount: ndi.sources.length,
                itemBuilder: (context, index) {
                  return ElevatedButton(
                      onPressed: () {
                        final pS = ndi.getSourceAt(index);

                        if (pS != null) {
                          ndi.stopGetFrames();
                          selectedSource = NDISource(pS);
                          setState(() {});
                          ndi.getFrames(selectedSource!.source, (frame) async {
                            // final bytes = await frame.iRGBA
                            //     .toByteData(format: ui.ImageByteFormat.png);
                            setState(() {
                              currentFrame = frame;
                              // currentFrameBytes = bytes;
                            });
                          });
                        }
                      },
                      child: Text(ndi.sources[index].name));
                },
              ),
            ),
            if (currentFrame != null)
              Container(
                width: 1920 * 0.7,
                height: 1080 * 0.7,
                color: Colors.red,
                child: RawImage(
                  image: currentFrame!.iRGBA,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                    onPressed: () {
                      final destination = InternetAddress("192.168.5.25");
                      const port = 7000;
                      const address = "/composition/columns/1/connect";
                      final message = OSCMessage(address,
                          arguments: [DataCodec.forType("i").toValue("1")]);
                      RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
                          .then((socket) {
                        socket.send(message.toBytes(), destination, port);
                      });
                    },
                    child: const Text("Column 1")),
                ElevatedButton(
                    onPressed: () {
                      final destination = InternetAddress("192.168.5.25");
                      const port = 7000;
                      const address = "/composition/columns/2/connect";
                      final message = OSCMessage(address,
                          arguments: [DataCodec.forType("i").toValue("1")]);
                      RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
                          .then((socket) {
                        socket.send(message.toBytes(), destination, port);
                      });
                    },
                    child: const Text("Column 2")),
                ElevatedButton(
                    onPressed: () {
                      final destination = InternetAddress("192.168.5.25");
                      const port = 7000;
                      const address = "/composition/columns/3/connect";
                      final message = OSCMessage(address,
                          arguments: [DataCodec.forType("i").toValue("1")]);
                      RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
                          .then((socket) {
                        socket.send(message.toBytes(), destination, port);
                      });
                    },
                    child: const Text("Column 3")),
                ElevatedButton(
                    onPressed: () {
                      final destination = InternetAddress("192.168.5.25");
                      const port = 7000;
                      const address = "/composition/columns/4/connect";
                      final message = OSCMessage(address,
                          arguments: [DataCodec.forType("i").toValue("1")]);
                      RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
                          .then((socket) {
                        socket.send(message.toBytes(), destination, port);
                      });
                    },
                    child: const Text("Column 4")),
              ],
            )
          ],
        ),
      ),
    );
  }
}
