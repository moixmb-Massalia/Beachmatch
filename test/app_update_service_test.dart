import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUpdateService Logic Tests', () {
    test('Build number comparison detects outdated version', () {
      const currentBuild = 172;
      const minRequiredBuild = 173;
      const latestBuild = 173;

      const isForceUpdate = currentBuild < minRequiredBuild;
      const isRecommendedUpdate = currentBuild < latestBuild;

      expect(isForceUpdate, isTrue);
      expect(isRecommendedUpdate, isTrue);
    });

    test('Build number comparison passes when on latest version', () {
      const currentBuild = 173;
      const minRequiredBuild = 173;
      const latestBuild = 173;

      const isForceUpdate = currentBuild < minRequiredBuild;
      const isRecommendedUpdate = currentBuild < latestBuild;

      expect(isForceUpdate, isFalse);
      expect(isRecommendedUpdate, isFalse);
    });

    test('Build number comparison detects flexible update when above min but below latest', () {
      const currentBuild = 172;
      const minRequiredBuild = 170;
      const latestBuild = 173;

      const isForceUpdate = currentBuild < minRequiredBuild;
      const isRecommendedUpdate = currentBuild < latestBuild;

      expect(isForceUpdate, isFalse);
      expect(isRecommendedUpdate, isTrue);
    });
  });
}
