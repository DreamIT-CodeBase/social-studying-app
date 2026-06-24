import 'dart:async';
import 'dart:math';

import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/shared/models/invite_code.dart';
import 'package:social_study_app/shared/models/workspace.dart';

/// Typed exceptions the UI branches on. Mirror the HTTP statuses the
/// real repository surfaces from the backend.

/// 409 from `POST /workspaces/` — a live workspace with this name
/// already exists in the tenant.
class WorkspaceNameConflictException implements Exception {
  const WorkspaceNameConflictException([
    this.message = 'A workspace with that name already exists',
  ]);
  final String message;
  @override
  String toString() => 'WorkspaceNameConflictException: $message';
}

/// 404 — the workspace was deleted or never existed.
class WorkspaceNotFoundException implements Exception {
  const WorkspaceNotFoundException([this.message = 'Workspace not found']);
  final String message;
  @override
  String toString() => 'WorkspaceNotFoundException: $message';
}

/// Offline, in-process implementation of workspace CRUD.
///
/// Backs the demo user so an offline dev can exercise the full
/// create / list / edit / delete flow without a live backend. Seeded
/// with one workspace ("Demo Classroom", id `wsp_demo_001`) so the list
/// screen has content on first open and the demo home screen's
/// workspace reference resolves.
///
/// State is in-process; restarting the app resets to the seed.
class DemoWorkspacesRepository implements WorkspacesRepository {
  DemoWorkspacesRepository();

  final List<Workspace> _workspaces = [
    Workspace(
      id: 'wsp_demo_001',
      tenantId: 'ten_demo',
      name: 'Demo Classroom',
      description: 'A sample workspace for exploring the app.',
      adminCount: 1,
      studentCount: 3,
      documentCount: 2,
      settings: const WorkspaceSettings(),
      createdAt: DateTime(2026, 4, 1),
    ),
  ];

  final Random _random = Random();
  int _idCounter = 1;

  @override
  Future<List<Workspace>> list() async {
    await _latency();
    // Defensive copy — callers must not mutate our backing store.
    return List.unmodifiable(_workspaces);
  }

  @override
  Future<Workspace> create({
    required String name,
    String? description,
  }) async {
    await _latency();
    final trimmed = name.trim();
    if (_nameTaken(trimmed, exceptId: null)) {
      throw WorkspaceNameConflictException(
        "A workspace named '$trimmed' already exists.",
      );
    }
    _idCounter++;
    final workspace = Workspace(
      id: 'wsp_demo_${_idCounter.toString().padLeft(3, '0')}',
      tenantId: 'ten_demo',
      name: trimmed,
      description: description?.trim() ?? '',
      settings: const WorkspaceSettings(),
      createdAt: DateTime.now(),
    );
    _workspaces.add(workspace);
    return workspace;
  }

