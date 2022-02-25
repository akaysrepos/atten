import 'dart:io';

import 'package:atten/locator.dart';
import 'package:atten/pages/employeehome.dart';
import 'package:atten/pages/employerhome.dart';
import 'package:atten/pages/login.dart';
import 'package:atten/services/camera.service.dart';
import 'package:atten/services/face_detector_service.dart';
import 'package:atten/services/ml_service.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

class SignUp extends StatefulWidget {
  const SignUp({
    Key? key,
  }) : super(key: key);

  @override
  _SignUpState createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  bool image = false;
  String label = "";
  String dropdownValue = "Employer";
  List<String> spinnerItems = ['Employer', 'Employee'];
  MLService _mlService = locator<MLService>();
  FaceDetectorService _mlKitService = locator<FaceDetectorService>();

  TextEditingController mobileController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool isCameraReady = false;
  bool verifing = false;
  bool showCapturedPhoto = false;
  var ImagePath;
  late Face faceDetected;
  late Size imageSize;
  List data = [];

  bool _detectingFaces = false;
  bool pictureTaked = false;

  // switchs when the user press the camera
  bool _saving = false;

  final FaceDetectorService _faceDetectorService =
      locator<FaceDetectorService>();
  final CameraService _cameraService = locator<CameraService>();

  GlobalKey<ScaffoldState> sKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _mlService.loadModel();
    _faceDetectorService.initialize();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraService.cameraController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    // final firstCamera = cameras[1];
    var cameraDescription = cameras.firstWhere(
      (CameraDescription camera) =>
          camera.lensDirection == CameraLensDirection.front,
    );
    // _controller = CameraController(firstCamera, ResolutionPreset.high);
    _initializeControllerFuture =
        _cameraService.startService(cameraDescription);
    await _initializeControllerFuture;

