class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String dashboard = '/';
  static const String expensesCreate = '/expenses/create';
  static const String scanTicket = '/expenses/scan-ticket';
  static const String incomesCreate = '/incomes/create';
  static const String transfersCreate = '/transfers/create';
  static const String movements = '/movements';
  static String movementEdit(int serverId, {bool askDelete = false}) => '/movements/edit/$serverId${askDelete ? '?eliminar=1' : ''}';
  static const String accountsAdmin = '/admin/accounts';
  static const String categoriesAdmin = '/admin/categories';
  static const String limitsAdmin = '/admin/limits';
  static const String analytics = '/analytics';
  static const String settings = '/settings';
  static const String syncPending = '/sync/pending';
}
