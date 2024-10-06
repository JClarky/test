import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:developer';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info/device_info.dart';
import 'package:collection/collection.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  FlutterBluePlus.setOptions(restoreState: true);
  runApp(const MyApp());
  //test
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
  List<BluetoothDevice> _devices = [];

  /*static const platform = MethodChannel('samples.flutter.dev/bt');

  Future<void> _setConnection() async {
    try {
      final result = await platform.invokeMethod<int>('btInit');
      log("Got");
    } on PlatformException {
      log("Failure");
    }
  }*/

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
    return File('$path/remoteId.txt');
  }

  Future<void> attemptBonding(BluetoothDevice device) async {
    // get the device UUID
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String deviceUUID;

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceUUID = androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceUUID = iosInfo.identifierForVendor ?? '';
      } else {
        print('Unsupported platform');
        return;
      }
    } catch (e) {
      print('Error getting device UUID: $e');
      return;
    }

    // convert the UUID to a byte array
    List<int> uuidBytes = deviceUUID.codeUnits;

    // function to match the UUID ignoring the first four characters (device name)
    bool matchUUID(String characteristicUUID, String targetUUID) {
      return characteristicUUID.substring(4).toLowerCase() ==
          targetUUID.substring(4).toLowerCase();
    }

    // discover services and characteristics
    List<BluetoothService> services;
    try {
      services = await device.discoverServices();
    } catch (e) {
      print('Error discovering services: $e');
      return;
    }

    // find the bonding characteristic
    BluetoothCharacteristic? bondingCharacteristic;
    for (var service in services) {
      bondingCharacteristic = service.characteristics.firstWhereOrNull((c) =>
          matchUUID(c.uuid.toString(),
              'UUID of your device that returns bonding characteristic'));
      if (bondingCharacteristic != null) break;
    }

    if (bondingCharacteristic != null) {
      try {
        print('Attempting to write to bonding characteristic...');
        await bondingCharacteristic.write(uuidBytes, withoutResponse: true);
        print('Written UUID to bonding characteristic.');
      } catch (e) {
        print('Error writing to bonding characteristic: $e');
        return;
      }
    } else {
      print('Bonding characteristic not found');
      return;
    }

    // check bonding status
    BluetoothCharacteristic? bondingStatusCharacteristic;
    for (var service in services) {
      bondingStatusCharacteristic = service.characteristics.firstWhereOrNull(
          (c) => matchUUID(c.uuid.toString(),
              'UUID of your device that returns bonding status characteristic'));
      if (bondingStatusCharacteristic != null) break;
    }

    if (bondingStatusCharacteristic != null) {
      try {
        await Future.delayed(const Duration(
            seconds: 1)); // add a delay to ensure the bonding is processed
        List<int> bondingStatus = await bondingStatusCharacteristic.read();
        print('Bonding status value: $bondingStatus');
        if (bondingStatus.isNotEmpty && bondingStatus[0] == 1) {
          print('Bonding successful.');
        } else {
          print('Bonding failed or not recognized by the device.');
        }
      } catch (e) {
        print('Error reading bonding status: $e');
      }
    } else {
      print('Bonding status characteristic not found');
    }
  }

  void printChar(BluetoothCharacteristic c) async {
    if (c.properties.read) {
      List<int> value = await c.read();
      print("Char:");
      print(value);
      try {
        await c.write([0]);
      } catch (e) {
        print("fail write");
        print(e);
      }
    }
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
    file.writeAsString(dev.remoteId.toString());
    //dev.cancelWhenDisconnected(subscription, delayed: true, next: true);
    // Note: You must call discoverServices after every re-connection!
    List<BluetoothService> services = await dev.discoverServices();
    attemptBonding(dev);

    /*services.forEach((service) {
      log("Service:");
      print(service.characteristics);

      var characteristics = service.characteristics;
      for (BluetoothCharacteristic c in characteristics) {
        printChar(c);
      }
    });*/
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
      final file = await _localFile;

      final String remoteId = await file.readAsString();
      log("ID FOUND:$remoteId");
      var dev = BluetoothDevice.fromId(remoteId);
      log("Got device from ID");
      await dev.connect(autoConnect: true, mtu: null);
      dev.connectionState.listen((BluetoothConnectionState state) async {
        if (state == BluetoothConnectionState.disconnected) {
          log("Disconnect occured, setting autoconnect here");
          await dev.connect(autoConnect: true, mtu: null);
          print(
              "${dev.disconnectReason?.code} ${dev.disconnectReason?.description}");
        }
      });
      return;
    } catch (e) {
      log("ID failure $e");
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

  void _disconnect() async {
    log("Disconnecting all devices and clearing remote id's");
    final file = await _localFile;
    file.writeAsStringSync("");
    List<BluetoothDevice> devices = FlutterBluePlus.connectedDevices;
    for (var dev in devices) {
      dev.disconnect();
    }
  }

  void _incrementCounter() {
    log("Increment counter");
    setState(() {
      _counter++;
    });

    //_setConnection();

    List<BluetoothDevice> devs = FlutterBluePlus.connectedDevices;
    for (var d in devs) {
      print(d);
    }
    setState(() {
      _devices = devs;
    });
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
            const Text('You have pushed the refresh button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            const Text('Connected Bluetooth Devices:'),
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_devices[index].name),
                    subtitle: Text(_devices[index].id.toString()),
                  );
                },
              ),
            ),
            ElevatedButton(
                onPressed: startScan, child: const Text('Rescan for device')),
            ElevatedButton(
              onPressed: _disconnect,
              child: const Text('Disconnect All Devices'),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.cached_outlined),
      ),
    );
  }
}
