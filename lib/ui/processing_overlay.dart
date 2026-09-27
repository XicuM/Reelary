import 'package:flutter/material.dart';
import '../services/background_processing_service.dart';

/// A single status line for an in-progress save. It hides when the service
/// emits null, which happens after success or failure.
class ProcessingOverlay extends StatelessWidget {
  const ProcessingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProcessingState?>(
      stream: BackgroundProcessingService().progressStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        return Positioned(
          left: 16,
          right: 88,
          bottom: 16,
          child: SafeArea(
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.inverseSurface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (state.showProgress) ...[
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onInverseSurface,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onInverseSurface,
                            ),
                          ),
                          if (state.content.isNotEmpty)
                            Text(
                              state.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onInverseSurface,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
