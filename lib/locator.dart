import 'package:flutter_subscriptions/core/services/subscription_service.dart';
import 'package:get_it/get_it.dart';

GetIt locator = GetIt.instance;

 setupLocator() {

  locator.registerLazySingleton(() => SubscriptionService());
}
