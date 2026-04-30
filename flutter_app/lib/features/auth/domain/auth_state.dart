import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:social_study_app/shared/models/user.dart';

part 'auth_state.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.authenticated({required User user}) = _Authenticated;
}
