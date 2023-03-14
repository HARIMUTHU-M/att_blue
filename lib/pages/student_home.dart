// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:att_blue/components/checkmark.dart';
import 'package:att_blue/components/rippleEffect/ripple_animation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:get/get.dart';
// import 'package:flutter/animations.dart'

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int flag = 0;
  User? user = FirebaseAuth.instance.currentUser;
  late final String currEmail = user?.email.toString() ?? "null";

  final Strategy strategy = Strategy.P2P_STAR;
  Map<String, ConnectionInfo> endpointMap = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Student HomePage"),
          backgroundColor: Colors.deepPurple,
          actions: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: GestureDetector(
                onTap: () async {
                  await Nearby().stopDiscovery();
                  await FirebaseAuth.instance.signOut();
                  Get.offNamed('/login');
                },
                child: const Icon(Icons.logout_sharp),
              ),
            )
          ],
        ),
        body: Center(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              if (flag == 0)
                GestureDetector(
                  onTap: endPointFoundHandler,
                  child: Container(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          Column(
                            children: [
                              Container(
                                  padding: const EdgeInsets.all(20),
                                  margin: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.5),
                                        spreadRadius: 5,
                                        blurRadius: 7,
                                        offset: const Offset(
                                            0, 3), // changes position of shadow
                                      )
                                    ],
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(72),
                                  ),
                                  child: const Icon(Icons.bluetooth,
                                      size: 84, color: Colors.white)),
                            ],
                          ),
                          const Text(
                            "Tap to mark attendance",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                            ),
                          )
                        ],
                      )),
                )
              else if (flag == 1)
                RipplesAnimation(
                  onPressed: () async {
                    print("Ripple Animation");
                  },
                  child: const Text("data"),
                )
              else if (flag == 2)
                Center(
                  child: Column(
                    children: [
                      const CheckMarkPage(),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Text("Attendance recorded",
                              style: TextStyle(fontSize: 20)),
                        ],
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                          onPressed: () {
                            setState(() {
                              flag = 0;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor:
                                const Color.fromARGB(255, 243, 86, 33),
                            minimumSize: const Size(100, 60),
                            maximumSize: const Size(150, 60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32.0),
                            ),
                          ),
                          child: Row(
                            children: const [
                              SizedBox(width: 10),
                              Icon(Icons.logout, size: 26),
                              SizedBox(width: 10),
                              Text("Logout", style: TextStyle(fontSize: 18)),
                            ],
                          )),
                    ],
                  ),
                ),
            ])));
  }

  void endPointFoundHandler() async {
    if (!await Nearby().askLocationPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permissions not granted :(")));
    }

    if (!await Nearby().enableLocationServices()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enabling Location Service Failed :(")));
    }

    if (!await Nearby().checkBluetoothPermission()) {
      Nearby().askBluetoothPermission();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Bluetooth permissions not granted :(")));
    }

    setState(() {
      flag = 1;
    });

    try {
      bool a = await Nearby().startDiscovery(
        currEmail,
        strategy,
        onEndpointFound: (id, name, serviceId) async {
          print("endpoint found");
          print(name);
          print("Found endpoint: $id, $name, $serviceId");
          if (name.startsWith("TCE_Faculty")) {
            try {
              // add if not exists, else update
              DateTime now = DateTime.now();
              String formattedDate =
                  '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

              var db = FirebaseFirestore.instance
                  .collection(formattedDate)
                  .doc(name.replaceAll("TCE_Faculty ", ""));
              var data = await db.get();

              if (!data.exists) {
                db.set({
                  //append currmail to email key
                  'email': FieldValue.arrayUnion([currEmail]),
                });
              } else {
                db.update({
                  //append currmail to email key
                  'email': FieldValue.arrayUnion([currEmail]),
                });
              }
              await Nearby().stopDiscovery();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Attendance recorded!! :)")));
              setState(() {
                flag = 2;
              });
            } on FirebaseAuthException catch (e) {
              print("Error $e");
            } catch (e) {
              showSnackbar("Error: $e");
            }
          }
        },
        onEndpointLost: (id) {
          showSnackbar(
              "Lost discovered Endpoint: ${endpointMap[id]!.endpointName}, id $id");
        },
      );
      showSnackbar("DISCOVERING: $a");
    } catch (e) {
      showSnackbar(e);
    }
  }

  void showSnackbar(dynamic a) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(a.toString()),
    ));
  }

  void onConnectionInit(String id, ConnectionInfo info) {
    showModalBottomSheet(
      context: context,
      builder: (builder) {
        return Center(
          child: Column(
            children: <Widget>[
              Text("id: $id"),
              Text("Token: ${info.authenticationToken}"),
              Text("Name: ${info.endpointName}"),
              Text("Incoming: ${info.isIncomingConnection}"),
              ElevatedButton(
                child: const Text("Accept Connection"),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    endpointMap[id] = info;
                  });
                  Nearby().acceptConnection(
                    id,
                    onPayLoadRecieved: (endid, payload) async {},
                    onPayloadTransferUpdate: (endid, payloadTransferUpdate) {},
                  );
                },
              ),
              ElevatedButton(
                child: const Text("Reject Connection"),
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await Nearby().rejectConnection(id);
                  } catch (e) {
                    showSnackbar(e);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
