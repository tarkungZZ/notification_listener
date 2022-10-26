import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: NotificationsLog(),
    );
  }
}

class NotificationsLog extends StatefulWidget {
  @override
  _NotificationsLogState createState() => _NotificationsLogState();
}

class _NotificationsLogState extends State<NotificationsLog> {
  List<NotificationEvent> _log = [];
  bool started = false;
  bool _loading = false;

  ReceivePort port = ReceivePort();

  @override
  void initState() {
    initPlatformState();
    super.initState();
  }

  // we must use static method, to handle in background
  static void _callback(NotificationEvent evt) {
    print("send evt to ui: $evt");
    final SendPort send = IsolateNameServer.lookupPortByName("_listener_");
    if (send == null) print("can't find the sender");
    send?.send(evt);
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    NotificationsListener.initialize(callbackHandle: _callback);

    // this can fix restart<debug> can't handle error
    IsolateNameServer.removePortNameMapping("_listener_");
    IsolateNameServer.registerPortWithName(port.sendPort, "_listener_");
    port.listen((message) => onData(message));
    // don't use the default receivePort
    // NotificationsListener.receivePort.listen((evt) => onData(evt));

    var isR = await NotificationsListener.isRunning;
    print("""Service is ${!isR ? "not " : ""}aleary running""");

    setState(() {
      started = isR;
    });
  }

  void onData(NotificationEvent event) async {
    setState(() {
      _log.add(event);
    });
    print(event.toString());

    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      //debugPrint('Running on ${androidInfo.model}');

      Map<String, dynamic> body = {
        'bid': '0',
        'web': 'ufa',
        'deviceID': androidInfo.model,
        'address': event.title,
        'message': event.text,
        'date': event.createAt.toString().substring(0, 19)
      };
      String jsonBody = json.encode(body);

      await http.post(Uri.parse('http://192.168.1.99:9999/line/line'),
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
          },
          encoding: Encoding.getByName('utf-8'),
          body: jsonBody);
    } catch (e) {
      print(e);
    }
  }

  void startListening() async {
    print("start listening");
    setState(() {
      _loading = true;
    });
    var hasPermission = await NotificationsListener.hasPermission;
    if (!hasPermission) {
      print("no permission, so open settings");
      NotificationsListener.openPermissionSettings();
      return;
    }

    var isR = await NotificationsListener.isRunning;

    if (!isR) {
      await NotificationsListener.startService(
          foreground: false,
          title: "Listener Running",
          description: "Welcome to having me");
    }

    setState(() {
      started = true;
      _loading = false;
    });
  }

  void stopListening() async {
    print("stop listening");

    setState(() {
      _loading = true;
    });

    await NotificationsListener.stopService();

    setState(() {
      started = false;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LINE UFA BID 0'),
        actions: [
          IconButton(
              onPressed: () {
                print("TODO:");
              },
              icon: Icon(Icons.settings))
        ],
      ),
      body: Center(
          child: ListView.builder(
              itemCount: _log.length,
              reverse: true,
              itemBuilder: (BuildContext context, int idx) {
                final entry = _log[idx];
                return ListTile(
                    onTap: () {
                      entry.tap();
                    },
                    // trailing:
                    //     entry.hasLargeIcon ? Image.memory(entry.largeIcon, width: 80, height: 80) :
                    //       Text(entry.packageName.toString().split('.').last),
                    title: Container(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Time : " +
                              entry.createAt.toString().substring(0, 19)),
                          Text("Sender : " + entry.title ?? "<<no title>>"),
                          Text("Message : " + entry.text ?? "<<no text>>"),
                          Text("------------")
                          // Row(
                          //     children: entry.actions.map((act) {
                          //   return TextButton(
                          //       onPressed: () {
                          //         // semantic is 1 means reply quick
                          //         if (act.semantic == 1) {
                          //           Map<String, dynamic> map = {};
                          //           act.inputs.forEach((e) {
                          //             print(
                          //                 "set inputs: ${e.label}<${e.resultKey}>");
                          //             map[e.resultKey] = "Auto reply from me";
                          //           });
                          //           act.postInputs(map);
                          //         } else {
                          //           // just tap
                          //           act.tap();
                          //         }
                          //       },
                          //       child: Text(act.title));
                          // }).toList()
                          //     // ..add(TextButton(
                          //     //     child: Text("Full"),
                          //     //     onPressed: () async {
                          //     //       try {
                          //     //         var data = await entry.getFull();
                          //     //         print("full notifaction: $data");
                          //     //       } catch (e) {
                          //     //         print(e);
                          //     //       }
                          //     //     })),
                          //     ),
                        ],
                      ),
                    ));
              })),
      floatingActionButton: FloatingActionButton(
        onPressed: started ? stopListening : startListening,
        tooltip: 'Start/Stop sensing',
        child: _loading
            ? Icon(Icons.close)
            : (started ? Icon(Icons.stop) : Icon(Icons.play_arrow)),
      ),
    );
  }
}
