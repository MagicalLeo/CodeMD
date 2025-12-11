import 'package:flutter_riverpod/flutter_riverpod.dart';

class TextScaleNotifier extends StateNotifier<double> {
  TextScaleNotifier() : super(1.0);

  void increaseTextScale() {
    if (state < 3.0) {
      state = (state + 0.2).clamp(0.5, 3.0);
    }
  }

  void decreaseTextScale() {
    if (state > 0.5) {
      state = (state - 0.2).clamp(0.5, 3.0);
    }
  }

  void resetTextScale() {
    state = 1.0;
  }
}

final textScaleProvider = StateNotifierProvider<TextScaleNotifier, double>((ref) {
  return TextScaleNotifier();
});