    if (!mounted) {
      return;
    }
    setState(() {
      isCameraReady = true;
    });
    _frameFaces();
  }

  _frameFaces() {
    imageSize = _cameraService.getImageSize();

    _cameraService.cameraController.startImageStream((image) async {
      if (_cameraService.cameraController != null) {
        if (_detectingFaces) return;

        _detectingFaces = true;

        try {
          List<Face> faces =
              await _faceDetectorService.getFacesFromImage(image);

          if (faces.length > 0) {
            // setState(() {
            //   print("has a face");
            //   sKey.currentState!
            //       .showSnackBar(const SnackBar(content: Text("Detected!")));
            faceDetected = faces[0];
            // });

            if (_saving) {
              setState(() async {
                data =
                    await _mlService.setCurrentPrediction(image, faceDetected);
              });
              setState(() {
                _saving = false;
              });
            }
          }
          //  else {
          //   setState(() {
          //     faceDetected = null;
          //   });
          // }

          _detectingFaces = false;
        } catch (e) {
          print(e);
          _detectingFaces = false;
        }
      }
    });
  }

  checkInFirestore() async {
    String mobile = mobileController.text;
    firestore
        .collection("atten")
        .doc("users")
        .collection(mobile)
        .doc("details")
        .get()
        .then((value) async {
      if (value.exists) {
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => const Login()));
      } else {
        if (data.isNotEmpty && dropdownValue.isNotEmpty) {
          setState(() {
            verifing = true;
          });
          verify(mobileController.text, dropdownValue);
        } else {
          sKey.currentState!.showSnackBar(
              const SnackBar(content: Text("Fill all the fields first!")));
        }
      }
    });
  }

  verify(String mobile, String type) async {
    _auth.verifyPhoneNumber(
        phoneNumber: mobile,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_credential) async {
          setState(() {
            verifing = false;
          });
          firestore
              .collection("atten")
              .doc("users")
              .collection(mobile)
              .doc("details")
              .set({"type": dropdownValue, "data": data},
                  SetOptions(merge: true)).then((value) {
            if (type == "Employee") {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => EmployeeHome(
                            number: mobile,
                            name: "Me",
                          )));
            } else if (type == "Employer") {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => EmployerHome(number: mobile)));
            }
          });
        },
        codeSent: (String verificationId, [int? forceResendingToken]) {
          setState(() {
            verifing = false;
          });
          showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                    title: const Text("Enter SMS Code"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextFormField(
                          controller: _codeController,
                        ),
                      ],
                    ),
                    actions: <Widget>[
                      FlatButton(
                        child: const Text("Done"),
                        textColor: Colors.white,
                        color: Colors.redAccent,
                        onPressed: () {
                          String smsCode = _codeController.text.trim();

                          var _credential = PhoneAuthProvider.credential(
                              verificationId: verificationId, smsCode: smsCode);
                          _auth
                              .signInWithCredential(_credential)
                              .then((result) {
                            firestore
                                .collection("atten")
                                .doc("users")
                                .collection(mobile)
                                .doc("details")
                                .set({"type": dropdownValue, "data": data},
                                    SetOptions(merge: true)).then((value) {
                              logUser(mobile, type);
                              if (type == "Employee") {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => EmployeeHome(
                                              number: mobile,
                                              name: "Me",
                                            )));
                              } else if (type == "Employer") {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            EmployerHome(number: mobile)));
                              }
                            });
                          }).catchError((e) {
                            print(e);
                          });
                        },
                      )
                    ],
                  ));
        },
        verificationFailed: (FirebaseAuthException error) {},
        codeAutoRetrievalTimeout: (String verificationId) {});
  }

  logUser(String number, String type) async {
    Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
    final SharedPreferences prefs = await _prefs;
    await prefs.setBool("isLoggedIn", true);
    await prefs.setString("number", number);
    await prefs.setString("type", type);
  }

  void onCaptureButtonPressed() async {
    //on camera button press
    if (faceDetected != null) {
      try {
        // final path = p.join(
        //   (await getTemporaryDirectory()).path, //Temporary path
        //   '${DateTime.now()}.png',
        // );
        // ImagePath = path;
        _saving = true;
        await Future.delayed(const Duration(milliseconds: 500));
        await _cameraService.cameraController.stopImageStream();
        await Future.delayed(const Duration(milliseconds: 200));
        XFile file = await _cameraService.cameraController.takePicture();
        ImagePath = file.path; //take photo

        setState(() {
          _saving = true;
          showCapturedPhoto = true;
        });
      } catch (e) {
        print(e);
      }
    } else {
      showDialog(
        context: context,
        builder: (context) {
          return const AlertDialog(
            content: Text('No face detected!'),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    return Scaffold(
        key: sKey,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            (!image && isCameraReady)
                ? FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        // If the Future is complete, display the preview.
                        return Transform.scale(
                          scale: 1.0,
                          child: AspectRatio(
                            aspectRatio:
                                MediaQuery.of(context).size.aspectRatio,
                            child: OverflowBox(
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.fitHeight,
                                child: Container(
                                  width: MediaQuery.of(context).size.width,
                                  height: MediaQuery.of(context).size.width *
                                      _cameraService
                                          .cameraController.value.aspectRatio,
                                  child: Stack(
                                    alignment: Alignment.bottomCenter,
                                    fit: StackFit.expand,
                                    children: <Widget>[
                                      showCapturedPhoto
                                          ? Center(
                                              child:
                                                  Image.file(File(ImagePath)))
                                          : CameraPreview(
                                              _cameraService.cameraController),
                                      verifing
                                          ? const CircularProgressIndicator()
                                          : Container(),
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextFormField(
                                              keyboardType: TextInputType.phone,
                                              textAlign: TextAlign.center,
                                              controller: mobileController,
                                              decoration: const InputDecoration(
                                                  hintText: "Enter Number"),
                                            ),
                                            DropdownButton<String>(
                                              value: dropdownValue,
                                              icon: const Icon(
                                                  Icons.arrow_drop_down),
                                              iconSize: 24,
                                              elevation: 16,
                                              style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 18),
                                              underline: Container(
                                                height: 2,
                                                color: Colors.deepPurpleAccent,
                                              ),
                                              onChanged: (data) {
                                                setState(() {
                                                  dropdownValue = data!;
                                                });
                                              },
                                              items: spinnerItems.map<
                                                      DropdownMenuItem<String>>(
                                                  (String value) {
                                                return DropdownMenuItem<String>(
                                                  value: value,
                                                  child: Text(value),
                                                );
                                              }).toList(),
                                            ),
                                            data.isEmpty
                                                ? ElevatedButton(
                                                    onPressed:
                                                        onCaptureButtonPressed,
                                                    child: const Text(
                                                        "Add Face data"))
                                                : Container(),
                                            data.isNotEmpty
                                                ? ElevatedButton(
                                                    onPressed: checkInFirestore,
                                                    child:
                                                        const Text("Sign Up"))
                                                : Container(),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      } else {
                        return const Center(
                            child:
                                CircularProgressIndicator()); // Otherwise, display a loading indicator.
                      }
                    },
                  )
                : Container(),
          ],
        ));
  }
}
