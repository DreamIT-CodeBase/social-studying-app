// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$uploadControllerHash() => r'1c80634fd177a19457b78f2f086ef2c0078a3bb9';

/// Encapsulates the "pick a file → POST it → return the new doc" flow.
///
/// Why a controller instead of doing this inline in the screen
/// ------------------------------------------------------------
/// - The flow has three steps (pick, upload, navigate-or-error).
/// - Each step has its own failure mode the UI needs to react to
///   (cancelled picker, empty file, unsupported type, transport error).
/// - Tests can drive `pickAndUpload` with an injected file picker,
///   skipping the platform plugin entirely.
///
/// Copied from [UploadController].
@ProviderFor(UploadController)
final uploadControllerProvider = AutoDisposeNotifierProvider<UploadController,
    AsyncValue<Document?>>.internal(
  UploadController.new,
  name: r'uploadControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$uploadControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UploadController = AutoDisposeNotifier<AsyncValue<Document?>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
