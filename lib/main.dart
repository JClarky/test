import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:developer';

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
    setState(() {
      _counter++;
    });

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
