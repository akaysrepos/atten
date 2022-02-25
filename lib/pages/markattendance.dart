import 'dart:io';
import 'dart:math' as math;
import 'package:atten/locator.dart';
import 'package:atten/pages/login.dart';
import 'package:atten/services/camera.service.dart';
import 'package:atten/services/face_detector_service.dart';
import 'package:atten/services/ml_service.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:intl/intl.dart';

class MarkAttendance extends StatefulWidget {
  const MarkAttendance({Key? key, required this.number}) : super(key: key);
  final String number;

  @override
  _MarkAttendanceState createState() => _MarkAttendanceState();
}

class _MarkAttendanceState extends State<MarkAttendance> {
  DateTime now = DateTime.now();
  bool image = false;
  String label = "";
  String dropdownValue = "Employer";
  List<String> spinnerItems = ['Employer', 'Employee'];
  final MLService _mlService = locator<MLService>();

  TextEditingController mobileController = TextEditingController();
  late Future<void> _initializeControllerFuture;
  bool isCameraReady = false;
  bool showCapturedPhoto = false;
  var ImagePath;
  late Face faceDetected;
  late Size imageSize;
  List data = [];
  List faceData = [];

  bool _detectingFaces = false;

  // switchs when the user press the camera
  bool _saving = false;

  final FaceDetectorService _faceDetectorService =
      locator<FaceDetectorService>();
  final CameraService _cameraService = locator<CameraService>();

  GlobalKey<ScaffoldState> sKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    isMarked();
    _mlService.loadModel();
    _faceDetectorService.initialize();
    getFaceData();
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
                faceData =
                    await _mlService.setCurrentPrediction(image, faceDetected);
                // sKey.currentState!.showSnackBar(
                //     SnackBar(content: Text(faceData.length.toString())));
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

  isMarked() async {
    String month = DateFormat.MMMM().format(now);
    firestore
        .collection("atten")
        .doc("users")
        .collection(widget.number)
        .doc(month)
        .get()
        .then((value) async {
      if (value.exists) {
        if (value['${now.day}'].toString().split("_")[0] == "present") {
          sKey.currentState!.showSnackBar(
              const SnackBar(content: Text("Already punched in!")));
          await Future.delayed(const Duration(milliseconds: 3000));
          Navigator.pop(context);
        }
      }
    });
  }

  getFaceData() async {
    firestore
        .collection("atten")
        .doc("users")
        .collection(widget.number)
        .doc("details")
        .get()
        .then((value) async {
      if (value.exists) {
        setState(() {
          data.addAll(value['data']);
          // sKey.currentState!
          //     .showSnackBar(SnackBar(content: Text(data.length.toString())));
        });
      }
    });
  }

  verify() async {
    bool face = await _mlService.searchResult(data, faceData);
    if (face) {
      // sKey.currentState!.showSnackBar(SnackBar(content: Text(face.toString())));
      mark();
    } else {
      sKey.currentState!
          .showSnackBar(const SnackBar(content: Text('Try Again')));
    }
  }

  mark() async {
    String month = DateFormat.MMMM().format(now);
    firestore
        .collection("atten")
        .doc("users")
        .collection(widget.number)
        .doc(month)
        .set({"${now.day}": "present_${now.toString()}_"},
            SetOptions(merge: true)).then((value) async {
      sKey.currentState!
          .showSnackBar(const SnackBar(content: Text("Punched IN!")));
      await Future.delayed(const Duration(milliseconds: 3000));
      Navigator.pop(context);
    });
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
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            !showCapturedPhoto
                                                ? ElevatedButton(
                                                    onPressed:
                                                        onCaptureButtonPressed,
                                                    child: const Text(
                                                        "Add Face data"))
                                                : Container(),
                                            showCapturedPhoto
                                                ? ElevatedButton(
                                                    onPressed: verify,
                                                    child:
                                                        const Text("Punch In"))
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
