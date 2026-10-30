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
  String get showingLastLoadedData => 'Showing the last loaded data';

  @override
  String get recordIncome => 'Record an income';

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
      'Your data stays on this phone: if you sign in again with this account you will find it (including anything not yet sent).';

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

  @override
  String get selectAccount => 'Select an account';

  @override
  String get operationNoLongerQueue =>
      'The operation is no longer in the queue';

  @override
  String get onlyEditsConflictCanRetried =>
      'Only edits in conflict can be retried';

  @override
  String get voucherNoLongerExistsPhone =>
      'The voucher no longer exists on this phone';

  @override
  String get onlyRejectedCreationsCanCorrected =>
      'Only rejected creations can be corrected';

  @override
  String get unknownIcon => 'Unknown icon';

  @override
  String get account => 'The account';

  @override
  String get currencyAccountMovementsCannotChange =>
      'The currency of an account with movements cannot change';

  @override
  String get noChangesSave => 'No changes to save';

  @override
  String nameMustHaveLeastAccountnamemin(Object accountNameMin) {
    return 'The name must have at least $accountNameMin characters';
  }

  @override
  String nameCannotExceedAccountnamemaxCharacters(Object accountNameMax) {
    return 'The name cannot exceed $accountNameMax characters';
  }

  @override
  String get selectRangeReport => 'Select a range for the report';

  @override
  String get reportsAnalytics => 'Reports and Analytics';

  @override
  String get refreshReport => 'Refresh report';

  @override
  String get dayDay => 'Day by Day';

  @override
  String get month => 'This Month';

  @override
  String get previousMonth => 'Previous Month';

  @override
  String get currentYear => 'Current Year';

  @override
  String get frequentConceptsDetail => 'Frequent Concepts Detail';

  @override
  String get annualOverview => 'Annual Overview';

  @override
  String get annualIncome => 'Annual Income';

  @override
  String get annualExpenses => 'Annual Expenses';

  @override
  String get netBalance => 'Net Balance';

  @override
  String get savingsRate => 'Savings Rate';

  @override
  String get incomeVsExpensesMonth => 'Income vs Expenses by Month';

  @override
  String get detailedMonthlyBreakdown => 'Detailed Monthly Breakdown';

  @override
  String incIngresoscents(Object ingresosCents) {
    return 'Inc: $ingresosCents';
  }

  @override
  String expEgresoscents(Object egresosCents) {
    return 'Exp: $egresosCents';
  }

  @override
  String get dailySpendingCurve => 'Daily Spending Curve';

  @override
  String get monthTotal => 'Month Total';

  @override
  String get highestPeak => 'Highest Peak';

  @override
  String get dailyExpenseTrend => 'Daily Expense Trend';

  @override
  String get noExpensesPeriod => 'No expenses in this period';

  @override
  String get totalExpenses => 'Total Expenses';

  @override
  String tostringasfixedTotal(Object toStringAsFixed) {
    return '$toStringAsFixed% of total';
  }

  @override
  String dayDianumSpentEgresoscents(Object diaNum, Object egresosCents) {
    return 'Day $diaNum\nSpent: $egresosCents';
  }

  @override
  String get searchItemPluCode => 'Search item or PLU code...';

  @override
  String get compareInflationBetweenPeriods =>
      'Compare Inflation between Periods';

  @override
  String get noRecordedItemsFound => 'No recorded items found';

  @override
  String get itemsRecordedWhenYouEnter =>
      'Items are recorded when you enter receipts or detailed expenses';

  @override
  String get priceHistoryTrend => 'Price History and Trend';

  @override
  String get noHistoricalDataItem => 'No historical data for this item';

  @override
  String get currentPrice => 'Current Price';

  @override
  String get totalChange => 'Total Change';

  @override
  String get historicalLow => 'Historical Low';

  @override
  String get historicalHigh => 'Historical High';

  @override
  String get unitPriceTrend => 'Unit Price Trend';

  @override
  String get purchaseHistory => 'Purchase History';

  @override
  String get inflationMonitor => 'Inflation Monitor';

  @override
  String get comparisonIdenticalItemsPurchased =>
      'Comparison of identical items purchased';

  @override
  String get noIdenticalItemsWerePurchased =>
      'No identical items were purchased in both selected periods.';

  @override
  String get personalAverageInflation => 'Personal Average Inflation';

  @override
  String productoscomunesItemsComparedProductosaumentaronWent(
      Object productosComunes, Object productosAumentaron) {
    return '$productosComunes items compared ($productosAumentaron went up in price)';
  }

  @override
  String get detailItem => 'Detail by Item';

  @override
  String beforePrecio1centsNowPrecio2cents(
      Object precio1Cents, Object precio2Cents) {
    return 'Before: $precio1Cents ➔ Now: $precio2Cents';
  }

  @override
  String get loadingFinances => 'Loading your finances...';

  @override
  String get category2 => 'The category';

  @override
  String get systemReservedCategoriesCannotChanged =>
      'System reserved categories cannot be changed or deleted';

  @override
  String get categoryNameRequired => 'The category name is required';

  @override
  String nameCannotExceedCategorynamemaxCharacters(Object categoryNameMax) {
    return 'The name cannot exceed $categoryNameMax characters';
  }

  @override
  String couldNotOpenLocalDatabase(Object e) {
    return 'Could not open the local database: $e';
  }

  @override
  String get filterBalancesUpDate => 'Filter balances up to a date';

  @override
  String get refreshBalances => 'Refresh balances';

  @override
  String get settings => 'Settings';

  @override
  String myAccountsAccounts(Object accounts) {
    return 'My Accounts ($accounts)';
  }

  @override
  String get limitsBudgets => 'Limits and Budgets';

  @override
  String get consolidatedBalances => 'Consolidated Balances';

  @override
  String get hideBalances => 'Hide balances';

  @override
  String get filterDate => 'Filter by date';

  @override
  String untilFechaformatted(Object fechaFormatted) {
    return 'Until: $fechaFormatted';
  }

  @override
  String get selectSourceAccount => 'Select a source account';

  @override
  String selectCategoryLineI(Object i) {
    return 'Select a category for line #$i';
  }

  @override
  String get qrReceiptsCannotConfirmedHere =>
      'QR receipts cannot be confirmed here';

  @override
  String get accountNotServerYetSync =>
      'The account is not on the server yet: sync and try again';

  @override
  String get fillConceptField => 'Fill in the Concept field';

  @override
  String categoryNameNotServerYet(Object name) {
    return 'The category $name is not on the server yet: sync';
  }

  @override
  String lineIMustHaveAmount(Object i) {
    return 'Line #$i must have an amount greater than 0';
  }

  @override
  String get expenseDate => 'Expense date';

  @override
  String get sourceAccount => 'Source Account';

  @override
  String get generalConcept2 => 'General Concept *';

  @override
  String get eGSupermarketBookstore => 'E.g.: Supermarket, Bookstore...';

  @override
  String get addLine => 'Add Line';

  @override
  String get expenseTotal => 'Expense Total';

  @override
  String get scannedQrCodeNotValid =>
      'The scanned QR code is not a valid web address (http/https).';

  @override
  String get loadingExpenses => 'Loading expenses...';

  @override
  String receiptReadItemsLines(Object items) {
    return 'Receipt read: $items lines';
  }

  @override
  String get couldNotProcessQr => 'Could not process the QR';

  @override
  String motivoDoYouWantScan(Object motivo) {
    return '$motivo\n\nDo you want to scan the QR again or read photos instead?';
  }

  @override
  String get usePhotos => 'Use photos';

  @override
  String get scannerNotAvailableDeviceSelect =>
      'The scanner is not available on this device. Select photos from the gallery.';

  @override
  String get couldNotAccessGalleryCheck =>
      'Could not access the gallery. Check the permissions.';

  @override
  String lineRenglonnum(Object renglonNum) {
    return 'Line #$renglonNum';
  }

  @override
  String get deleteLine2 => 'Delete line';

  @override
  String get eGVegetablesMeatCleaning => 'E.g.: Vegetables, Meat, Cleaning...';

  @override
  String get selectDestinationAccount => 'Select a destination account';

  @override
  String get incomeDate => 'Income date';

  @override
  String get amountAdd => 'Amount to Add';

  @override
  String get conceptReason => 'Concept / Reason';

  @override
  String eGSalaryFreelancePayment(Object conceptoIngresoPorDefecto) {
    return 'E.g.: Salary, Freelance payment, Sale... (empty: \"$conceptoIngresoPorDefecto\")';
  }

  @override
  String get recordIncome2 => 'Record Income';

  @override
  String get amountMustGreaterThanZero =>
      'The amount must be greater than zero';

  @override
  String get selectLeastOneCategory => 'Select at least one category';

  @override
  String mostBudgetmaxcategoriesCategories(Object budgetMaxCategories) {
    return 'At most $budgetMaxCategories categories';
  }

  @override
  String get selectLeastOneAccountApply =>
      'Select at least one account to apply the spending limit to';

  @override
  String get limit2 => 'The limit';

  @override
  String get invalidDate => 'Invalid date';

  @override
  String get endDateCannotBeforeStart =>
      'The end date cannot be before the start date';

  @override
  String get generalConcept3 => 'The general concept';

  @override
  String get changeAccountsTransferEditSource =>
      'To change the accounts of a transfer, edit source and destination';

  @override
  String get movementCannotMovedAccountAnother =>
      'The movement cannot be moved to an account in another currency';

  @override
  String get transferLinesEditedAsPair =>
      'Transfer lines are edited as a pair (source, destination and amount)';

  @override
  String get concept2 => 'The concept';

  @override
  String get incomesAlwaysUseReservedIncome =>
      'Incomes always use the reserved income category';

  @override
  String get selectCategory => 'Select a category';

  @override
  String categoryNameReservedCannotUsed(Object name) {
    return 'The category $name is reserved and cannot be used in expenses';
  }

  @override
  String categoryNameInactive(Object name) {
    return 'The category $name is inactive';
  }

  @override
  String get singleLineTransferCannotDeleted =>
      'A single line of a transfer cannot be deleted; delete the whole movement';

  @override
  String get onlyLineVoucherDeleteWhole =>
      'It is the only line of the voucher; delete the whole movement';

  @override
  String get movementNotTransfer => 'The movement is not a transfer';

  @override
  String get transferDoesNotHaveIts =>
      'The transfer does not have its pair of lines on this phone';

  @override
  String get sourceDestinationAccountsCannotSame =>
      'Source and destination accounts cannot be the same';

  @override
  String get cannotTransferBetweenAccountsDifferent =>
      'Cannot transfer between accounts in different currencies';

  @override
  String get voucherNotPhoneSyncTry =>
      'The voucher is not on this phone; sync and try again';

  @override
  String get lineNoLongerPhone => 'The line is no longer on this phone';

  @override
  String get voucherHasNotReachedServer =>
      'The voucher has not reached the server yet: sync before editing or deleting its lines';

  @override
  String accountNameInactive(Object name) {
    return 'The account $name is inactive';
  }

  @override
  String get enterLeastOneExpense => 'Enter at least one expense';

  @override
  String get most300LinesPerExpense => 'At most 300 lines per expense';

  @override
  String get selectAccountDebit => 'Select the account to debit';

  @override
  String conceptLineI(Object i) {
    return 'The concept of line $i';
  }

  @override
  String selectCategoryLineI2(Object i) {
    return 'Select a category in line $i';
  }

  @override
  String get selectDestinationAccount2 => 'Select the destination account';

  @override
  String get selectSourceAccount2 => 'Select the source account';

  @override
  String get selectDestinationAccount3 => 'Select the destination account';

  @override
  String get cannotTransferBetweenAccountsDifferent2 =>
      'Cannot transfer between accounts in different currencies. Record an expense and an income.';

  @override
  String conceptCannotExceedConceptmaxCharacters(Object conceptMax) {
    return 'The concept cannot exceed $conceptMax characters';
  }

  @override
  String get operationCorrectNoLongerRejected =>
      'The operation to correct is no longer rejected';

  @override
  String systemCategoryRoleMissingSync(Object role) {
    return 'The system category $role is missing: sync online before entering data.';
  }

  @override
  String get languageDefaultCurrency => 'Language and Default Currency';

  @override
  String get appLanguage => 'App Language';

  @override
  String get sessionDiagnosticsDebug => 'Session diagnostics (debug)';

  @override
  String get n2ParallelGetAuthMe => '2 parallel GET /auth/me';

  @override
  String get management => 'Management';

  @override
  String get accountsPaymentMethods => 'Accounts and Payment Methods';

  @override
  String get manageBanksWalletsCash => 'Manage banks, wallets and cash';

  @override
  String get createRenameActivateExpenseCategories =>
      'Create, rename and activate expense categories';

  @override
  String get budgetsSpendingCaps => 'Budgets and Spending Caps';

  @override
  String get monthlyLimitsAlertsOneTap =>
      'Monthly limits, alerts and one-tap renewal';

  @override
  String get reportsPriceMonitor => 'Reports and Price Monitor';

  @override
  String get visualAnalyticsChartsInflationTrends =>
      'Visual analytics, charts and inflation trends';

  @override
  String get appearanceTheme => 'Appearance and Theme';

  @override
  String get displayMode => 'Display Mode';

  @override
  String get initialSetup => 'Initial Setup';

  @override
  String get welcomePleaseChooseInitialPreferences =>
      'Welcome! Please choose your initial preferences:';

  @override
  String get n1UsualCurrencyDefault => '1. Main currency';

  @override
  String get n2PreferredLanguage => '2. Preferred Language';

  @override
  String get selectSourceDestinationAccounts =>
      'Select source and destination accounts';

  @override
  String get transferDate => 'Transfer date';

  @override
  String get source => 'From (Source)';

  @override
  String get selectSource => 'Select source';

  @override
  String get swapAccounts => 'Swap accounts';

  @override
  String get destination => 'To (Destination)';

  @override
  String get amountTransfer => 'Amount to Transfer';

  @override
  String get conceptReference => 'Concept / Reference';

  @override
  String get eGWithdrawal => 'E.g.: Withdrawal';

  @override
  String get confirmTransfer => 'Confirm Transfer';

  @override
  String notOnPhoneSync(String what) {
    return '$what is not on this phone; sync and try again';
  }

  @override
  String fieldRequired(String field) {
    return '$field is required';
  }

  @override
  String fieldTooLong(String field, int max) {
    return '$field cannot exceed $max characters';
  }

  @override
  String amountOfMustBePositive(String what) {
    return 'The $what amount must be greater than zero';
  }

  @override
  String lineN(int n) {
    return 'line $n';
  }

  @override
  String get incomeWord => 'income';

  @override
  String get transferWord => 'transfer';

  @override
  String insufficientFundsTransfer(
      String amount, String account, String available) {
    return 'Not enough balance to transfer $amount from $account (available $available). Record an income in the source account first.';
  }

  @override
  String insufficientFundsTransferEdit(String amount, String account) {
    return 'Not enough balance to transfer $amount from $account. Record an income in the source account first.';
  }

  @override
  String categoryNotForBudgets(String name) {
    return 'The category $name cannot be used in spending limits';
  }

  @override
  String get accountAlreadyActive => 'The account is already active';

  @override
  String get accountAlreadyInactive => 'The account is already inactive';

  @override
  String get categoryAlreadyActive => 'The category is already active';

  @override
  String get categoryAlreadyInactive => 'The category is already inactive';

  @override
  String get accountNameTaken => 'An account with that name already exists';

  @override
  String get accountNameTakenInactive =>
      'An inactive account with that name exists: activate it';

  @override
  String get categoryNameTaken => 'A category with that name already exists';

  @override
  String get categoryNameTakenInactive =>
      'An inactive category with that name exists: activate it';

  @override
  String get alreadyTriedSyncBeforeDiscard =>
      'It was already sent once: it may be applied on the server. Sync before discarding it.';

  @override
  String get comparison => 'Comparison';

  @override
  String get prices => 'Prices';

  @override
  String get custom => 'Custom';

  @override
  String get surplus => 'Surplus';

  @override
  String get deficit => 'Deficit';

  @override
  String get income2 => 'Income';

  @override
  String get expenses => 'Expenses';

  @override
  String get apply => 'Apply';

  @override
  String get clear => 'Clear';

  @override
  String get expenses2 => 'Expenses';

  @override
  String get transfer2 => 'Transfer';

  @override
  String get history => 'History';

  @override
  String get date => 'Date';

  @override
  String get destinationAccount => 'Destination account.';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get start => 'Start';

  @override
  String linesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String purchasesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count purchases',
      one: '1 purchase',
    );
    return '$_temp0';
  }

  @override
  String ticketSumDiffers(String sum, String total, String diff) {
    return 'Sum of lines ($sum) differs from the receipt total ($total): difference $diff. Check the amounts.';
  }

  @override
  String ticketReadSumTotal(String sum, String total) {
    return 'Receipt read: sum $sum | total $total';
  }

  @override
  String ticketSumNoTotal(String sum) {
    return 'Sum of lines: $sum (no total detected on the receipt).';
  }

  @override
  String chartMonthTooltip(
      String month, String kind, String amount, String balance) {
    return '$month\n$kind: $amount\nBalance: $balance';
  }

  @override
  String get currencyArs => 'Argentine pesos (ARS \$)';

  @override
  String get currencyUsd => 'US dollars (USD \$)';

  @override
  String get cameraPermissionDenied =>
      'No permission to use the camera. Enable it in the phone settings to read the QR.';

  @override
  String get cameraUnsupported => 'This phone cannot read QR codes.';

  @override
  String get cameraError => 'Could not use the camera.';

  @override
  String get errInsecureTransport =>
      'The server address does not use HTTPS: this version of the app only connects over HTTPS.';

  @override
  String get ticketAlreadyRegistered =>
      'This receipt was already recorded; it was not added again.';

  @override
  String ticketRecordedNotOnPhoneYet(String error) {
    return 'Receipt recorded on the server, but it could not be loaded on the phone: $error. It will appear on the next sync.';
  }

  @override
  String get syncOfflineSaved =>
      'No connection to the server: what you enter is saved on the phone and sent when it is back.';

  @override
  String get qrNeedsConnection => 'QR reading needs a connection';

  @override
  String savedThing(String what) {
    return '$what saved.';
  }

  @override
  String get changesSaved => 'Changes saved.';

  @override
  String get dashboardYou => 'you';

  @override
  String get dashboards => 'Dashboards';

  @override
  String get manageDashboards => 'Manage dashboards';

  @override
  String get chooseDashboard => 'Choose dashboard';

  @override
  String get dashboardSharedTag => 'shared';

  @override
  String get invitationTitle => 'A dashboard was shared with you';

  @override
  String invitationBody(String inviter, String email, String dashboard) {
    return '$inviter ($email) invited you to share their dashboard \"$dashboard\".';
  }

  @override
  String get acceptInvitation => 'Accept';

  @override
  String get rejectInvitation => 'Reject';

  @override
  String notificationAccepted(String user, String dashboard) {
    return '$user accepted sharing the dashboard \"$dashboard\".';
  }

  @override
  String notificationRejected(String user, String dashboard) {
    return '$user declined sharing the dashboard \"$dashboard\".';
  }

  @override
  String get accessLostNotice =>
      'You no longer have access to that dashboard: showing your main dashboard.';

  @override
  String movementCreatedBy(String name) {
    return 'Added by $name';
  }

  @override
  String get dashboardName => 'Dashboard name';

  @override
  String get dashboardDefaultName => 'principal';

  @override
  String get displayName => 'Display name';

  @override
  String get displayNameHint =>
      'People you share a dashboard with see it. It does not have to be unique.';

  @override
  String get displayNameSaved => 'Name saved.';

  @override
  String get yourDashboards => 'Your dashboards';

  @override
  String get sharedWithYou => 'Shared with you';

  @override
  String get newDashboard => 'New dashboard';

  @override
  String get createDashboard => 'Create';

  @override
  String get shareWithEmail => 'Share with (email of a registered user)';

  @override
  String get shareDashboard => 'Share';

  @override
  String invitationSent(String email) {
    return 'Invitation sent to $email. You will be notified when it is accepted or declined.';
  }

  @override
  String get dashboardMembers => 'Members';

  @override
  String get ownerTag => 'owner';

  @override
  String ownedBy(String name) {
    return 'by $name';
  }

  @override
  String get removeAccess => 'Remove access';

  @override
  String get leaveDashboard => 'Leave';

  @override
  String get openDashboard => 'Open';

  @override
  String get clearDashboard => 'Clear dashboard';

  @override
  String get deleteDashboard => 'Delete dashboard';

  @override
  String confirmClearDashboard(String name) {
    return 'All movements, receipts and limits of \"$name\" are deleted. Accounts and categories are kept. This cannot be undone.';
  }

  @override
  String confirmDeleteDashboard(String name) {
    return '\"$name\" is deleted with all its content and every guest loses access. This cannot be undone.';
  }

  @override
  String confirmLeaveDashboard(String name) {
    return 'You stop seeing \"$name\". To come back, the owner has to invite you again.';
  }

  @override
  String confirmRemoveMember(String user, String name) {
    return '$user stops seeing \"$name\".';
  }

  @override
  String dashboardCreated(String name) {
    return 'Dashboard \"$name\" created.';
  }

  @override
  String get dashboardRenamed => 'Name changed.';

  @override
  String get dashboardClearedMsg => 'Dashboard cleared.';

  @override
  String get dashboardDeletedMsg => 'Dashboard deleted.';

  @override
  String get dashboardLeftMsg => 'You left the dashboard.';

  @override
  String get accessRemovedMsg => 'Access removed.';

  @override
  String get dashboardsNeedConnection =>
      'Managing and sharing dashboards needs a connection.';

  @override
  String get noNotifications2 => 'You have no notifications.';

  @override
  String get errDashboardForbidden =>
      'You do not have access to that dashboard.';

  @override
  String get errNotCreator => 'Only the person who added it can change it.';

  @override
  String get errOwnerOnly => 'Only the dashboard owner can do this.';

  @override
  String get errUserNotRegistered =>
      'You can only share with registered users.';

  @override
  String get errAlreadyMember =>
      'That person already has access to this dashboard.';

  @override
  String get errSelfInvite => 'You cannot share a dashboard with yourself.';

  @override
  String get errOwnerCannotLeave => 'The owner cannot leave their dashboard.';

  @override
  String get errPrincipalUndeletable =>
      'The main dashboard cannot be deleted; it can be cleared.';

  @override
  String get errNotPrincipal =>
      'Only the main dashboard is cleared; the others are deleted.';

  @override
  String get errInvitationClosed => 'The invitation was already answered.';

  @override
  String get dashboardIsPrincipal => 'Your main dashboard';

  @override
  String dashboardSharedCount(int count) {
    return 'Shared · $count members';
  }

  @override
  String get mainCurrency => 'Main currency';

  @override
  String get mainCurrencyHint => 'It is preselected and shown first.';

  @override
  String get mainCurrencySaved => 'Main currency saved.';

  @override
  String get budgetCurrency => 'Limit currency';

  @override
  String get mixedCurrencies => 'Mixed currencies';

  @override
  String get budgetMixedCurrency =>
      'All accounts of a limit must be in the same currency.';

  @override
  String get longTicket => 'Long receipt';

  @override
  String get longTicketHint =>
      'Photograph the receipt from top to bottom, in parts. Each photo must repeat a few lines from the end of the previous one.';

  @override
  String longTicketPartsCount(int count, int max) {
    return '$count of $max parts';
  }

  @override
  String longTicketPart(int number) {
    return 'Part $number';
  }

  @override
  String get longTicketAddPart => 'Add part';

  @override
  String get longTicketAddFromGallery => 'Add from gallery';

  @override
  String get longTicketRedoLast => 'Redo last';

  @override
  String get longTicketFinish => 'Finish';

  @override
  String longTicketMaxParts(int max) {
    return 'You reached the maximum of $max parts.';
  }

  @override
  String get longTicketAlignHint =>
      'Line up the top with the end of the previous part';

  @override
  String get longTicketTakePhoto => 'Take photo';

  @override
  String longTicketCameraError(Object error) {
    return 'Could not use the camera: $error';
  }

  @override
  String get longTicketMergePending =>
      'The parts are joined; sending them to the review screen is added in the next step.';

  @override
  String longTicketReadError(Object error) {
    return 'Could not read the parts: $error';
  }

  @override
  String longTicketMergedTitle(int rows) {
    return 'Joined receipt: $rows rows';
  }

  @override
  String longTicketPartOverlap(int number, int rows) {
    return 'Part $number: $rows repeated rows discarded';
  }

  @override
  String longTicketPartNotChained(int number) {
    return 'Part $number could not be chained to the previous one (not enough repeated lines). Redo it with more overlap.';
  }

  @override
  String longTicketPartAmbiguous(int number) {
    return 'Part $number matches the previous one in more than one place. Redo it with more overlap.';
  }
}
