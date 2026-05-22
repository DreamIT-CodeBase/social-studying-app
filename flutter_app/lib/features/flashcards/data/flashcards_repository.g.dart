// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcards_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$flashcardsRepositoryHash() =>
    r'd2fbac9f9f35baf8c707b17b21295dd310a91387';

/// Selects between the demo (in-process state machine) and the real
/// (Dio → backend) implementation based on the authenticated user.
///
/// Mirrors the questions repository's selection logic so the demo
/// user (`usr_demo_001` / `demo@socialstudyapp.com`) gets the offline
/// flow and any other user is assumed to be authenticated against
/// the real API.
///
/// Copied from [flashcardsRepository].
@ProviderFor(flashcardsRepository)
final flashcardsRepositoryProvider = Provider<FlashcardsRepository>.internal(
  flashcardsRepository,
  name: r'flashcardsRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$flashcardsRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FlashcardsRepositoryRef = ProviderRef<FlashcardsRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
