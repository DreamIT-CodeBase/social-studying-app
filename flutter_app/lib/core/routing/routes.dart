abstract final class AppRoutes {
  static const String login = '/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminDocuments = '/admin/documents';
  static const String studentHome = '/student/home';

  /// Sprint 2.10 polling screen route. The list screen pushes onto
  /// this with `context.push('${adminDocuments}/$workspaceId/$documentId')`.
  static const String adminDocumentPolling =
      '$adminDocuments/:workspaceId/:documentId';
}
