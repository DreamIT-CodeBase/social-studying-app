// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'questions_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$questionsRepositoryHash() =>
    r'240aed85ae7ab422fc84716708b5fa4414433faf';

/// Selects between the demo (in-process state machine) and the real
/// (Dio → backend) implementation based on the authenticated user.
///
/// Mirrors the documents repository's selection logic so the demo
/// user (`usr_demo_001` / `demo@socialstudyapp.com`) gets the offline
/// flow and any other user is assumed to be authenticated against
/// the real API.
///
/// Copied from [questionsRepository].
@ProviderFor(questionsRepository)
final questionsRepositoryProvider = Provider<QuestionsRepository>.internal(
  questionsRepository,
  name: r'questionsRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$questionsRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef QuestionsRepositoryRef = ProviderRef<QuestionsRepository>;
