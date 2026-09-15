import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Central sound-effect service for the Social Study app.
///
/// Wraps a single [AudioPlayer] — one sound plays at a time so SFX
/// never pile up. Exposes a [SoundService.instance] static accessor so
/// top-level UI helpers (e.g. [showLevelUpBurst]) can reach it without
/// needing a [WidgetRef] or [BuildContext].
///
/// Sounds are mapped to app events:
///
/// | Method              | File                                          | Event                  |
/// |---------------------|-----------------------------------------------|------------------------|
/// | [playCorrectAnswer] | meldix-success-340660.mp3                     | Correct answer         |
/// | [playLevelUp]       | universfield-level-up-06-370051.mp3           | Level-up overlay       |
/// | [playBadgeUnlock]   | latent-rick-achievement-badge-pop-sound-2...  | Badge unlock sheet     |
/// | [playNotification]  | universfield-new-notification-051-494246.mp3  | Foreground notification|
///
/// All play calls are fire-and-forget (`unawaited`) and swallow
/// errors so a missing audio file or platform issue can never crash
/// the app.
class SoundService {
  SoundService._();

  // ── Static singleton ──────────────────────────────────────────────

  static SoundService? _instance;

  /// The global singleton. Initialised once on first access.
  static SoundService get instance {
    _instance ??= SoundService._();
    return _instance!;
  }

  // ── Internal player ───────────────────────────────────────────────

  final AudioPlayer _player = AudioPlayer();

  // ── Asset paths ───────────────────────────────────────────────────

  static const _correctAnswer = 'audio/meldix-success-340660.mp3';
  static const _wrongAnswer = 'audio/universfield-wrong-answer-129254.mp3';
  static const _levelUp = 'audio/universfield-level-up-06-370051.mp3';
  static const _badgeUnlock =
      'audio/latent-rick-achievement-badge-pop-sound-2-547865.mp3';
  static const _notification =
      'audio/universfield-new-notification-051-494246.mp3';
  static const _cardFlip = 'audio/u_vdwj1c20kz-coin-collision-sound-342335.mp3';

  // ── Public API ────────────────────────────────────────────────────

  /// Play the success chime when the student answers correctly.
  void playCorrectAnswer() => _play(_correctAnswer);

  /// Play the wrong-answer sound when the student answers incorrectly.
  void playWrongAnswer() => _play(_wrongAnswer);

  /// Play the level-up fanfare during the confetti overlay.
  void playLevelUp() => _play(_levelUp);

  /// Play the badge pop when a badge unlock sheet opens.
  void playBadgeUnlock() => _play(_badgeUnlock);

  /// Play the notification ping for foreground push messages.
  void playNotification() => _play(_notification);

  /// Play a subtle tick when a flashcard is flipped to reveal the answer.
  void playCardFlip() => _play(_cardFlip);

  /// Release the underlying [AudioPlayer]. Called on app exit; in
  /// practice the OS reclaims resources anyway, but this is clean.
  Future<void> dispose() async {
    await _player.dispose();
    _instance = null;
  }

  // ── Internal ──────────────────────────────────────────────────────

  void _play(String assetPath) {
    _player.play(AssetSource(assetPath)).catchError((Object e) {
      // Never crash — audio is enhancement, not critical path.
      debugPrint('SoundService: failed to play $assetPath — $e');
    });
  }
}
