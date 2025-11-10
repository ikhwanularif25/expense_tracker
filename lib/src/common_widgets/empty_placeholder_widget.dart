import 'package:flutter/material.dart';

class EmptyPlaceholderWidget extends StatelessWidget {
  final String message;
  final IconData? iconData; 

  const EmptyPlaceholderWidget({
    super.key,
    required this.message,
    this.iconData = Icons.inbox_rounded, 
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: 96,
              color: Theme.of(
                context,
              ).colorScheme.secondary.withAlpha(100), 
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
