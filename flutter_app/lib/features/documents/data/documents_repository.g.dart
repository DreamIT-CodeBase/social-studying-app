// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'documents_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$documentsRepositoryHash() =>
    r'26c0c1c28851ae341c2286f75470627011bebb8a';

/// Provider selects between the demo (in-process state machine) and the
/// real (Dio → backend) implementation based on the authenticated user.
///
/// The demo user signs in via `_MockAuthRepository` (see
/// [authRepositoryProvider]) and gets the demo documents flow so the app
/// is fully exercisable without a live backend. Any other user is
/// assumed to be authenticated against the real API.
///
/// Copied from [documentsRepository].
@ProviderFor(documentsRepository)
final documentsRepositoryProvider = Provider<DocumentsRepository>.internal(
  documentsRepository,
  name: r'documentsRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$documentsRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DocumentsRepositoryRef = ProviderRef<DocumentsRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
