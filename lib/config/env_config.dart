import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

class EnvConfig {
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'dummy_google_maps_key';
  static String get stripePublishableKey => dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? 'dummy_stripe_publishable_key';
  static String get stripeSecretKey => dotenv.env['STRIPE_SECRET_KEY'] ?? 'dummy_stripe_secret_key';
  
  static String get appName => dotenv.env['APP_NAME'] ?? '스크림져드';
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  
  static bool get isProduction => dotenv.env['ENV'] == 'production';
  static bool get isDevelopment => dotenv.env['ENV'] != 'production';
  
  // Initialize environment variables
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
      print('Environment variables loaded successfully.');
    } catch (e) {
      print('Warning: .env file not found or could not be loaded. Using default values.');
      // Set default values for development
      dotenv.env['APP_NAME'] = '스크림져드';
      dotenv.env['APP_VERSION'] = '1.0.0';
      dotenv.env['ENV'] = 'development';
    }
  }
} 