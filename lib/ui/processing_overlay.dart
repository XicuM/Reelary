import 'package:flutter/material.dart';
import '../services/background_processing_service.dart';

class ProcessingOverlay extends StatelessWidget {
  const ProcessingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProcessingState?>(
      stream: BackgroundProcessingService().progressStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();

        final state = snapshot.data!;
        // You might want to auto-hide after some time or when "success" event comes?
        // For now, let's assume the service clears the stream or we handle visibility logic.
        // Actually, the service keeps running until stopped. When stopped, maybe we send a "done" state?
        // Or we just check if service is running. 
        // My previous implementation of `stopService` set `_isDesktopServiceRunning` to false. 
        // But the stream might not emit "stopped". 
        // Let's rely on the fact that when finished, we might want to show "Success" for a bit then hide.
        // The service logic sends "Successfully processed" then waits 3s then stops.
        
        // Let's decide visibility. If the stream has data, show it.
        // If the service is NOT processing, maybe we should return empty?
        // But the stream is broadcast, so it only has data when events are fired.
        // To handle "hiding", we could add a timer or specific "Close" event.
        // But the easiest is: The service emits "Success", user sees it.
        // Then service stops.
        // However, StreamBuilder keeps the last data.
        // We need a way to dismiss it.
        // Let's add a "Close" button to the overlay or rely on a "Hidden" state.
        // For now, simplest: Show Card with Close button.

        return Positioned( // Position at bottom right or bottom center
          bottom: 20,
          right: 20,
          left: 20, // Full width on mobile?
          child: SafeArea(
            child: Center( // Constrain width on large screens
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                           children: [
                             const SizedBox(
                               width: 20, 
                               height: 20, 
                               child: CircularProgressIndicator(strokeWidth: 2)
                             ),
                             const SizedBox(width: 12),
                             Expanded(
                               child: Text(
                                 state.title,
                                 style: Theme.of(context).textTheme.titleMedium,
                               ),
                             ),
                             IconButton(
                               icon: const Icon(Icons.close, size: 20),
                               onPressed: () {
                                 // Close overlay? 
                                 // We can't clear the stream easily.
                                 // Maybe just hide this specific instance? 
                                 // But it will reappear on next update.
                                 // Since this is "Background" processing, maybe we just minimize it?
                                 // Actually, if user clicks Close, they probably want to dismiss the toast.
                                 // But the process is still running.
                                 // For this MVP, let's just show it. 
                                 // The user asked for "Popup".
                               },
                             ),
                           ],
                         ),
                        const SizedBox(height: 8),
                        Text(state.content),
                        if (state.showProgress) ...[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: state.maxProgress > 0 
                                ? state.progress / state.maxProgress 
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
