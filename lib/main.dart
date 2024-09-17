import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:developer';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 169, 18, 18)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Bluetooth connection test'),
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

  static const platform = MethodChannel('samples.flutter.dev/bt');

  Future<void> _setConnection() async {
    try {
      final result = await platform.invokeMethod<int>('btInit');
      log("Got");
    } on PlatformException catch (e) {
      log("Failure");
    }
  }

  @override
  void initState() {
    super.initState();

    log("Init home page");

    if (FlutterBluePlus.isSupported == false) {
      log("Bluetooth not supported");
      return;
    } else {
      log("Bluetooth supported");
    }

    startScan();
  }

  // ···
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('remoteID.txt');
  }

  void connect(BluetoothDevice dev) async {
    log("Connecting");
    await dev.connect();

    var subscription =
        dev.connectionState.listen((BluetoothConnectionState state) async {
      if (state == BluetoothConnectionState.disconnected) {
        log("Disconnect occured, setting autoconnect");
        await dev.connect(autoConnect: true, mtu: null);
        print(
            "${dev.disconnectReason?.code} ${dev.disconnectReason?.description}");
      }
    });

    final file = await _localFile;

    // Write the file
    file.writeAsString('$dev.remoteId');

    //dev.cancelWhenDisconnected(subscription, delayed: true, next: true);
  }

/*
  void reconnect(BluetoothDevice dev) async {
    try {
      log("Reconnect automatically to the device!");
      await dev.connect(autoConnect: true, mtu:null);
      await dev.connectionState.where((val) => val == BluetoothConnectionState.connected).first;
      
    } catch (e) {
      log("Reconnection failed: $e");
    }
  }
*/
  void startScan() async {
    try {
      final String remoteId = await File('/remoteId.txt').readAsString();
      log("ID FOUND:$remoteId");
      var device = BluetoothDevice.fromId(remoteId);
      await device.connect(autoConnect: true);
      return;
    } catch (e) {
      log("ID failure");
    }

    log("Start initial scan");
    var subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          ScanResult r = results.last; // the most recently found devices
          log('${r.device.remoteId}: "${r.advertisementData.advName}" found!');

          if (r.advertisementData.advName == "Jayden Dev") {
            log("Device identified! Attempting to connect...");
            connect(r.device);
          }
        }
      },
      onError: (e) => print(e),
    );

    // cleanup: cancel subscription when scanning stops
    FlutterBluePlus.cancelWhenScanComplete(subscription);

    // Wait for Bluetooth enabled & permission granted
    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first;

    // Start scanning with timeout
    await FlutterBluePlus.startScan(
        withServices: [Guid("180D")], // match any of the specified services
        withNames: ["Jayden Dev"], // match specified names
        timeout: const Duration(seconds: 15));

    // Wait for scanning to stop
    await FlutterBluePlus.isScanning.where((val) => val == false).first;
  }

  void _incrementCounter() {
    log("Increment counter");
    setState(() {
      _counter++;
    });

    _setConnection();

    List<BluetoothDevice> devs = FlutterBluePlus.connectedDevices;
    for (var d in devs) {
      print(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
