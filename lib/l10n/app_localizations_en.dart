// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cannotReachServerCheckConnection =>
      'Cannot reach the server. Check your connection.';

  @override
  String get notSyncedSession => 'Not synced in this session';

  @override
  String get syncing => 'Syncing…';

  @override
  String get completeMatchesServer => 'Complete: matches the server';

  @override
  String get notEverythingWasAppliedSee =>
      'Not everything was applied: see details';

  @override
  String get doesNotMatchServer => 'Does not match the server';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get lastCompleteSync => 'Last complete sync';

  @override
  String get phone => 'On this phone';

  @override
  String get movements => 'movements';

  @override
  String get lines => 'lines';

  @override
  String get pendingSend => 'Pending to send';

  @override
  String get rejected => 'Rejected';

  @override
  String get conflict => 'In conflict';

  @override
  String get pendingRejected => 'Pending and rejected';

  @override
  String get syncNow => 'Sync now';

  @override
  String get noAccountsPhoneSyncWhile =>
      'No accounts on this phone. Sync while online.';

  @override
  String willRecordIncomeThatAccount(Object name, Object queda) {
    return '$name will be at $queda. Record an income in that account.';
  }

  @override
  String notEnoughBalanceTransferAvailable(
      Object total, Object name, Object disponible) {
    return 'Not enough balance to transfer $total from $name (available $disponible). Record an income in the source account first.';
  }

  @override
  String get accounts => 'Accounts';

  @override
  String get newAccount => 'New account';

  @override
  String get all => 'All';

  @override
  String get active => 'Active';

  @override
  String get retry => 'Retry';

  @override
  String get noAccounts => 'No accounts';

  @override
  String get accountDeactivated => 'Account deactivated.';

  @override
  String get accountActivated => 'Account activated.';

  @override
  String get deleteAccount => 'Delete account?';

  @override
  String get withoutMovementsDeletedMovementsDeactivated =>
      'Without movements it is deleted; with movements it is deactivated.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get accountDeleted => 'Account deleted.';

  @override
  String get editAccount => 'Edit account';

  @override
  String get name => 'Name';

  @override
  String get currency => 'Currency';

  @override
  String get currencyLockedAccountHasMovements =>
      'Currency is locked: the account has movements.';

  @override
  String get icon => 'Icon';

  @override
  String get save => 'Save';

  @override
  String get accountCreated => 'Account created.';

  @override
  String get accountUpdated => 'Account updated.';

  @override
  String get inactive => 'Inactive';

  @override
  String get movements2 => 'movements';

  @override
  String get pendingSync => ' · pending sync';

  @override
  String get edit => 'Edit';

  @override
  String get deactivate => 'Deactivate';

  @override
  String get activate => 'Activate';

  @override
  String get code => 'Code';

  @override
  String get sessionExpiredPleaseSignAgain =>
      'Your session expired. Please sign in again.';

  @override
  String signedOutDeviceButServer(Object detail) {
    return 'Signed out on this device, but the server could not be notified$detail.';
  }

  @override
  String get sign => 'Sign in';

  @override
  String get youExampleCom => 'you@example.com';

  @override
  String get enterEmail => 'Enter your email';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get password => 'Password';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get sign2 => 'Sign in';

  @override
  String get categories => 'Categories';

  @override
  String get newCategory => 'New category';

  @override
  String get searchCategory => 'Search category';

  @override
  String get inactive2 => 'Inactive';

  @override
  String get noCategories => 'No categories';

  @override
  String get categoryDeactivated => 'Category deactivated.';

  @override
  String get categoryActivated => 'Category activated.';

  @override
  String get deleteCategory => 'Delete category?';

  @override
  String get categoryDeleted => 'Category deleted.';

  @override
  String get renameCategory => 'Rename category';

  @override
  String get categoryCreated => 'Category created.';

  @override
  String get categoryRenamed => 'Category renamed.';

  @override
  String get inactive3 => 'inactive';

  @override
  String get reserved => 'reserved';

  @override
  String get reserved2 => 'Reserved';

  @override
  String get rename => 'Rename';

  @override
  String get syncFailed2 => 'Sync failed';

  @override
  String operationSWereNotApplied(Object needsAttention) {
    return '$needsAttention operation(s) were not applied. See Settings → Pending and rejected.';
  }

  @override
  String get localDataDoesNotMatch =>
      'Local data does not match the server; a full download will run next time.';

  @override
  String get lastRate => 'Last rate';

  @override
  String get exchangeRateOfflineUsdNot =>
      'Exchange rate: offline · USD not converted';

  @override
  String get exchangeRateUnavailableUsdNot =>
      'Exchange rate unavailable · USD not converted';

  @override
  String get showingLastLoadedData => 'Showing the last loaded data';

  @override
  String get recordIncome => 'Record an income';

  @override
  String get noExchangeRate => 'no exchange rate';

  @override
  String get notifications => 'Notifications';

  @override
  String limitNearTop(Object titulo, Object porcentaje) {
    return 'Limit \'$titulo\' near top ($porcentaje%)';
  }

  @override
  String limitReached(Object titulo, Object porcentaje) {
    return 'Limit \'$titulo\' reached ($porcentaje%)';
  }

  @override
  String limitHasFinishedExpired(Object titulo) {
    return 'Limit \'$titulo\' has finished and is expired';
  }

  @override
  String get noPendingNotifications => 'No pending notifications';

  @override
  String get balanceWillNegative => 'Balance will be negative';

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String get ticketRecordedServer => 'Ticket recorded on the server.';

  @override
  String get expense => 'Expense';

  @override
  String get confirmingQrTicketRequiresConnection =>
      ' Confirming a QR ticket requires a connection.';

  @override
  String get correctExpense => 'Correct Expense';

  @override
  String get newExpense => 'New Expense';

  @override
  String registerExpense(Object totalFormateado) {
    return 'Register Expense ($totalFormateado)';
  }

  @override
  String get scanReceipt => 'Scan receipt';

  @override
  String get scanTicketQr => 'Scan Ticket QR';

  @override
  String get pointCameraReceiptQrCode => 'Point camera at receipt QR code';

  @override
  String get ifMerchantNewPageText =>
      'If this merchant is new, the page text will be sent to an external AI service to learn its reading rules.';

  @override
  String get featureNotAvailableNow => 'Feature not available for now';

  @override
  String get addLeastOnePhotoReceipt => 'Add at least one photo of the receipt';

  @override
  String get noProductsWereDetectedReceipt =>
      'No products were detected on the receipt.';

  @override
  String receiptReadDeviceLines(Object items) {
    return 'Receipt read on the device ($items lines)';
  }

  @override
  String couldNotReadReceipt(Object e) {
    return 'Could not read the receipt: $e';
  }

  @override
  String get scanReceiptUsingAutoCrop =>
      'Scan the receipt using auto-crop, QR code or pick a photo from your gallery.';

  @override
  String get readingReceiptDevice => 'Reading receipt on the device...';

  @override
  String get extractingProductsNetAmountsDiscounts =>
      'Extracting products, net amounts and discounts...';

  @override
  String get noScansAddedYet => 'No scans added yet';

  @override
  String get useScanScanQrGallery => 'Use Scan, Scan QR or Gallery below';

  @override
  String scan(Object numFoto) {
    return 'Scan #$numFoto';
  }

  @override
  String get scan2 => 'Scan';

  @override
  String get scanQr => 'Scan QR';

  @override
  String get gallery => 'Gallery';

  @override
  String get finishLoading => 'Finish loading';

  @override
  String get readAi => 'Read with AI';

  @override
  String get income => 'Income';

  @override
  String get correctIncome => 'Correct Income';

  @override
  String get newIncome => 'New Income';

  @override
  String get invalidAmountMax2Decimals => 'Invalid amount (max. 2 decimals)';

  @override
  String get budgets => 'Budgets';

  @override
  String get newBudget => 'New budget';

  @override
  String get all2 => 'All';

  @override
  String get current => 'Current';

  @override
  String get due => 'Due';

  @override
  String get exceeded => 'Exceeded';

  @override
  String get noBudgets => 'No budgets';

  @override
  String get budgetRenewed => 'Budget renewed.';

  @override
  String get deleteBudget => 'Delete budget?';

  @override
  String get budgetDeleted => 'Budget deleted.';

  @override
  String get editBudget => 'Edit budget';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String get limit => 'Limit';

  @override
  String get budgetUpdated => 'Budget updated.';

  @override
  String get categories2 => 'Categories';

  @override
  String get accounts2 => 'Accounts';

  @override
  String get budgetCreated => 'Budget created.';

  @override
  String get currentBudgets => 'Current budgets';

  @override
  String get limits => 'Limits';

  @override
  String get spent => 'Spent';

  @override
  String get remaining => 'Remaining';

  @override
  String get excess => 'Excess';

  @override
  String get left => 'Left';

  @override
  String get renew => 'Renew';

  @override
  String pending(Object pending) {
    return ' Pending: $pending.';
  }

  @override
  String savedPhoneWillSentServer(Object what, Object suffix) {
    return '$what saved on this phone. It will be sent to the server when syncing.$suffix';
  }

  @override
  String get couldNotReadDataPhone => 'Could not read the data on this phone';

  @override
  String savedPhoneSending(Object ok) {
    return '$ok Saved on this phone; sending…';
  }

  @override
  String get dateRange => 'Date range';

  @override
  String get movements3 => 'Movements';

  @override
  String get searchTextAmount => 'Search by text or amount';

  @override
  String get results => 'results';

  @override
  String lastMovements(Object total) {
    return 'Last $total movements';
  }

  @override
  String get noMovements => 'No movements';

  @override
  String get will => 'will be at';

  @override
  String get recordIncomeThatAccount => 'Record an income in that account.';

  @override
  String get savedPhoneSending2 => 'Saved on this phone; sending…';

  @override
  String get completeSourceDestinationValidAmount =>
      'Complete source, destination and a valid amount';

  @override
  String get deleteMovement => 'Delete movement?';

  @override
  String get removedAllItsLines => 'It is removed with all its lines.';

  @override
  String get editMovement => 'Edit movement';

  @override
  String get movementNotPhoneWasDeleted =>
      'This movement is not on the phone (or was deleted). Sync and try again.';

  @override
  String get deleteMovement2 => 'Delete movement';

  @override
  String get header => 'Header';

  @override
  String get generalConcept => 'General concept';

  @override
  String get accountAllLines => 'Account (all lines)';

  @override
  String get saveHeader => 'Save header';

  @override
  String get lines2 => 'Lines';

  @override
  String get notServerYetLinesCan =>
      'Not on the server yet: lines can be edited after syncing.';

  @override
  String get transfer => 'Transfer';

  @override
  String get from2 => 'From';

  @override
  String get to2 => 'To';

  @override
  String get amount => 'Amount';

  @override
  String get saveTransfer => 'Save transfer';

  @override
  String get concept => 'Concept';

  @override
  String get category => 'Category';

  @override
  String get deleteLine => 'Delete line';

  @override
  String get saveLine => 'Save line';

  @override
  String showingLinesFilter(Object details, Object detailsCount) {
    return 'Showing $details of $detailsCount lines (filter)';
  }

  @override
  String get unit => 'unit';

  @override
  String get signOut => 'Sign out?';

  @override
  String get allDataStoredPhoneWill =>
      'All data stored on this phone will be deleted. Data already on the server is not affected.';

  @override
  String get signOut2 => 'Sign out';

  @override
  String get session => 'Session';

  @override
  String get offline => 'offline';

  @override
  String get deletesDataStoredPhoneSettings =>
      'Deletes the data stored on this phone. Settings are kept.';

  @override
  String get offlineData => 'Offline data';

  @override
  String get server => 'Server';

  @override
  String get apiAddress => 'API address';

  @override
  String get notConfiguredApiBaseUrl => 'Not configured (API_BASE_URL)';

  @override
  String get discard => 'Discard?';

  @override
  String get serverVersionKeptChangeLost =>
      'The server version is kept. Your change is lost.';

  @override
  String get removedPhoneLocalBalanceReverted =>
      'It is removed from this phone and the local balance is reverted.';

  @override
  String get discard2 => 'Discard';

  @override
  String get discarded => 'Discarded';

  @override
  String get nothingPendingEverythingWasApplied =>
      'Nothing pending: everything was applied.';

  @override
  String get rejected2 => 'Rejected';

  @override
  String get conflictServerVersionApplied =>
      'Conflict (server version applied)';

  @override
  String get pending2 => 'Pending';

  @override
  String get reason => 'Reason';

  @override
  String get attempts => 'Attempts';

  @override
  String get correct => 'Correct';

  @override
  String get queuedAgainChanges => 'Queued again with your changes';

  @override
  String get retryMyChanges => 'Retry with my changes';

  @override
  String get keepServerVersion => 'Keep server version';

  @override
  String get correctTransfer => 'Correct Transfer';

  @override
  String get transferMoney => 'Transfer Money';

  @override
  String noOtherAccount(Object currency) {
    return 'No other account in $currency';
  }

  @override
  String get selectDestination => 'Select destination';

  @override
  String get errInvalidCredentials => 'Wrong email or password.';

  @override
  String get errAccountLocked =>
      'Too many failed attempts. Try again in 15 minutes.';

  @override
  String get errRateLimited => 'Too many requests. Please wait a moment.';

  @override
  String get errInvalidRefresh => 'Your session expired. Please sign in again.';

  @override
  String get errInvalidToken => 'Your session expired. Please sign in again.';

  @override
  String get errUnauthorized => 'You need to sign in.';

  @override
  String get errNotFound =>
      'The server does not have this feature or the item does not exist.';

  @override
  String get errDuplicate => 'A record with that data already exists.';

  @override
  String get errEmailTaken => 'An account with that email already exists.';

  @override
  String get errInsufficientFunds =>
      'Not enough balance to transfer. Record an income in the source account first.';

  @override
  String get errReservedCategory => 'That category is reserved by the system.';

  @override
  String get errSameAccount => 'Source and destination accounts must differ.';

  @override
  String get errCurrencyMismatch =>
      'Cannot transfer between accounts in different currencies.';

  @override
  String get errAccountInactive => 'The account is inactive.';

  @override
  String get errAccountHasFunds =>
      'This account has money; empty it and try again.';

  @override
  String get errCurrencyLocked =>
      'The currency of an account with movements cannot change.';

  @override
  String get errDuplicateName => 'Another record already has that name.';

  @override
  String get errInvalidPeriod =>
      'The end date cannot be before the start date.';

  @override
  String get errLastDetail => 'It is the only line; delete the whole movement.';

  @override
  String get errTransferEdit =>
      'A transfer is edited as a pair (source, destination, amount).';

  @override
  String get errVersionConflict => 'The record changed on the server.';

  @override
  String get errCategoryInactive => 'The category is inactive.';

  @override
  String get errCatalogNotSynced =>
      'Server data is missing on this phone: sync while online.';

  @override
  String get errInternalError => 'Internal server error.';

  @override
  String get errNotAvailable => 'Feature not available for now.';

  @override
  String get errConfigMissing =>
      'The app has no server address configured (API_BASE_URL).';

  @override
  String get errUnexpectedResponse => 'Unexpected response from the server.';

  @override
  String errInvalidData(String message) {
    return 'Invalid data: $message';
  }

  @override
  String get errNetwork => 'Cannot reach the server. Check your connection.';
}
