// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'taxonomy_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taxonomyRepositoryHash() =>
    r'ef826cea7a669a8cc50e167a543645c522565bc2';

/// Provider selects between demo and real impl based on the authenticated
/// user — same heuristic as ``documentsRepositoryProvider``.
///
/// Copied from [taxonomyRepository].
@ProviderFor(taxonomyRepository)
final taxonomyRepositoryProvider = Provider<TaxonomyRepository>.internal(
  taxonomyRepository,
  name: r'taxonomyRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$taxonomyRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TaxonomyRepositoryRef = ProviderRef<TaxonomyRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
