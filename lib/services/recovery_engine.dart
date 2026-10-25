class RecoveryAction {
  final String action;
  final Map<String, dynamic> params;
  final String description;

  RecoveryAction({
    required this.action,
    required this.params,
    required this.description,
  });
}

class RecoveryEngine {
  /// Diagnoses the failure and suggests a recovery action based on the last action and current screen dump.
  Future<RecoveryAction> diagnose(
    String lastFailedAction,
    String screenContent,
  ) async {
    final lowerScreen = screenContent.toLowerCase();

    // 1. Loading/spinner detected -> Wait
    if (lowerScreen.contains('loading') ||
        lowerScreen.contains('progress') ||
        lowerScreen.contains('spinner') ||
        lowerScreen.contains('wait')) {
      return RecoveryAction(
        action: 'wait',
        params: {},
        description: 'App seems to be loading, waiting...',
      );
    }

    // 2. A failed click usually means the row is off-screen or still loading.
    // Scroll down instead of pressing back, which used to bounce out of search
    // results and restart the whole flow.
    if (lastFailedAction == 'click_text' || lastFailedAction == 'click_at') {
      return RecoveryAction(
        action: 'scroll',
        params: {'direction': 'down'},
        description: 'Click missed, scrolling down to reveal the target.',
      );
    }

    // 3. Never press back from recovery. Going back exits the results or the
    // destination picker and makes the agent loop through the same screens.
    return RecoveryAction(
      action: 'wait',
      params: {},
      description: 'Waiting for the screen to settle before trying again.',
    );
  }
}
