import 'package:freezed_annotation/freezed_annotation.dart';

part 'tenant.freezed.dart';
part 'tenant.g.dart';

enum TenantType { family, school }

@freezed
class Tenant with _$Tenant {
  const factory Tenant({
    required String id,
    required String name,
    required TenantType type,
    required String adminUserId,
    required DateTime createdAt,
    @Default(false) bool isDeleted,
  }) = _Tenant;

  factory Tenant.fromJson(Map<String, dynamic> json) => _$TenantFromJson(json);
}
