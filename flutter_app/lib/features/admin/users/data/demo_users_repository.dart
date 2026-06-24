import 'dart:async';

import 'package:social_study_app/features/admin/users/data/users_repository.dart';
import 'package:social_study_app/shared/models/user.dart';

/// Typed exceptions the UI branches on. Mirror the HTTP statuses the
/// real repository surfaces from the backend.

/// 409 from `POST /users/` — a user with this email already exists.
class UserEmailConflictException implements Exception {
  const UserEmailConflictException([
    this.message = 'A user with that email already exists',
  ]);
  final String message;
  @override
  String toString() => 'UserEmailConflictException: $message';
}

/// 404 — the user was deleted or never existed.
class UserNotFoundException implements Exception {
  const UserNotFoundException([this.message = 'User not found']);
  final String message;
  @override
  String toString() => 'UserNotFoundException: $message';
}

/// Offline, in-process implementation of workspace user management.
///
/// Backs the demo user so an offline dev can exercise the full roster /
/// invite / role-change flow without a live backend. Seeded with three
/// students enrolled in the demo workspace (`wsp_demo_001`).
///
/// State is in-process; restarting the app resets to the seed.
class DemoUsersRepository implements UsersRepository {
  DemoUsersRepository();

  final List<User> _users = [
    User(
      id: 'usr_demo_101',
      email: 'maya@socialstudyapp.com',
      displayName: 'Maya Chen',
      tenantId: 'ten_demo',
      role: UserRole.student,
      workspaceMemberships: const [
        WorkspaceMembership(
          workspaceId: 'wsp_demo_001',
          workspaceName: 'Demo Classroom',
          role: UserRole.student,
        ),
      ],
      createdAt: DateTime(2026, 4, 10),
    ),
    User(
      id: 'usr_demo_102',
      email: 'liam@socialstudyapp.com',
      displayName: 'Liam Park',
      tenantId: 'ten_demo',
      role: UserRole.student,
      workspaceMemberships: const [
        WorkspaceMembership(
          workspaceId: 'wsp_demo_001',
          workspaceName: 'Demo Classroom',
          role: UserRole.student,
        ),
      ],
      createdAt: DateTime(2026, 4, 12),
    ),
    User(
      id: 'usr_demo_103',
      email: 'sofia@socialstudyapp.com',
      displayName: 'Sofia Ramirez',
      tenantId: 'ten_demo',
      role: UserRole.workspaceAdmin,
      workspaceMemberships: const [
        WorkspaceMembership(
          workspaceId: 'wsp_demo_001',
          workspaceName: 'Demo Classroom',
          role: UserRole.workspaceAdmin,
        ),
      ],
      createdAt: DateTime(2026, 4, 9),
    ),
  ];

  int _idCounter = 103;

  @override
  Future<List<User>> listWorkspaceUsers(String workspaceId) async {
    await _latency();
    return List.unmodifiable(
      _users.where(
        (u) => u.workspaceMemberships
            .any((m) => m.workspaceId == workspaceId),
      ),
    );
  }

  @override
  Future<User> createUser({
    required String workspaceId,
    required String email,
    required String displayName,
    required UserRole role,
  }) async {
    await _latency();
    final trimmedEmail = email.trim().toLowerCase();
    if (_users.any((u) => u.email.toLowerCase() == trimmedEmail)) {
      throw UserEmailConflictException(
        "A user with the email '$trimmedEmail' already exists.",
      );
    }
    _idCounter++;
    final user = User(
      id: 'usr_demo_${_idCounter.toString().padLeft(3, '0')}',
      email: trimmedEmail,
      displayName: displayName.trim(),
      tenantId: 'ten_demo',
      role: role,
      // Demo users join the demo workspace immediately so the roster
      // reflects them without a separate invite-redemption step.
      workspaceMemberships: [
        WorkspaceMembership(
          workspaceId: workspaceId,
          workspaceName: 'Demo Classroom',
          role: role,
        ),
      ],
      createdAt: DateTime.now(),
    );
    _users.add(user);
    return user;
  }

  @override
  Future<void> deactivateUser(String userId) async {
    await _latency();
    final index = _users.indexWhere((u) => u.id == userId);
    if (index == -1) throw const UserNotFoundException();
    _users.removeAt(index);
  }

  @override
  Future<User> changeRole({
    required String workspaceId,
    required String userId,
    required UserRole role,
  }) async {
    await _latency();
    final index = _users.indexWhere((u) => u.id == userId);
    if (index == -1) throw const UserNotFoundException();
    final memberships = [
      for (final membership in _users[index].workspaceMemberships)
        membership.workspaceId == workspaceId
            ? membership.copyWith(role: role)
            : membership,
    ];
    final updated = _users[index].copyWith(
      role: role,
      workspaceMemberships: memberships,
    );
    _users[index] = updated;
    return updated;
  }

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 200));
}