  @override
  Future<Workspace> update({
    required String workspaceId,
    String? name,
    String? description,
    WorkspaceSettings? settings,
  }) async {
    await _latency();
    final index = _workspaces.indexWhere((w) => w.id == workspaceId);
    if (index == -1) throw const WorkspaceNotFoundException();

    final current = _workspaces[index];
    if (name != null && _nameTaken(name.trim(), exceptId: workspaceId)) {
      throw WorkspaceNameConflictException(
        "A workspace named '${name.trim()}' already exists.",
      );
    }
    final updated = current.copyWith(
      name: name?.trim() ?? current.name,
      description: description?.trim() ?? current.description,
      settings: settings ?? current.settings,
    );
    _workspaces[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String workspaceId) async {
    await _latency();
    final index = _workspaces.indexWhere((w) => w.id == workspaceId);
    if (index == -1) throw const WorkspaceNotFoundException();
    _workspaces.removeAt(index);
  }

  @override
  Future<GeneratedInviteCode> generateInviteCode(String workspaceId) async {
    await _latency();
    if (!_workspaces.any((w) => w.id == workspaceId)) {
      throw const WorkspaceNotFoundException();
    }
    return GeneratedInviteCode(
      code: _randomCode(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      maxUses: 30,
    );
  }

  // ── Internals ───────────────────────────────────────────────────────────

  bool _nameTaken(String name, {required String? exceptId}) =>
      _workspaces.any(
        (w) =>
            w.id != exceptId &&
            w.name.toLowerCase() == name.toLowerCase(),
      );

  /// 8-char uppercase code — matches the backend's
  /// `uuid4().hex[:8].upper()` shape closely enough for the demo.
  String _randomCode() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      8,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  @override
  Future<Workspace> createCollaborative({required String name, String? description}) async {
    await _latency();
    _idCounter++;
    final workspace = Workspace(
      id: 'wsp_demo_${_idCounter.toString().padLeft(3, '0')}',
      tenantId: 'ten_demo',
      name: name.trim(),
      description: description?.trim() ?? '',
      type: 'collaborative',
      ownerId: 'usr_demo_001',
      joinCode: _randomCode().substring(0, 6),
      settings: const WorkspaceSettings(),
      createdAt: DateTime.now(),
    );
    _workspaces.add(workspace);
    return workspace;
  }

  @override
  Future<Workspace> joinCollaborative({String? joinCode, String? inviteToken}) async {
    await _latency();
    if (joinCode == null && inviteToken == null) {
      throw Exception('Join code or invite token is required');
    }
    // Return a joined collaborative workspace
    final workspace = Workspace(
      id: 'wsp_collab_joined',
      tenantId: 'ten_demo',
      name: 'Collaborative Biology Study',
      description: 'Study group for cell biology chapters.',
      type: 'collaborative',
      ownerId: 'usr_other_002',
      joinCode: 'BIO101',
      settings: const WorkspaceSettings(),
      createdAt: DateTime.now(),
    );
    if (!_workspaces.any((w) => w.id == workspace.id)) {
      _workspaces.add(workspace);
    }
    return workspace;
  }

  @override
  Future<void> leaveCollaborative(String workspaceId) async {
    await _latency();
    _workspaces.removeWhere((w) => w.id == workspaceId);
  }

  @override
  Future<List<Map<String, dynamic>>> listMembers(String workspaceId) async {
    await _latency();
    return [
      {
        "user_id": "usr_demo_001",
        "role": "owner",
        "display_name": "Tarun",
        "email": "tarunjuneja@gmail.com",
        "joined_at": DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      },
      {
        "user_id": "usr_other_002",
        "role": "editor",
        "display_name": "Alice",
        "email": "alice@gmail.com",
        "joined_at": DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        "user_id": "usr_other_003",
        "role": "viewer",
        "display_name": "Bob",
        "email": "bob@gmail.com",
        "joined_at": DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      }
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> listActivity(String workspaceId) async {
    await _latency();
    return [
      {
        "_id": "act_1",
        "workspace_id": workspaceId,
        "user_id": "usr_demo_001",
        "user_name": "Tarun",
        "activity_type": "member_joined",
        "details": {"role": "owner"},
        "created_at": DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      },
      {
        "_id": "act_2",
        "workspace_id": workspaceId,
        "user_id": "usr_other_002",
        "user_name": "Alice",
        "activity_type": "document_uploaded",
        "details": {"filename": "CellStructure.pdf"},
        "created_at": DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      }
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getMessages(String workspaceId) async {
    await _latency();
    return [
      {
        "_id": "msg_1",
        "workspace_id": workspaceId,
        "sender_id": "usr_other_002",
        "sender_name": "Alice",
        "content": "Hi everyone! Welcome to our study workspace.",
        "attachments": [],
        "created_at": DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      },
      {
        "_id": "msg_2",
        "workspace_id": workspaceId,
        "sender_id": "usr_demo_001",
        "sender_name": "Tarun",
        "content": "Thanks Alice! Let's upload the cell biology slides here.",
        "attachments": [],
        "created_at": DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      }
    ];
  }

  @override
  Future<void> postMessage(String workspaceId, {required String content, List<String>? attachments}) async {
    await _latency();
  }

  @override
  Future<void> changeMemberRole(String workspaceId, {required String userId, required String role}) async {
    await _latency();
  }

  @override
  Future<Map<String, dynamic>> inviteToCollaborative(String workspaceId, {String? email, String? username, required String role}) async {
    await _latency();
    return {
      "invite_token": "token_demo_invite",
      "join_code": "DEMO123",
      "role": role,
      "expires_at": DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    };
  }
}
