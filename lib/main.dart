import 'package:flutter/material.dart';
import 'package:flutter_subscriptions/locator.dart';
import 'package:flutter_subscriptions/ui/subscription/subscription_screen.dart';

void main() async{
    await setupLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home:  SubscriptionScreen(),
    );
  }
}
