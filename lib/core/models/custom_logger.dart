import 'package:flutter_subscriptions/core/models/custom_log_output.dart';
import 'package:flutter_subscriptions/core/models/custom_log_printer.dart';
import 'package:logger/logger.dart';

class CustomLogger extends Logger {
  final String className;

  CustomLogger({required this.className})
    : super(
        output: CustomLogOutput(),
        printer: CustomLogPrinter(className: className),
      );
}


