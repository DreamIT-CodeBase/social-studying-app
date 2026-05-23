abstract final class AppRoutes {
  static const String login = '/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminDocuments = '/admin/documents';
  static const String adminTaxonomy = '/admin/taxonomy';
  static const String adminWorkspaces = '/admin/workspaces';
  static const String adminModeration = '/admin/moderation';
  static const String adminWorkspaceSettings = '/admin/settings';
  static const String studentHome = '/student/home';
  static const String studentRevision = '/student/revision';

  /// Sprint 2.10 polling screen route. The list screen pushes onto
  /// this with `context.push('${adminDocuments}/$workspaceId/$documentId')`.
  static const String adminDocumentPolling =
      '$adminDocuments/:workspaceId/:documentId';

  /// Sprint 2.13 taxonomy viewer route. Pushed from the AppBar action
  /// on the documents list screen.
  static const String adminTaxonomyViewer =
      '$adminTaxonomy/:workspaceId';

  /// Sprint 4.3 taxonomy editor route. Pushed from the AppBar action on
  /// the taxonomy viewer screen.
  static const String adminTaxonomyEditor =
      '$adminTaxonomy/:workspaceId/edit';

  /// Sprint 4.5 moderation dashboard. Pushed from the admin Settings
  /// tab, scoped to the active workspace.
  static const String adminModerationDashboard =
      '$adminModeration/:workspaceId';

  /// Sprint 4.4 workspace settings. Pushed from the admin Settings tab,
  /// scoped to the active workspace.
  static const String adminWorkspaceSettingsEditor =
      '$adminWorkspaceSettings/:workspaceId';

  /// Sprint 4.10 revision mode — a bounded mixed question + flashcard
  /// session. Pushed from the student Home tab.
  static const String studentRevisionSession =
      '$studentRevision/:workspaceId';
}
