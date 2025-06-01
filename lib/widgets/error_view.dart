import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  
  const ErrorView({
    Key? key,
    required this.message,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 64.0,
            ),
            const SizedBox(height: 16.0),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.0,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24.0),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 