import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @cannotReachServerCheckConnection.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con el servidor. Revisá tu conexión.'**
  String get cannotReachServerCheckConnection;

  /// No description provided for @notSyncedSession.
  ///
  /// In es, this message translates to:
  /// **'Sin sincronizar en esta sesión'**
  String get notSyncedSession;

  /// No description provided for @syncing.
  ///
  /// In es, this message translates to:
  /// **'Sincronizando…'**
  String get syncing;

  /// No description provided for @completeMatchesServer.
  ///
  /// In es, this message translates to:
  /// **'Completa: coincide con el servidor'**
  String get completeMatchesServer;

  /// No description provided for @notEverythingWasAppliedSee.
  ///
  /// In es, this message translates to:
  /// **'No se aplicó todo: ver el detalle'**
  String get notEverythingWasAppliedSee;

  /// No description provided for @doesNotMatchServer.
  ///
  /// In es, this message translates to:
  /// **'No coincide con el servidor'**
  String get doesNotMatchServer;

  /// No description provided for @syncFailed.
  ///
  /// In es, this message translates to:
  /// **'Falló la sincronización'**
  String get syncFailed;

  /// No description provided for @lastCompleteSync.
  ///
  /// In es, this message translates to:
  /// **'Última sincronización completa'**
  String get lastCompleteSync;

  /// No description provided for @phone.
  ///
  /// In es, this message translates to:
  /// **'En este celular'**
  String get phone;

  /// No description provided for @movements.
  ///
  /// In es, this message translates to:
  /// **'comprobantes'**
  String get movements;

  /// No description provided for @lines.
  ///
  /// In es, this message translates to:
  /// **'renglones'**
  String get lines;

  /// No description provided for @pendingSend.
  ///
  /// In es, this message translates to:
  /// **'Pendientes de enviar'**
  String get pendingSend;

  /// No description provided for @rejected.
  ///
  /// In es, this message translates to:
  /// **'Rechazadas'**
  String get rejected;

  /// No description provided for @conflict.
  ///
  /// In es, this message translates to:
  /// **'En conflicto'**
  String get conflict;

  /// No description provided for @pendingRejected.
  ///
  /// In es, this message translates to:
  /// **'Pendientes y rechazados'**
  String get pendingRejected;

  /// No description provided for @syncNow.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar ahora'**
  String get syncNow;

  /// No description provided for @noAccountsPhoneSyncWhile.
  ///
  /// In es, this message translates to:
  /// **'No hay cuentas en el celular. Sincronizá con conexión.'**
  String get noAccountsPhoneSyncWhile;

  /// No description provided for @willRecordIncomeThatAccount.
  ///
  /// In es, this message translates to:
  /// **'La cuenta {name} queda en {queda}. Registrá un ingreso en esa cuenta.'**
  String willRecordIncomeThatAccount(Object name, Object queda);

  /// No description provided for @notEnoughBalanceTransferAvailable.
  ///
  /// In es, this message translates to:
  /// **'No dispone del saldo solicitado a transferir ({total}) en {name} (disponible {disponible}). Realizá un ingreso en la cuenta de origen.'**
  String notEnoughBalanceTransferAvailable(
      Object total, Object name, Object disponible);

  /// No description provided for @accounts.
  ///
  /// In es, this message translates to:
  /// **'Cuentas y Medios de Pago'**
  String get accounts;

  /// No description provided for @newAccount.
  ///
  /// In es, this message translates to:
  /// **'Nueva cuenta'**
  String get newAccount;

  /// No description provided for @all.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get all;

  /// No description provided for @active.
  ///
  /// In es, this message translates to:
  /// **'Activas'**
  String get active;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @noAccounts.
  ///
  /// In es, this message translates to:
  /// **'No hay cuentas registradas'**
  String get noAccounts;

  /// No description provided for @accountDeactivated.
  ///
  /// In es, this message translates to:
  /// **'Cuenta desactivada.'**
  String get accountDeactivated;

  /// No description provided for @accountActivated.
  ///
  /// In es, this message translates to:
  /// **'Cuenta activada.'**
  String get accountActivated;

  /// No description provided for @deleteAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar la cuenta?'**
  String get deleteAccount;

  /// No description provided for @withoutMovementsDeletedMovementsDeactivated.
  ///
  /// In es, this message translates to:
  /// **'Sin movimientos se elimina; con movimientos se desactiva.'**
  String get withoutMovementsDeletedMovementsDeactivated;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @accountDeleted.
  ///
  /// In es, this message translates to:
  /// **'Cuenta eliminada.'**
  String get accountDeleted;

  /// No description provided for @editAccount.
  ///
  /// In es, this message translates to:
  /// **'Editar cuenta'**
  String get editAccount;

  /// No description provided for @name.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get name;

  /// No description provided for @currency.
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get currency;

  /// No description provided for @currencyLockedAccountHasMovements.
  ///
  /// In es, this message translates to:
  /// **'La moneda no se cambia: la cuenta tiene movimientos.'**
  String get currencyLockedAccountHasMovements;

  /// No description provided for @icon.
  ///
  /// In es, this message translates to:
  /// **'Ícono'**
  String get icon;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @accountCreated.
  ///
  /// In es, this message translates to:
  /// **'Cuenta creada.'**
  String get accountCreated;

  /// No description provided for @accountUpdated.
  ///
  /// In es, this message translates to:
  /// **'Cuenta actualizada.'**
  String get accountUpdated;

  /// No description provided for @inactive.
  ///
  /// In es, this message translates to:
  /// **'Inactiva'**
  String get inactive;

  /// No description provided for @movements2.
  ///
  /// In es, this message translates to:
  /// **'movimientos'**
  String get movements2;

  /// No description provided for @pendingSync.
  ///
  /// In es, this message translates to:
  /// **' · sin sincronizar'**
  String get pendingSync;

  /// No description provided for @edit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get edit;

  /// No description provided for @deactivate.
  ///
  /// In es, this message translates to:
  /// **'Desactivar'**
  String get deactivate;

  /// No description provided for @activate.
  ///
  /// In es, this message translates to:
  /// **'Activar'**
  String get activate;

  /// No description provided for @code.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get code;

  /// No description provided for @sessionExpiredPleaseSignAgain.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión expiró. Iniciá sesión nuevamente.'**
  String get sessionExpiredPleaseSignAgain;

  /// No description provided for @signedOutDeviceButServer.
  ///
  /// In es, this message translates to:
  /// **'Se cerró la sesión en este celular, pero no se pudo avisar al servidor{detail}.'**
  String signedOutDeviceButServer(Object detail);

  /// No description provided for @sign.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get sign;

  /// No description provided for @youExampleCom.
  ///
  /// In es, this message translates to:
  /// **'tu@email.com'**
  String get youExampleCom;

  /// No description provided for @enterEmail.
  ///
  /// In es, this message translates to:
  /// **'Ingresá tu email'**
  String get enterEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Email inválido'**
  String get invalidEmail;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @enterPassword.
  ///
  /// In es, this message translates to:
  /// **'Ingresá tu contraseña'**
  String get enterPassword;

  /// No description provided for @sign2.
  ///
  /// In es, this message translates to:
  /// **'Acceder'**
  String get sign2;

  /// No description provided for @categories.
  ///
  /// In es, this message translates to:
  /// **'Rubros y Categorías'**
  String get categories;

  /// No description provided for @newCategory.
  ///
  /// In es, this message translates to:
  /// **'Nueva categoría'**
  String get newCategory;

  /// No description provided for @searchCategory.
  ///
  /// In es, this message translates to:
  /// **'Buscar categoría'**
  String get searchCategory;

  /// No description provided for @inactive2.
  ///
  /// In es, this message translates to:
  /// **'Inactivas'**
  String get inactive2;

  /// No description provided for @noCategories.
  ///
  /// In es, this message translates to:
  /// **'No hay categorías'**
  String get noCategories;

  /// No description provided for @categoryDeactivated.
  ///
  /// In es, this message translates to:
  /// **'Categoría desactivada.'**
  String get categoryDeactivated;

  /// No description provided for @categoryActivated.
  ///
  /// In es, this message translates to:
  /// **'Categoría activada.'**
  String get categoryActivated;

  /// No description provided for @deleteCategory.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar la categoría?'**
  String get deleteCategory;

  /// No description provided for @categoryDeleted.
  ///
  /// In es, this message translates to:
  /// **'Categoría eliminada.'**
  String get categoryDeleted;

  /// No description provided for @renameCategory.
  ///
  /// In es, this message translates to:
  /// **'Renombrar categoría'**
  String get renameCategory;

  /// No description provided for @categoryCreated.
  ///
  /// In es, this message translates to:
  /// **'Categoría creada.'**
  String get categoryCreated;

  /// No description provided for @categoryRenamed.
  ///
  /// In es, this message translates to:
  /// **'Categoría renombrada.'**
  String get categoryRenamed;

  /// No description provided for @inactive3.
  ///
  /// In es, this message translates to:
  /// **'inactiva'**
  String get inactive3;

  /// No description provided for @reserved.
  ///
  /// In es, this message translates to:
  /// **'reservada'**
  String get reserved;

  /// No description provided for @reserved2.
  ///
  /// In es, this message translates to:
  /// **'Reservada'**
  String get reserved2;

  /// No description provided for @rename.
  ///
  /// In es, this message translates to:
  /// **'Renombrar'**
  String get rename;

  /// No description provided for @syncFailed2.
  ///
  /// In es, this message translates to:
  /// **'No se pudo sincronizar'**
  String get syncFailed2;

  /// No description provided for @operationSWereNotApplied.
  ///
  /// In es, this message translates to:
  /// **'{needsAttention} operación(es) no se aplicaron. Ver Ajustes → Pendientes y rechazados.'**
  String operationSWereNotApplied(Object needsAttention);

  /// No description provided for @localDataDoesNotMatch.
  ///
  /// In es, this message translates to:
  /// **'Los datos locales no coinciden con el servidor; la próxima vez se descarga todo.'**
  String get localDataDoesNotMatch;

  /// No description provided for @lastRate.
  ///
  /// In es, this message translates to:
  /// **'Última cotización'**
  String get lastRate;

  /// No description provided for @exchangeRateOfflineUsdNot.
  ///
  /// In es, this message translates to:
  /// **'Cotización: sin conexión · USD sin convertir'**
  String get exchangeRateOfflineUsdNot;

  /// No description provided for @exchangeRateUnavailableUsdNot.
  ///
  /// In es, this message translates to:
  /// **'Cotización no disponible · USD sin convertir'**
  String get exchangeRateUnavailableUsdNot;

  /// No description provided for @showingLastLoadedData.
  ///
  /// In es, this message translates to:
  /// **'Se muestran los datos de la última carga'**
  String get showingLastLoadedData;

  /// No description provided for @recordIncome.
  ///
  /// In es, this message translates to:
  /// **'Registrá un ingreso'**
  String get recordIncome;

  /// No description provided for @noExchangeRate.
  ///
  /// In es, this message translates to:
  /// **'sin cotización'**
  String get noExchangeRate;

  /// No description provided for @notifications.
  ///
  /// In es, this message translates to:
  /// **'Novedades'**
  String get notifications;

  /// No description provided for @limitNearTop.
  ///
  /// In es, this message translates to:
  /// **'Límite \'{titulo}\' cercano al tope ({porcentaje}%)'**
  String limitNearTop(Object titulo, Object porcentaje);

  /// No description provided for @limitReached.
  ///
  /// In es, this message translates to:
  /// **'Límite \'{titulo}\' alcanzado ({porcentaje}%)'**
  String limitReached(Object titulo, Object porcentaje);

  /// No description provided for @limitHasFinishedExpired.
  ///
  /// In es, this message translates to:
  /// **'El límite \'{titulo}\' ha finalizado y está vencido'**
  String limitHasFinishedExpired(Object titulo);

  /// No description provided for @noPendingNotifications.
  ///
  /// In es, this message translates to:
  /// **'Sin novedades pendientes'**
  String get noPendingNotifications;

  /// No description provided for @balanceWillNegative.
  ///
  /// In es, this message translates to:
  /// **'La cuenta queda en negativo'**
  String get balanceWillNegative;

  /// No description provided for @saveAnyway.
  ///
  /// In es, this message translates to:
  /// **'Guardar igual'**
  String get saveAnyway;

  /// No description provided for @ticketRecordedServer.
  ///
  /// In es, this message translates to:
  /// **'Ticket registrado en el servidor.'**
  String get ticketRecordedServer;

  /// No description provided for @expense.
  ///
  /// In es, this message translates to:
  /// **'Egreso'**
  String get expense;

  /// No description provided for @confirmingQrTicketRequiresConnection.
  ///
  /// In es, this message translates to:
  /// **' Confirmar un ticket QR requiere conexión.'**
  String get confirmingQrTicketRequiresConnection;

  /// No description provided for @correctExpense.
  ///
  /// In es, this message translates to:
  /// **'Corregir Egreso'**
  String get correctExpense;

  /// No description provided for @newExpense.
  ///
  /// In es, this message translates to:
  /// **'Nuevo Egreso'**
  String get newExpense;

  /// No description provided for @registerExpense.
  ///
  /// In es, this message translates to:
  /// **'Registrar Gasto ({totalFormateado})'**
  String registerExpense(Object totalFormateado);

  /// No description provided for @scanReceipt.
  ///
  /// In es, this message translates to:
  /// **'Escanear ticket'**
  String get scanReceipt;

  /// No description provided for @scanTicketQr.
  ///
  /// In es, this message translates to:
  /// **'Escanear QR del Ticket'**
  String get scanTicketQr;

  /// No description provided for @pointCameraReceiptQrCode.
  ///
  /// In es, this message translates to:
  /// **'Apuntá la cámara al código QR del ticket'**
  String get pointCameraReceiptQrCode;

  /// No description provided for @ifMerchantNewPageText.
  ///
  /// In es, this message translates to:
  /// **'Si este comercio es nuevo, el texto de la página se enviará a un servicio externo para aprender sus reglas.'**
  String get ifMerchantNewPageText;

  /// No description provided for @featureNotAvailableNow.
  ///
  /// In es, this message translates to:
  /// **'Función no disponible por ahora'**
  String get featureNotAvailableNow;

  /// No description provided for @addLeastOnePhotoReceipt.
  ///
  /// In es, this message translates to:
  /// **'Debes agregar al menos una foto del ticket'**
  String get addLeastOnePhotoReceipt;

  /// No description provided for @noProductsWereDetectedReceipt.
  ///
  /// In es, this message translates to:
  /// **'No se detectaron productos en el ticket.'**
  String get noProductsWereDetectedReceipt;

  /// No description provided for @receiptReadDeviceLines.
  ///
  /// In es, this message translates to:
  /// **'Ticket leído en el dispositivo ({items} renglones)'**
  String receiptReadDeviceLines(Object items);

  /// No description provided for @couldNotReadReceipt.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el ticket: {e}'**
  String couldNotReadReceipt(Object e);

  /// No description provided for @scanReceiptUsingAutoCrop.
  ///
  /// In es, this message translates to:
  /// **'Escanéa el ticket con auto-recorte, lee el código QR o selecciona una foto desde tu galería.'**
  String get scanReceiptUsingAutoCrop;

  /// No description provided for @readingReceiptDevice.
  ///
  /// In es, this message translates to:
  /// **'Leyendo el ticket en el dispositivo...'**
  String get readingReceiptDevice;

  /// No description provided for @extractingProductsNetAmountsDiscounts.
  ///
  /// In es, this message translates to:
  /// **'Extrayendo productos, montos netos y descuentos...'**
  String get extractingProductsNetAmountsDiscounts;

  /// No description provided for @noScansAddedYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no agregaste escaneos'**
  String get noScansAddedYet;

  /// No description provided for @useScanScanQrGallery.
  ///
  /// In es, this message translates to:
  /// **'Usa el botón Escanear, Escanear QR o Galería inferior'**
  String get useScanScanQrGallery;

  /// No description provided for @scan.
  ///
  /// In es, this message translates to:
  /// **'Escaneo #{numFoto} del ticket'**
  String scan(Object numFoto);

  /// No description provided for @scan2.
  ///
  /// In es, this message translates to:
  /// **'Escanear'**
  String get scan2;

  /// No description provided for @scanQr.
  ///
  /// In es, this message translates to:
  /// **'Escanear QR'**
  String get scanQr;

  /// No description provided for @gallery.
  ///
  /// In es, this message translates to:
  /// **'Galería'**
  String get gallery;

  /// No description provided for @finishLoading.
  ///
  /// In es, this message translates to:
  /// **'Finalizar carga'**
  String get finishLoading;

  /// No description provided for @readAi.
  ///
  /// In es, this message translates to:
  /// **'Leer con IA'**
  String get readAi;

  /// No description provided for @income.
  ///
  /// In es, this message translates to:
  /// **'Ingreso'**
  String get income;

  /// No description provided for @correctIncome.
  ///
  /// In es, this message translates to:
  /// **'Corregir Ingreso'**
  String get correctIncome;

  /// No description provided for @newIncome.
  ///
  /// In es, this message translates to:
  /// **'Nuevo Ingreso'**
  String get newIncome;

  /// No description provided for @invalidAmountMax2Decimals.
  ///
  /// In es, this message translates to:
  /// **'Importe inválido (máx. 2 decimales)'**
  String get invalidAmountMax2Decimals;

  /// No description provided for @budgets.
  ///
  /// In es, this message translates to:
  /// **'Límites y Presupuestos'**
  String get budgets;

  /// No description provided for @newBudget.
  ///
  /// In es, this message translates to:
  /// **'Nuevo límite'**
  String get newBudget;

  /// No description provided for @all2.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get all2;

  /// No description provided for @current.
  ///
  /// In es, this message translates to:
  /// **'En curso'**
  String get current;

  /// No description provided for @due.
  ///
  /// In es, this message translates to:
  /// **'Vencidos'**
  String get due;

  /// No description provided for @exceeded.
  ///
  /// In es, this message translates to:
  /// **'Excedidos'**
  String get exceeded;

  /// No description provided for @noBudgets.
  ///
  /// In es, this message translates to:
  /// **'No hay presupuestos'**
  String get noBudgets;

  /// No description provided for @budgetRenewed.
  ///
  /// In es, this message translates to:
  /// **'Límite renovado.'**
  String get budgetRenewed;

  /// No description provided for @deleteBudget.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar el límite?'**
  String get deleteBudget;

  /// No description provided for @budgetDeleted.
  ///
  /// In es, this message translates to:
  /// **'Límite eliminado.'**
  String get budgetDeleted;

  /// No description provided for @editBudget.
  ///
  /// In es, this message translates to:
  /// **'Editar límite'**
  String get editBudget;

  /// No description provided for @from.
  ///
  /// In es, this message translates to:
  /// **'Desde'**
  String get from;

  /// No description provided for @to.
  ///
  /// In es, this message translates to:
  /// **'Hasta'**
  String get to;

  /// No description provided for @limit.
  ///
  /// In es, this message translates to:
  /// **'Límite de gasto'**
  String get limit;

  /// No description provided for @budgetUpdated.
  ///
  /// In es, this message translates to:
  /// **'Límite actualizado.'**
  String get budgetUpdated;

  /// No description provided for @categories2.
  ///
  /// In es, this message translates to:
  /// **'Categorías'**
  String get categories2;

  /// No description provided for @accounts2.
  ///
  /// In es, this message translates to:
  /// **'Cuentas'**
  String get accounts2;

  /// No description provided for @budgetCreated.
  ///
  /// In es, this message translates to:
  /// **'Límite creado.'**
  String get budgetCreated;

  /// No description provided for @currentBudgets.
  ///
  /// In es, this message translates to:
  /// **'Presupuestos vigentes'**
  String get currentBudgets;

  /// No description provided for @limits.
  ///
  /// In es, this message translates to:
  /// **'Total topes'**
  String get limits;

  /// No description provided for @spent.
  ///
  /// In es, this message translates to:
  /// **'Gastado'**
  String get spent;

  /// No description provided for @remaining.
  ///
  /// In es, this message translates to:
  /// **'Restante'**
  String get remaining;

  /// No description provided for @excess.
  ///
  /// In es, this message translates to:
  /// **'Excedente'**
  String get excess;

  /// No description provided for @left.
  ///
  /// In es, this message translates to:
  /// **'Resta'**
  String get left;

  /// No description provided for @renew.
  ///
  /// In es, this message translates to:
  /// **'Renovar'**
  String get renew;

  /// No description provided for @pending.
  ///
  /// In es, this message translates to:
  /// **' Pendientes: {pending}.'**
  String pending(Object pending);

  /// No description provided for @savedPhoneWillSentServer.
  ///
  /// In es, this message translates to:
  /// **'{what} guardado en el celular. Se enviará al servidor al sincronizar.{suffix}'**
  String savedPhoneWillSentServer(Object what, Object suffix);

  /// No description provided for @couldNotReadDataPhone.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron leer los datos del celular'**
  String get couldNotReadDataPhone;

  /// No description provided for @savedPhoneSending.
  ///
  /// In es, this message translates to:
  /// **'{ok} Guardado en el celular; enviando…'**
  String savedPhoneSending(Object ok);

  /// No description provided for @dateRange.
  ///
  /// In es, this message translates to:
  /// **'Rango de fechas'**
  String get dateRange;

  /// No description provided for @movements3.
  ///
  /// In es, this message translates to:
  /// **'Movimientos'**
  String get movements3;

  /// No description provided for @searchTextAmount.
  ///
  /// In es, this message translates to:
  /// **'Buscar por texto o monto'**
  String get searchTextAmount;

  /// No description provided for @results.
  ///
  /// In es, this message translates to:
  /// **'resultados'**
  String get results;

  /// No description provided for @lastMovements.
  ///
  /// In es, this message translates to:
  /// **'Últimos {total} movimientos'**
  String lastMovements(Object total);

  /// No description provided for @noMovements.
  ///
  /// In es, this message translates to:
  /// **'No hay movimientos'**
  String get noMovements;

  /// No description provided for @will.
  ///
  /// In es, this message translates to:
  /// **'queda en'**
  String get will;

  /// No description provided for @recordIncomeThatAccount.
  ///
  /// In es, this message translates to:
  /// **'Registrá un ingreso en esa cuenta.'**
  String get recordIncomeThatAccount;

  /// No description provided for @savedPhoneSending2.
  ///
  /// In es, this message translates to:
  /// **'Guardado en el celular; enviando…'**
  String get savedPhoneSending2;

  /// No description provided for @completeSourceDestinationValidAmount.
  ///
  /// In es, this message translates to:
  /// **'Completá origen, destino y un monto válido'**
  String get completeSourceDestinationValidAmount;

  /// No description provided for @deleteMovement.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar el comprobante?'**
  String get deleteMovement;

  /// No description provided for @removedAllItsLines.
  ///
  /// In es, this message translates to:
  /// **'Se elimina con todos sus renglones.'**
  String get removedAllItsLines;

  /// No description provided for @editMovement.
  ///
  /// In es, this message translates to:
  /// **'Editar comprobante'**
  String get editMovement;

  /// No description provided for @movementNotPhoneWasDeleted.
  ///
  /// In es, this message translates to:
  /// **'El comprobante no está en el celular (o se eliminó). Sincronizá y volvé a intentar.'**
  String get movementNotPhoneWasDeleted;

  /// No description provided for @deleteMovement2.
  ///
  /// In es, this message translates to:
  /// **'Eliminar comprobante'**
  String get deleteMovement2;

  /// No description provided for @header.
  ///
  /// In es, this message translates to:
  /// **'Encabezado'**
  String get header;

  /// No description provided for @generalConcept.
  ///
  /// In es, this message translates to:
  /// **'Concepto general'**
  String get generalConcept;

  /// No description provided for @accountAllLines.
  ///
  /// In es, this message translates to:
  /// **'Cuenta (todos los renglones)'**
  String get accountAllLines;

  /// No description provided for @saveHeader.
  ///
  /// In es, this message translates to:
  /// **'Guardar encabezado'**
  String get saveHeader;

  /// No description provided for @lines2.
  ///
  /// In es, this message translates to:
  /// **'Renglones'**
  String get lines2;

  /// No description provided for @notServerYetLinesCan.
  ///
  /// In es, this message translates to:
  /// **'Todavía no está en el servidor: los renglones se editan después de sincronizar.'**
  String get notServerYetLinesCan;

  /// No description provided for @transfer.
  ///
  /// In es, this message translates to:
  /// **'Transferencia'**
  String get transfer;

  /// No description provided for @from2.
  ///
  /// In es, this message translates to:
  /// **'Desde (origen)'**
  String get from2;

  /// No description provided for @to2.
  ///
  /// In es, this message translates to:
  /// **'Hacia (destino)'**
  String get to2;

  /// No description provided for @amount.
  ///
  /// In es, this message translates to:
  /// **'Monto'**
  String get amount;

  /// No description provided for @saveTransfer.
  ///
  /// In es, this message translates to:
  /// **'Guardar transferencia'**
  String get saveTransfer;

  /// No description provided for @concept.
  ///
  /// In es, this message translates to:
  /// **'Concepto'**
  String get concept;

  /// No description provided for @category.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get category;

  /// No description provided for @deleteLine.
  ///
  /// In es, this message translates to:
  /// **'Borrar renglón'**
  String get deleteLine;

  /// No description provided for @saveLine.
  ///
  /// In es, this message translates to:
  /// **'Guardar renglón'**
  String get saveLine;

  /// No description provided for @showingLinesFilter.
  ///
  /// In es, this message translates to:
  /// **'Se muestran {details} de {detailsCount} renglones (filtro)'**
  String showingLinesFilter(Object details, Object detailsCount);

  /// No description provided for @unit.
  ///
  /// In es, this message translates to:
  /// **'unit.'**
  String get unit;

  /// No description provided for @signOut.
  ///
  /// In es, this message translates to:
  /// **'¿Cerrar sesión?'**
  String get signOut;

  /// No description provided for @allDataStoredPhoneWill.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán todos los datos guardados en este celular. Lo que ya está en el servidor no se toca.'**
  String get allDataStoredPhoneWill;

  /// No description provided for @signOut2.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get signOut2;

  /// No description provided for @session.
  ///
  /// In es, this message translates to:
  /// **'Sesión'**
  String get session;

  /// No description provided for @offline.
  ///
  /// In es, this message translates to:
  /// **'sin conexión'**
  String get offline;

  /// No description provided for @deletesDataStoredPhoneSettings.
  ///
  /// In es, this message translates to:
  /// **'Borra los datos guardados en este celular. Se conservan los ajustes.'**
  String get deletesDataStoredPhoneSettings;

  /// No description provided for @offlineData.
  ///
  /// In es, this message translates to:
  /// **'Datos sin conexión'**
  String get offlineData;

  /// No description provided for @server.
  ///
  /// In es, this message translates to:
  /// **'Servidor'**
  String get server;

  /// No description provided for @apiAddress.
  ///
  /// In es, this message translates to:
  /// **'Dirección de la API'**
  String get apiAddress;

  /// No description provided for @notConfiguredApiBaseUrl.
  ///
  /// In es, this message translates to:
  /// **'Sin configurar (API_BASE_URL)'**
  String get notConfiguredApiBaseUrl;

  /// No description provided for @discard.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar?'**
  String get discard;

  /// No description provided for @serverVersionKeptChangeLost.
  ///
  /// In es, this message translates to:
  /// **'Queda la versión del servidor. Tu cambio se pierde.'**
  String get serverVersionKeptChangeLost;

  /// No description provided for @removedPhoneLocalBalanceReverted.
  ///
  /// In es, this message translates to:
  /// **'Se quita del celular y el saldo local se revierte.'**
  String get removedPhoneLocalBalanceReverted;

  /// No description provided for @discard2.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get discard2;

  /// No description provided for @discarded.
  ///
  /// In es, this message translates to:
  /// **'Descartada'**
  String get discarded;

  /// No description provided for @nothingPendingEverythingWasApplied.
  ///
  /// In es, this message translates to:
  /// **'Nada pendiente: todo se aplicó.'**
  String get nothingPendingEverythingWasApplied;

  /// No description provided for @rejected2.
  ///
  /// In es, this message translates to:
  /// **'Rechazada'**
  String get rejected2;

  /// No description provided for @conflictServerVersionApplied.
  ///
  /// In es, this message translates to:
  /// **'Conflicto (se aplicó la del servidor)'**
  String get conflictServerVersionApplied;

  /// No description provided for @pending2.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get pending2;

  /// No description provided for @reason.
  ///
  /// In es, this message translates to:
  /// **'Motivo'**
  String get reason;

  /// No description provided for @attempts.
  ///
  /// In es, this message translates to:
  /// **'Intentos'**
  String get attempts;

  /// No description provided for @correct.
  ///
  /// In es, this message translates to:
  /// **'Corregir'**
  String get correct;

  /// No description provided for @queuedAgainChanges.
  ///
  /// In es, this message translates to:
  /// **'Reencolada con tus cambios'**
  String get queuedAgainChanges;

  /// No description provided for @retryMyChanges.
  ///
  /// In es, this message translates to:
  /// **'Reintentar con mis cambios'**
  String get retryMyChanges;

  /// No description provided for @keepServerVersion.
  ///
  /// In es, this message translates to:
  /// **'Quedarme con la del servidor'**
  String get keepServerVersion;

  /// No description provided for @correctTransfer.
  ///
  /// In es, this message translates to:
  /// **'Corregir Transferencia'**
  String get correctTransfer;

  /// No description provided for @transferMoney.
  ///
  /// In es, this message translates to:
  /// **'Transferir Dinero'**
  String get transferMoney;

  /// No description provided for @noOtherAccount.
  ///
  /// In es, this message translates to:
  /// **'No hay otra cuenta en {currency}'**
  String noOtherAccount(Object currency);

  /// No description provided for @selectDestination.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar destino'**
  String get selectDestination;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In es, this message translates to:
  /// **'Email o contraseña incorrectos.'**
  String get errInvalidCredentials;

  /// No description provided for @errAccountLocked.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos fallidos. Probá de nuevo en 15 minutos.'**
  String get errAccountLocked;

  /// No description provided for @errRateLimited.
  ///
  /// In es, this message translates to:
  /// **'Demasiadas solicitudes. Esperá un momento.'**
  String get errRateLimited;

  /// No description provided for @errInvalidRefresh.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión expiró. Iniciá sesión nuevamente.'**
  String get errInvalidRefresh;

  /// No description provided for @errInvalidToken.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión expiró. Iniciá sesión nuevamente.'**
  String get errInvalidToken;

  /// No description provided for @errUnauthorized.
  ///
  /// In es, this message translates to:
  /// **'Tenés que iniciar sesión.'**
  String get errUnauthorized;

  /// No description provided for @errNotFound.
  ///
  /// In es, this message translates to:
  /// **'El servidor no tiene esta función o el dato no existe.'**
  String get errNotFound;

  /// No description provided for @errDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Ya existe un registro con esos datos.'**
  String get errDuplicate;

  /// No description provided for @errEmailTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una cuenta con ese email.'**
  String get errEmailTaken;

  /// No description provided for @errInsufficientFunds.
  ///
  /// In es, this message translates to:
  /// **'No dispone del saldo a transferir. Realizá un ingreso en la cuenta de origen.'**
  String get errInsufficientFunds;

  /// No description provided for @errReservedCategory.
  ///
  /// In es, this message translates to:
  /// **'Esa categoría está reservada por el sistema.'**
  String get errReservedCategory;

  /// No description provided for @errSameAccount.
  ///
  /// In es, this message translates to:
  /// **'La cuenta de origen y la de destino no pueden ser iguales.'**
  String get errSameAccount;

  /// No description provided for @errCurrencyMismatch.
  ///
  /// In es, this message translates to:
  /// **'No se puede transferir entre cuentas de distinta moneda.'**
  String get errCurrencyMismatch;

  /// No description provided for @errAccountInactive.
  ///
  /// In es, this message translates to:
  /// **'La cuenta está inactiva.'**
  String get errAccountInactive;

  /// No description provided for @errAccountHasFunds.
  ///
  /// In es, this message translates to:
  /// **'Esta cuenta tiene dinero, deje la cuenta vacía y vuelva a intentarlo.'**
  String get errAccountHasFunds;

  /// No description provided for @errCurrencyLocked.
  ///
  /// In es, this message translates to:
  /// **'No se puede cambiar la moneda de una cuenta con movimientos.'**
  String get errCurrencyLocked;

  /// No description provided for @errDuplicateName.
  ///
  /// In es, this message translates to:
  /// **'Ya existe otro registro con ese nombre.'**
  String get errDuplicateName;

  /// No description provided for @errInvalidPeriod.
  ///
  /// In es, this message translates to:
  /// **'La fecha hasta no puede ser anterior a la fecha desde.'**
  String get errInvalidPeriod;

  /// No description provided for @errLastDetail.
  ///
  /// In es, this message translates to:
  /// **'Es el único renglón del comprobante; eliminá el movimiento completo.'**
  String get errLastDetail;

  /// No description provided for @errTransferEdit.
  ///
  /// In es, this message translates to:
  /// **'Una transferencia se edita como par (origen, destino y monto).'**
  String get errTransferEdit;

  /// No description provided for @errVersionConflict.
  ///
  /// In es, this message translates to:
  /// **'El registro cambió en el servidor.'**
  String get errVersionConflict;

  /// No description provided for @errCategoryInactive.
  ///
  /// In es, this message translates to:
  /// **'La categoría está inactiva.'**
  String get errCategoryInactive;

  /// No description provided for @errCatalogNotSynced.
  ///
  /// In es, this message translates to:
  /// **'Faltan datos del servidor en el celular: sincronizá con conexión.'**
  String get errCatalogNotSynced;

  /// No description provided for @errInternalError.
  ///
  /// In es, this message translates to:
  /// **'Error interno del servidor.'**
  String get errInternalError;

  /// No description provided for @errNotAvailable.
  ///
  /// In es, this message translates to:
  /// **'Función no disponible por ahora.'**
  String get errNotAvailable;

  /// No description provided for @errConfigMissing.
  ///
  /// In es, this message translates to:
  /// **'La app no tiene configurada la dirección del servidor (API_BASE_URL).'**
  String get errConfigMissing;

  /// No description provided for @errUnexpectedResponse.
  ///
  /// In es, this message translates to:
  /// **'El servidor respondió algo inesperado.'**
  String get errUnexpectedResponse;

  /// No description provided for @errInvalidData.
  ///
  /// In es, this message translates to:
  /// **'Datos inválidos: {message}'**
  String errInvalidData(String message);

  /// No description provided for @errNetwork.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con el servidor. Revisá tu conexión.'**
  String get errNetwork;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
