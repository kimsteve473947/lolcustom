import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

class EnvConfig {
  // API Keys (optional - for future features)
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'dummy_google_maps_key';
  static String get stripePublishableKey => dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? 'dummy_stripe_publishable_key';
  static String get stripeSecretKey => dotenv.env['STRIPE_SECRET_KEY'] ?? 'dummy_stripe_secret_key';
  
  // App Configuration
  static String get appName => dotenv.env['APP_NAME'] ?? 'LOL 내전 매니저';
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  static String get appBuild => dotenv.env['APP_BUILD'] ?? '1';
  
  // Environment settings
  static bool get isProduction => dotenv.env['ENV'] == 'production';
  static bool get isDevelopment => dotenv.env['ENV'] != 'production';
  
  // Initialize environment variables (optional)
  static Future<void> init() async {
    try {
      // Try to load .env file if it exists (for development)
      await dotenv.load(fileName: '.env');
      print('✅ Environment variables loaded from .env file');
    } catch (e) {
      // .env file not found or not accessible - use default values
      print('ℹ️ .env file not found, using default configuration');
      
      // Set default values for development
      dotenv.env['APP_NAME'] = 'LOL 내전 매니저';
      dotenv.env['APP_VERSION'] = '1.0.0';
      dotenv.env['APP_BUILD'] = '1';
      dotenv.env['ENV'] = 'development';
      
      print('✅ Default environment configuration loaded');
    }
  }
} 