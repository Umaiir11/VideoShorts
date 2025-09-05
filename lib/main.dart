// lib/main.dart
import 'package:flutter/material.dart';
import 'package:fuzzintest/view.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: VideoFeedView(),
      theme: ThemeData(brightness: Brightness.dark),
    );
  }
}
