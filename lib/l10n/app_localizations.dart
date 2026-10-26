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

  /// No description provided for @selectAccount.
  ///
  /// In es, this message translates to:
  /// **'Seleccioná una cuenta'**
  String get selectAccount;

  /// No description provided for @operationNoLongerQueue.
  ///
  /// In es, this message translates to:
  /// **'La operación ya no está en la cola'**
  String get operationNoLongerQueue;

  /// No description provided for @onlyEditsConflictCanRetried.
  ///
  /// In es, this message translates to:
  /// **'Solo se reintentan ediciones en conflicto'**
  String get onlyEditsConflictCanRetried;

  /// No description provided for @voucherNoLongerExistsPhone.
  ///
  /// In es, this message translates to:
  /// **'El comprobante ya no existe en el celular'**
  String get voucherNoLongerExistsPhone;

  /// No description provided for @onlyRejectedCreationsCanCorrected.
  ///
  /// In es, this message translates to:
  /// **'Solo se corrigen altas rechazadas'**
  String get onlyRejectedCreationsCanCorrected;

  /// No description provided for @unknownIcon.
  ///
  /// In es, this message translates to:
  /// **'Ícono desconocido'**
  String get unknownIcon;

  /// No description provided for @account.
  ///
  /// In es, this message translates to:
  /// **'La cuenta'**
  String get account;

  /// No description provided for @currencyAccountMovementsCannotChange.
  ///
  /// In es, this message translates to:
  /// **'No se puede cambiar la moneda de una cuenta con movimientos'**
  String get currencyAccountMovementsCannotChange;

  /// No description provided for @noChangesSave.
  ///
  /// In es, this message translates to:
  /// **'No hay cambios para guardar'**
  String get noChangesSave;

  /// No description provided for @nameMustHaveLeastAccountnamemin.
  ///
  /// In es, this message translates to:
  /// **'El nombre debe tener al menos {accountNameMin} caracteres'**
  String nameMustHaveLeastAccountnamemin(Object accountNameMin);

  /// No description provided for @nameCannotExceedAccountnamemaxCharacters.
  ///
  /// In es, this message translates to:
  /// **'El nombre no puede superar {accountNameMax} caracteres'**
  String nameCannotExceedAccountnamemaxCharacters(Object accountNameMax);

  /// No description provided for @selectRangeReport.
  ///
  /// In es, this message translates to:
  /// **'Selecciona rango para el reporte'**
  String get selectRangeReport;

  /// No description provided for @reportsAnalytics.
  ///
  /// In es, this message translates to:
  /// **'Reportes y Analíticas'**
  String get reportsAnalytics;

  /// No description provided for @refreshReport.
  ///
  /// In es, this message translates to:
  /// **'Actualizar reporte'**
  String get refreshReport;

  /// No description provided for @dayDay.
  ///
  /// In es, this message translates to:
  /// **'Día a Día'**
  String get dayDay;

  /// No description provided for @month.
  ///
  /// In es, this message translates to:
  /// **'Este Mes'**
  String get month;

  /// No description provided for @previousMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes Anterior'**
  String get previousMonth;

  /// No description provided for @currentYear.
  ///
  /// In es, this message translates to:
  /// **'Año Actual'**
  String get currentYear;

  /// No description provided for @frequentConceptsDetail.
  ///
  /// In es, this message translates to:
  /// **'Detalle de Conceptos Frecuentes'**
  String get frequentConceptsDetail;

  /// No description provided for @annualOverview.
  ///
  /// In es, this message translates to:
  /// **'Ejercicio Anual'**
  String get annualOverview;

  /// No description provided for @annualIncome.
  ///
  /// In es, this message translates to:
  /// **'Ingresos Anuales'**
  String get annualIncome;

  /// No description provided for @annualExpenses.
  ///
  /// In es, this message translates to:
  /// **'Egresos Anuales'**
  String get annualExpenses;

  /// No description provided for @netBalance.
  ///
  /// In es, this message translates to:
  /// **'Balance Neto'**
  String get netBalance;

  /// No description provided for @savingsRate.
  ///
  /// In es, this message translates to:
  /// **'Tasa de Ahorro'**
  String get savingsRate;

  /// No description provided for @incomeVsExpensesMonth.
  ///
  /// In es, this message translates to:
  /// **'Ingresos vs Egresos Mes a Mes'**
  String get incomeVsExpensesMonth;

  /// No description provided for @detailedMonthlyBreakdown.
  ///
  /// In es, this message translates to:
  /// **'Desglose Mensual Detallado'**
  String get detailedMonthlyBreakdown;

  /// No description provided for @incIngresoscents.
  ///
  /// In es, this message translates to:
  /// **'Ing: {ingresosCents}'**
  String incIngresoscents(Object ingresosCents);

  /// No description provided for @expEgresoscents.
  ///
  /// In es, this message translates to:
  /// **'Egr: {egresosCents}'**
  String expEgresoscents(Object egresosCents);

  /// No description provided for @dailySpendingCurve.
  ///
  /// In es, this message translates to:
  /// **'Curva de Gasto Diario'**
  String get dailySpendingCurve;

  /// No description provided for @monthTotal.
  ///
  /// In es, this message translates to:
  /// **'Total del Mes'**
  String get monthTotal;

  /// No description provided for @highestPeak.
  ///
  /// In es, this message translates to:
  /// **'Pico Más Alto'**
  String get highestPeak;

  /// No description provided for @dailyExpenseTrend.
  ///
  /// In es, this message translates to:
  /// **'Trayectoria Diaria de Egresos'**
  String get dailyExpenseTrend;

  /// No description provided for @noExpensesPeriod.
  ///
  /// In es, this message translates to:
  /// **'No hay egresos en este período'**
  String get noExpensesPeriod;

  /// No description provided for @totalExpenses.
  ///
  /// In es, this message translates to:
  /// **'Total Gastos'**
  String get totalExpenses;

  /// No description provided for @tostringasfixedTotal.
  ///
  /// In es, this message translates to:
  /// **'{toStringAsFixed}% del total'**
  String tostringasfixedTotal(Object toStringAsFixed);

  /// No description provided for @dayDianumSpentEgresoscents.
  ///
  /// In es, this message translates to:
  /// **'Día {diaNum}\nGasto: {egresosCents}'**
  String dayDianumSpentEgresoscents(Object diaNum, Object egresosCents);

  /// No description provided for @searchItemPluCode.
  ///
  /// In es, this message translates to:
  /// **'Buscar artículo o código PLU...'**
  String get searchItemPluCode;

  /// No description provided for @compareInflationBetweenPeriods.
  ///
  /// In es, this message translates to:
  /// **'Comparar Inflación entre Períodos'**
  String get compareInflationBetweenPeriods;

  /// No description provided for @noRecordedItemsFound.
  ///
  /// In es, this message translates to:
  /// **'No se encontraron artículos registrados'**
  String get noRecordedItemsFound;

  /// No description provided for @itemsRecordedWhenYouEnter.
  ///
  /// In es, this message translates to:
  /// **'Los artículos se registran al cargar tickets o egresos detallados'**
  String get itemsRecordedWhenYouEnter;

  /// No description provided for @priceHistoryTrend.
  ///
  /// In es, this message translates to:
  /// **'Historial de Precios y Tendencia'**
  String get priceHistoryTrend;

  /// No description provided for @noHistoricalDataItem.
  ///
  /// In es, this message translates to:
  /// **'No hay datos históricos para este artículo'**
  String get noHistoricalDataItem;

  /// No description provided for @currentPrice.
  ///
  /// In es, this message translates to:
  /// **'Precio Actual'**
  String get currentPrice;

  /// No description provided for @totalChange.
  ///
  /// In es, this message translates to:
  /// **'Variación Total'**
  String get totalChange;

  /// No description provided for @historicalLow.
  ///
  /// In es, this message translates to:
  /// **'Mínimo Histórico'**
  String get historicalLow;

  /// No description provided for @historicalHigh.
  ///
  /// In es, this message translates to:
  /// **'Máximo Histórico'**
  String get historicalHigh;

  /// No description provided for @unitPriceTrend.
  ///
  /// In es, this message translates to:
  /// **'Evolución del Precio Unitario'**
  String get unitPriceTrend;

  /// No description provided for @purchaseHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial de Compras'**
  String get purchaseHistory;

  /// No description provided for @inflationMonitor.
  ///
  /// In es, this message translates to:
  /// **'Monitor de Inflación'**
  String get inflationMonitor;

  /// No description provided for @comparisonIdenticalItemsPurchased.
  ///
  /// In es, this message translates to:
  /// **'Comparativa de artículos idénticos comprados'**
  String get comparisonIdenticalItemsPurchased;

  /// No description provided for @noIdenticalItemsWerePurchased.
  ///
  /// In es, this message translates to:
  /// **'No se detectaron artículos idénticos comprados en ambos períodos seleccionados.'**
  String get noIdenticalItemsWerePurchased;

  /// No description provided for @personalAverageInflation.
  ///
  /// In es, this message translates to:
  /// **'Inflación Promedio Personal'**
  String get personalAverageInflation;

  /// No description provided for @productoscomunesItemsComparedProductosaumentaronWent.
  ///
  /// In es, this message translates to:
  /// **'{productosComunes} artículos comparados ({productosAumentaron} subieron de precio)'**
  String productoscomunesItemsComparedProductosaumentaronWent(
      Object productosComunes, Object productosAumentaron);

  /// No description provided for @detailItem.
  ///
  /// In es, this message translates to:
  /// **'Detalle por Artículo'**
  String get detailItem;

  /// No description provided for @beforePrecio1centsNowPrecio2cents.
  ///
  /// In es, this message translates to:
  /// **'Antes: {precio1Cents} ➔ Ahora: {precio2Cents}'**
  String beforePrecio1centsNowPrecio2cents(
      Object precio1Cents, Object precio2Cents);

  /// No description provided for @loadingFinances.
  ///
  /// In es, this message translates to:
  /// **'Cargando tu espacio financiero...'**
  String get loadingFinances;

  /// No description provided for @category2.
  ///
  /// In es, this message translates to:
  /// **'La categoría'**
  String get category2;

  /// No description provided for @systemReservedCategoriesCannotChanged.
  ///
  /// In es, this message translates to:
  /// **'Las categorías reservadas del sistema no pueden modificarse ni eliminarse'**
  String get systemReservedCategoriesCannotChanged;

  /// No description provided for @categoryNameRequired.
  ///
  /// In es, this message translates to:
  /// **'El nombre de la categoría es obligatorio'**
  String get categoryNameRequired;

  /// No description provided for @nameCannotExceedCategorynamemaxCharacters.
  ///
  /// In es, this message translates to:
  /// **'El nombre no puede superar {categoryNameMax} caracteres'**
  String nameCannotExceedCategorynamemaxCharacters(Object categoryNameMax);

  /// No description provided for @couldNotOpenLocalDatabase.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la base local: {e}'**
  String couldNotOpenLocalDatabase(Object e);

  /// No description provided for @filterBalancesUpDate.
  ///
  /// In es, this message translates to:
  /// **'Filtrar saldos hasta fecha'**
  String get filterBalancesUpDate;

  /// No description provided for @refreshBalances.
  ///
  /// In es, this message translates to:
  /// **'Actualizar saldos'**
  String get refreshBalances;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes y Configuración'**
  String get settings;

  /// No description provided for @myAccountsAccounts.
  ///
  /// In es, this message translates to:
  /// **'Mis Cuentas ({accounts})'**
  String myAccountsAccounts(Object accounts);

  /// No description provided for @limitsBudgets.
  ///
  /// In es, this message translates to:
  /// **'Límites y Presupuestos'**
  String get limitsBudgets;

  /// No description provided for @consolidatedBalances.
  ///
  /// In es, this message translates to:
  /// **'Saldos Consolidados'**
  String get consolidatedBalances;

  /// No description provided for @hideBalances.
  ///
  /// In es, this message translates to:
  /// **'Ocultar saldos'**
  String get hideBalances;

  /// No description provided for @filterDate.
  ///
  /// In es, this message translates to:
  /// **'Filtrar por fecha'**
  String get filterDate;

  /// No description provided for @untilFechaformatted.
  ///
  /// In es, this message translates to:
  /// **'Hasta: {fechaFormatted}'**
  String untilFechaformatted(Object fechaFormatted);

  /// No description provided for @selectSourceAccount.
  ///
  /// In es, this message translates to:
  /// **'Debes seleccionar una cuenta de origen'**
  String get selectSourceAccount;

  /// No description provided for @selectCategoryLineI.
  ///
  /// In es, this message translates to:
  /// **'Debes seleccionar una categoría para el Renglón #{i}'**
  String selectCategoryLineI(Object i);

  /// No description provided for @qrReceiptsCannotConfirmedHere.
  ///
  /// In es, this message translates to:
  /// **'No se pueden confirmar tickets QR en este contexto'**
  String get qrReceiptsCannotConfirmedHere;

  /// No description provided for @accountNotServerYetSync.
  ///
  /// In es, this message translates to:
  /// **'La cuenta todavía no está en el servidor: sincronizá y volvé a intentar'**
  String get accountNotServerYetSync;

  /// No description provided for @fillConceptField.
  ///
  /// In es, this message translates to:
  /// **'Debe completar el campo Concepto'**
  String get fillConceptField;

  /// No description provided for @categoryNameNotServerYet.
  ///
  /// In es, this message translates to:
  /// **'La categoría {name} todavía no está en el servidor: sincronizá'**
  String categoryNameNotServerYet(Object name);

  /// No description provided for @lineIMustHaveAmount.
  ///
  /// In es, this message translates to:
  /// **'El Renglón #{i} debe tener un monto mayor a 0'**
  String lineIMustHaveAmount(Object i);

  /// No description provided for @expenseDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha del egreso'**
  String get expenseDate;

  /// No description provided for @sourceAccount.
  ///
  /// In es, this message translates to:
  /// **'Cuenta de Origen'**
  String get sourceAccount;

  /// No description provided for @generalConcept2.
  ///
  /// In es, this message translates to:
  /// **'Concepto General *'**
  String get generalConcept2;

  /// No description provided for @eGSupermarketBookstore.
  ///
  /// In es, this message translates to:
  /// **'Ej: Supermercado, Librería...'**
  String get eGSupermarketBookstore;

  /// No description provided for @addLine.
  ///
  /// In es, this message translates to:
  /// **'Agregar Renglón'**
  String get addLine;

  /// No description provided for @expenseTotal.
  ///
  /// In es, this message translates to:
  /// **'Total del Gasto'**
  String get expenseTotal;

  /// No description provided for @scannedQrCodeNotValid.
  ///
  /// In es, this message translates to:
  /// **'El código QR escaneado no es una dirección web válida (http/https).'**
  String get scannedQrCodeNotValid;

  /// No description provided for @loadingExpenses.
  ///
  /// In es, this message translates to:
  /// **'Cargando gastos...'**
  String get loadingExpenses;

  /// No description provided for @receiptReadItemsLines.
  ///
  /// In es, this message translates to:
  /// **'Ticket leído: {items} renglones'**
  String receiptReadItemsLines(Object items);

  /// No description provided for @couldNotProcessQr.
  ///
  /// In es, this message translates to:
  /// **'No se pudo procesar QR'**
  String get couldNotProcessQr;

  /// No description provided for @motivoDoYouWantScan.
  ///
  /// In es, this message translates to:
  /// **'{motivo}\n\n¿Deseas intentar reescanear el QR o usar la lectura por fotos?'**
  String motivoDoYouWantScan(Object motivo);

  /// No description provided for @usePhotos.
  ///
  /// In es, this message translates to:
  /// **'Usar fotos'**
  String get usePhotos;

  /// No description provided for @scannerNotAvailableDeviceSelect.
  ///
  /// In es, this message translates to:
  /// **'El escáner no está disponible en este dispositivo. Selecciona fotos de la galería.'**
  String get scannerNotAvailableDeviceSelect;

  /// No description provided for @couldNotAccessGalleryCheck.
  ///
  /// In es, this message translates to:
  /// **'No se pudo acceder a la galería. Verifica los permisos.'**
  String get couldNotAccessGalleryCheck;

  /// No description provided for @lineRenglonnum.
  ///
  /// In es, this message translates to:
  /// **'Renglón #{renglonNum}'**
  String lineRenglonnum(Object renglonNum);

  /// No description provided for @deleteLine2.
  ///
  /// In es, this message translates to:
  /// **'Eliminar renglón'**
  String get deleteLine2;

  /// No description provided for @eGVegetablesMeatCleaning.
  ///
  /// In es, this message translates to:
  /// **'Ej: Verduras, Carne, Limpieza...'**
  String get eGVegetablesMeatCleaning;

  /// No description provided for @selectDestinationAccount.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una cuenta de destino'**
  String get selectDestinationAccount;

  /// No description provided for @incomeDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha del ingreso'**
  String get incomeDate;

  /// No description provided for @amountAdd.
  ///
  /// In es, this message translates to:
  /// **'Monto a Ingresar'**
  String get amountAdd;

  /// No description provided for @conceptReason.
  ///
  /// In es, this message translates to:
  /// **'Concepto / Motivo'**
  String get conceptReason;

  /// No description provided for @eGSalaryFreelancePayment.
  ///
  /// In es, this message translates to:
  /// **'Ej: Sueldo, Cobro freelance, Venta... (vacío: \"{conceptoIngresoPorDefecto}\")'**
  String eGSalaryFreelancePayment(Object conceptoIngresoPorDefecto);

  /// No description provided for @recordIncome2.
  ///
  /// In es, this message translates to:
  /// **'Registrar Ingreso'**
  String get recordIncome2;

  /// No description provided for @amountMustGreaterThanZero.
  ///
  /// In es, this message translates to:
  /// **'El monto debe ser mayor a cero'**
  String get amountMustGreaterThanZero;

  /// No description provided for @selectLeastOneCategory.
  ///
  /// In es, this message translates to:
  /// **'Seleccione al menos una categoría'**
  String get selectLeastOneCategory;

  /// No description provided for @mostBudgetmaxcategoriesCategories.
  ///
  /// In es, this message translates to:
  /// **'Máximo {budgetMaxCategories} categorías'**
  String mostBudgetmaxcategoriesCategories(Object budgetMaxCategories);

  /// No description provided for @selectLeastOneAccountApply.
  ///
  /// In es, this message translates to:
  /// **'Debe seleccionar al menos un lugar donde aplicar el límite de gastos'**
  String get selectLeastOneAccountApply;

  /// No description provided for @limit2.
  ///
  /// In es, this message translates to:
  /// **'El límite'**
  String get limit2;

  /// No description provided for @invalidDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha inválida'**
  String get invalidDate;

  /// No description provided for @endDateCannotBeforeStart.
  ///
  /// In es, this message translates to:
  /// **'La fecha hasta no puede ser anterior a la fecha desde'**
  String get endDateCannotBeforeStart;

  /// No description provided for @generalConcept3.
  ///
  /// In es, this message translates to:
  /// **'El concepto general'**
  String get generalConcept3;

  /// No description provided for @changeAccountsTransferEditSource.
  ///
  /// In es, this message translates to:
  /// **'Para cambiar las cuentas de una transferencia editá origen y destino'**
  String get changeAccountsTransferEditSource;

  /// No description provided for @movementCannotMovedAccountAnother.
  ///
  /// In es, this message translates to:
  /// **'No se puede mover el movimiento a una cuenta de otra moneda'**
  String get movementCannotMovedAccountAnother;

  /// No description provided for @transferLinesEditedAsPair.
  ///
  /// In es, this message translates to:
  /// **'Los renglones de una transferencia se editan como par (origen, destino y monto)'**
  String get transferLinesEditedAsPair;

  /// No description provided for @concept2.
  ///
  /// In es, this message translates to:
  /// **'El concepto'**
  String get concept2;

  /// No description provided for @incomesAlwaysUseReservedIncome.
  ///
  /// In es, this message translates to:
  /// **'Los ingresos usan siempre la categoría reservada de ingresos'**
  String get incomesAlwaysUseReservedIncome;

  /// No description provided for @selectCategory.
  ///
  /// In es, this message translates to:
  /// **'Seleccione una categoría'**
  String get selectCategory;

  /// No description provided for @categoryNameReservedCannotUsed.
  ///
  /// In es, this message translates to:
  /// **'La categoría {name} es reservada y no puede usarse en egresos'**
  String categoryNameReservedCannotUsed(Object name);

  /// No description provided for @categoryNameInactive.
  ///
  /// In es, this message translates to:
  /// **'La categoría {name} está inactiva'**
  String categoryNameInactive(Object name);

  /// No description provided for @singleLineTransferCannotDeleted.
  ///
  /// In es, this message translates to:
  /// **'No se puede eliminar un solo renglón de una transferencia; eliminá el movimiento completo'**
  String get singleLineTransferCannotDeleted;

  /// No description provided for @onlyLineVoucherDeleteWhole.
  ///
  /// In es, this message translates to:
  /// **'Es el único renglón del comprobante; eliminá el movimiento completo'**
  String get onlyLineVoucherDeleteWhole;

  /// No description provided for @movementNotTransfer.
  ///
  /// In es, this message translates to:
  /// **'El movimiento no es una transferencia'**
  String get movementNotTransfer;

  /// No description provided for @transferDoesNotHaveIts.
  ///
  /// In es, this message translates to:
  /// **'La transferencia no tiene su par de renglones en el celular'**
  String get transferDoesNotHaveIts;

  /// No description provided for @sourceDestinationAccountsCannotSame.
  ///
  /// In es, this message translates to:
  /// **'La cuenta de origen y de destino no pueden ser iguales'**
  String get sourceDestinationAccountsCannotSame;

  /// No description provided for @cannotTransferBetweenAccountsDifferent.
  ///
  /// In es, this message translates to:
  /// **'No se puede transferir entre cuentas de distinta moneda'**
  String get cannotTransferBetweenAccountsDifferent;

  /// No description provided for @voucherNotPhoneSyncTry.
  ///
  /// In es, this message translates to:
  /// **'El comprobante no está en el celular; sincronizá y volvé a intentar'**
  String get voucherNotPhoneSyncTry;

  /// No description provided for @lineNoLongerPhone.
  ///
  /// In es, this message translates to:
  /// **'El renglón ya no está en el celular'**
  String get lineNoLongerPhone;

  /// No description provided for @voucherHasNotReachedServer.
  ///
  /// In es, this message translates to:
  /// **'El comprobante todavía no llegó al servidor: sincronizá antes de editar o borrar sus renglones'**
  String get voucherHasNotReachedServer;

  /// No description provided for @accountNameInactive.
  ///
  /// In es, this message translates to:
  /// **'La cuenta {name} está inactiva'**
  String accountNameInactive(Object name);

  /// No description provided for @enterLeastOneExpense.
  ///
  /// In es, this message translates to:
  /// **'Debe ingresar al menos un gasto'**
  String get enterLeastOneExpense;

  /// No description provided for @most300LinesPerExpense.
  ///
  /// In es, this message translates to:
  /// **'Máximo 300 renglones por egreso'**
  String get most300LinesPerExpense;

  /// No description provided for @selectAccountDebit.
  ///
  /// In es, this message translates to:
  /// **'Debe seleccionar un lugar para realizar el débito'**
  String get selectAccountDebit;

  /// No description provided for @conceptLineI.
  ///
  /// In es, this message translates to:
  /// **'El concepto del renglón {i}'**
  String conceptLineI(Object i);

  /// No description provided for @selectCategoryLineI2.
  ///
  /// In es, this message translates to:
  /// **'Seleccione una categoría en el renglón {i}'**
  String selectCategoryLineI2(Object i);

  /// No description provided for @selectDestinationAccount2.
  ///
  /// In es, this message translates to:
  /// **'Debe seleccionar la cuenta de destino'**
  String get selectDestinationAccount2;

  /// No description provided for @selectSourceAccount2.
  ///
  /// In es, this message translates to:
  /// **'Seleccione la cuenta de origen'**
  String get selectSourceAccount2;

  /// No description provided for @selectDestinationAccount3.
  ///
  /// In es, this message translates to:
  /// **'Seleccione la cuenta de destino'**
  String get selectDestinationAccount3;

  /// No description provided for @cannotTransferBetweenAccountsDifferent2.
  ///
  /// In es, this message translates to:
  /// **'No se puede transferir entre cuentas de distinta moneda. Registrá un egreso y un ingreso.'**
  String get cannotTransferBetweenAccountsDifferent2;

  /// No description provided for @conceptCannotExceedConceptmaxCharacters.
  ///
  /// In es, this message translates to:
  /// **'El concepto no puede superar {conceptMax} caracteres'**
  String conceptCannotExceedConceptmaxCharacters(Object conceptMax);

  /// No description provided for @operationCorrectNoLongerRejected.
  ///
  /// In es, this message translates to:
  /// **'La operación a corregir ya no está rechazada'**
  String get operationCorrectNoLongerRejected;

  /// No description provided for @systemCategoryRoleMissingSync.
  ///
  /// In es, this message translates to:
  /// **'Falta la categoría del sistema {role}: sincronizá con conexión antes de cargar.'**
  String systemCategoryRoleMissingSync(Object role);

  /// No description provided for @languageDefaultCurrency.
  ///
  /// In es, this message translates to:
  /// **'Idioma y Moneda por Defecto'**
  String get languageDefaultCurrency;

  /// No description provided for @appLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma de la Aplicación'**
  String get appLanguage;

  /// No description provided for @sessionDiagnosticsDebug.
  ///
  /// In es, this message translates to:
  /// **'Diagnóstico de sesión (debug)'**
  String get sessionDiagnosticsDebug;

  /// No description provided for @n2ParallelGetAuthMe.
  ///
  /// In es, this message translates to:
  /// **'2 GET /auth/me en paralelo'**
  String get n2ParallelGetAuthMe;

  /// No description provided for @management.
  ///
  /// In es, this message translates to:
  /// **'Módulos de Gestión Administrativa'**
  String get management;

  /// No description provided for @accountsPaymentMethods.
  ///
  /// In es, this message translates to:
  /// **'Cuentas y Medios de Pago'**
  String get accountsPaymentMethods;

  /// No description provided for @manageBanksWalletsCash.
  ///
  /// In es, this message translates to:
  /// **'Gestionar bancos, billeteras y efectivo (ABM Lugares)'**
  String get manageBanksWalletsCash;

  /// No description provided for @createRenameActivateExpenseCategories.
  ///
  /// In es, this message translates to:
  /// **'Crear, renombrar y activar categorías de gasto'**
  String get createRenameActivateExpenseCategories;

  /// No description provided for @budgetsSpendingCaps.
  ///
  /// In es, this message translates to:
  /// **'Presupuestos y Topes de Gasto'**
  String get budgetsSpendingCaps;

  /// No description provided for @monthlyLimitsAlertsOneTap.
  ///
  /// In es, this message translates to:
  /// **'Límites mensuales, alertas y renovación en 1 tap'**
  String get monthlyLimitsAlertsOneTap;

  /// No description provided for @reportsPriceMonitor.
  ///
  /// In es, this message translates to:
  /// **'Reportes y Monitor de Precios'**
  String get reportsPriceMonitor;

  /// No description provided for @visualAnalyticsChartsInflationTrends.
  ///
  /// In es, this message translates to:
  /// **'Analíticas visuales, gráficos y evolución de inflación'**
  String get visualAnalyticsChartsInflationTrends;

  /// No description provided for @appearanceTheme.
  ///
  /// In es, this message translates to:
  /// **'Apariencia y Tema'**
  String get appearanceTheme;

  /// No description provided for @displayMode.
  ///
  /// In es, this message translates to:
  /// **'Modo de Visualización'**
  String get displayMode;

  /// No description provided for @initialSetup.
  ///
  /// In es, this message translates to:
  /// **'Configuración Inicial'**
  String get initialSetup;

  /// No description provided for @welcomePleaseChooseInitialPreferences.
  ///
  /// In es, this message translates to:
  /// **'¡Bienvenido! Elegí tus preferencias iniciales:'**
  String get welcomePleaseChooseInitialPreferences;

  /// No description provided for @n1UsualCurrencyDefault.
  ///
  /// In es, this message translates to:
  /// **'1. Moneda principal'**
  String get n1UsualCurrencyDefault;

  /// No description provided for @n2PreferredLanguage.
  ///
  /// In es, this message translates to:
  /// **'2. Idioma de Preferencia'**
  String get n2PreferredLanguage;

  /// No description provided for @selectSourceDestinationAccounts.
  ///
  /// In es, this message translates to:
  /// **'Selecciona cuenta de origen y destino'**
  String get selectSourceDestinationAccounts;

  /// No description provided for @transferDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha de la transferencia'**
  String get transferDate;

  /// No description provided for @source.
  ///
  /// In es, this message translates to:
  /// **'Desde (Origen)'**
  String get source;

  /// No description provided for @selectSource.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar origen'**
  String get selectSource;

  /// No description provided for @swapAccounts.
  ///
  /// In es, this message translates to:
  /// **'Invertir cuentas'**
  String get swapAccounts;

  /// No description provided for @destination.
  ///
  /// In es, this message translates to:
  /// **'Hacia (Destino)'**
  String get destination;

  /// No description provided for @amountTransfer.
  ///
  /// In es, this message translates to:
  /// **'Monto a Transferir'**
  String get amountTransfer;

  /// No description provided for @conceptReference.
  ///
  /// In es, this message translates to:
  /// **'Concepto / Referencia'**
  String get conceptReference;

  /// No description provided for @eGWithdrawal.
  ///
  /// In es, this message translates to:
  /// **'Ej: Extraccion'**
  String get eGWithdrawal;

  /// No description provided for @confirmTransfer.
  ///
  /// In es, this message translates to:
  /// **'Confirmar Transferencia'**
  String get confirmTransfer;

  /// No description provided for @notOnPhoneSync.
  ///
  /// In es, this message translates to:
  /// **'{what} no está en el celular; sincronizá y volvé a intentar'**
  String notOnPhoneSync(String what);

  /// No description provided for @fieldRequired.
  ///
  /// In es, this message translates to:
  /// **'{field} es obligatorio'**
  String fieldRequired(String field);

  /// No description provided for @fieldTooLong.
  ///
  /// In es, this message translates to:
  /// **'{field} no puede superar {max} caracteres'**
  String fieldTooLong(String field, int max);

  /// No description provided for @amountOfMustBePositive.
  ///
  /// In es, this message translates to:
  /// **'El monto del {what} debe ser mayor a cero'**
  String amountOfMustBePositive(String what);

  /// No description provided for @lineN.
  ///
  /// In es, this message translates to:
  /// **'renglón {n}'**
  String lineN(int n);

  /// No description provided for @incomeWord.
  ///
  /// In es, this message translates to:
  /// **'ingreso'**
  String get incomeWord;

  /// No description provided for @transferWord.
  ///
  /// In es, this message translates to:
  /// **'transferencia'**
  String get transferWord;

  /// No description provided for @insufficientFundsTransfer.
  ///
  /// In es, this message translates to:
  /// **'No dispone del saldo solicitado a transferir ({amount}) en {account}: disponible {available}. Realizá un ingreso en la cuenta de origen.'**
  String insufficientFundsTransfer(
      String amount, String account, String available);

  /// No description provided for @insufficientFundsTransferEdit.
  ///
  /// In es, this message translates to:
  /// **'No dispone del saldo solicitado a transferir ({amount}) en {account}. Realizá un ingreso en la cuenta de origen.'**
  String insufficientFundsTransferEdit(String amount, String account);

  /// No description provided for @categoryNotForBudgets.
  ///
  /// In es, this message translates to:
  /// **'La categoría {name} no puede usarse en límites de gasto'**
  String categoryNotForBudgets(String name);

  /// No description provided for @accountAlreadyActive.
  ///
  /// In es, this message translates to:
  /// **'La cuenta ya está activa'**
  String get accountAlreadyActive;

  /// No description provided for @accountAlreadyInactive.
  ///
  /// In es, this message translates to:
  /// **'La cuenta ya está inactiva'**
  String get accountAlreadyInactive;

  /// No description provided for @categoryAlreadyActive.
  ///
  /// In es, this message translates to:
  /// **'La categoría ya está activa'**
  String get categoryAlreadyActive;

  /// No description provided for @categoryAlreadyInactive.
  ///
  /// In es, this message translates to:
  /// **'La categoría ya está inactiva'**
  String get categoryAlreadyInactive;

  /// No description provided for @accountNameTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una cuenta con ese nombre'**
  String get accountNameTaken;

  /// No description provided for @accountNameTakenInactive.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una cuenta inactiva con ese nombre: activala'**
  String get accountNameTakenInactive;

  /// No description provided for @categoryNameTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una categoría con ese nombre'**
  String get categoryNameTaken;

  /// No description provided for @categoryNameTakenInactive.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una categoría inactiva con ese nombre: activala'**
  String get categoryNameTakenInactive;

  /// No description provided for @alreadyTriedSyncBeforeDiscard.
  ///
  /// In es, this message translates to:
  /// **'Ya se intentó enviar: podría estar aplicada en el servidor. Sincronizá antes de descartarla.'**
  String get alreadyTriedSyncBeforeDiscard;

  /// No description provided for @comparison.
  ///
  /// In es, this message translates to:
  /// **'Comparativa'**
  String get comparison;

  /// No description provided for @prices.
  ///
  /// In es, this message translates to:
  /// **'Precios'**
  String get prices;

  /// No description provided for @custom.
  ///
  /// In es, this message translates to:
  /// **'Personalizado'**
  String get custom;

  /// No description provided for @surplus.
  ///
  /// In es, this message translates to:
  /// **'Superávit'**
  String get surplus;

  /// No description provided for @deficit.
  ///
  /// In es, this message translates to:
  /// **'Déficit'**
  String get deficit;

  /// No description provided for @income2.
  ///
  /// In es, this message translates to:
  /// **'Ingresos'**
  String get income2;

  /// No description provided for @expenses.
  ///
  /// In es, this message translates to:
  /// **'Egresos'**
  String get expenses;

  /// No description provided for @apply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get apply;

  /// No description provided for @clear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get clear;

  /// No description provided for @expenses2.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get expenses2;

  /// No description provided for @transfer2.
  ///
  /// In es, this message translates to:
  /// **'Transferir'**
  String get transfer2;

  /// No description provided for @history.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get history;

  /// No description provided for @date.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get date;

  /// No description provided for @destinationAccount.
  ///
  /// In es, this message translates to:
  /// **'Cuenta de destino.'**
  String get destinationAccount;

  /// No description provided for @system.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get system;

  /// No description provided for @light.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get dark;

  /// No description provided for @start.
  ///
  /// In es, this message translates to:
  /// **'Comenzar'**
  String get start;

  /// No description provided for @linesCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 renglón} other{{count} renglones}}'**
  String linesCount(int count);

  /// No description provided for @purchasesCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 compra} other{{count} compras}}'**
  String purchasesCount(int count);

  /// No description provided for @ticketSumDiffers.
  ///
  /// In es, this message translates to:
  /// **'Suma de renglones ({sum}) difiere del total del ticket ({total}): diferencia {diff}. Revisá los montos.'**
  String ticketSumDiffers(String sum, String total, String diff);

  /// No description provided for @ticketReadSumTotal.
  ///
  /// In es, this message translates to:
  /// **'Ticket leído: suma {sum} | total {total}'**
  String ticketReadSumTotal(String sum, String total);

  /// No description provided for @ticketSumNoTotal.
  ///
  /// In es, this message translates to:
  /// **'Suma de renglones: {sum} (no se detectó un total en el ticket).'**
  String ticketSumNoTotal(String sum);

  /// No description provided for @chartMonthTooltip.
  ///
  /// In es, this message translates to:
  /// **'{month}\n{kind}: {amount}\nBalance: {balance}'**
  String chartMonthTooltip(
      String month, String kind, String amount, String balance);

  /// No description provided for @currencyArs.
  ///
  /// In es, this message translates to:
  /// **'Pesos argentinos (ARS \$)'**
  String get currencyArs;

  /// No description provided for @currencyUsd.
  ///
  /// In es, this message translates to:
  /// **'Dólares (USD \$)'**
  String get currencyUsd;

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In es, this message translates to:
  /// **'Sin permiso para usar la cámara. Habilitalo en los ajustes del celular para leer el QR.'**
  String get cameraPermissionDenied;

  /// No description provided for @cameraUnsupported.
  ///
  /// In es, this message translates to:
  /// **'Este celular no permite leer códigos QR.'**
  String get cameraUnsupported;

  /// No description provided for @cameraError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo usar la cámara.'**
  String get cameraError;

  /// No description provided for @errInsecureTransport.
  ///
  /// In es, this message translates to:
  /// **'La dirección del servidor no usa HTTPS: esta versión de la app solo se conecta por HTTPS.'**
  String get errInsecureTransport;

  /// No description provided for @ticketAlreadyRegistered.
  ///
  /// In es, this message translates to:
  /// **'Este ticket ya estaba registrado; no se cargó de nuevo.'**
  String get ticketAlreadyRegistered;

  /// No description provided for @ticketRecordedNotOnPhoneYet.
  ///
  /// In es, this message translates to:
  /// **'Ticket registrado en el servidor, pero no se pudo traer al celular: {error}. Va a aparecer en la próxima sincronización.'**
  String ticketRecordedNotOnPhoneYet(String error);

  /// No description provided for @syncOfflineSaved.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión con el servidor: lo que cargues se guarda en el celular y se envía cuando vuelva.'**
  String get syncOfflineSaved;

  /// No description provided for @qrNeedsConnection.
  ///
  /// In es, this message translates to:
  /// **'La lectura por QR necesita conexión'**
  String get qrNeedsConnection;

  /// No description provided for @savedThing.
  ///
  /// In es, this message translates to:
  /// **'{what} guardado.'**
  String savedThing(String what);

  /// No description provided for @changesSaved.
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados.'**
  String get changesSaved;

  /// No description provided for @dashboardYou.
  ///
  /// In es, this message translates to:
  /// **'tú'**
  String get dashboardYou;

  /// No description provided for @dashboards.
  ///
  /// In es, this message translates to:
  /// **'Dashboards'**
  String get dashboards;

  /// No description provided for @manageDashboards.
  ///
  /// In es, this message translates to:
  /// **'Gestionar dashboards'**
  String get manageDashboards;

  /// No description provided for @chooseDashboard.
  ///
  /// In es, this message translates to:
  /// **'Elegir dashboard'**
  String get chooseDashboard;

  /// No description provided for @dashboardSharedTag.
  ///
  /// In es, this message translates to:
  /// **'compartido'**
  String get dashboardSharedTag;

  /// No description provided for @invitationTitle.
  ///
  /// In es, this message translates to:
  /// **'Te compartieron un dashboard'**
  String get invitationTitle;

  /// No description provided for @invitationBody.
  ///
  /// In es, this message translates to:
  /// **'{inviter} ({email}) te invitó a compartir su dashboard \"{dashboard}\".'**
  String invitationBody(String inviter, String email, String dashboard);

  /// No description provided for @acceptInvitation.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get acceptInvitation;

  /// No description provided for @rejectInvitation.
  ///
  /// In es, this message translates to:
  /// **'Rechazar'**
  String get rejectInvitation;

  /// No description provided for @notificationAccepted.
  ///
  /// In es, this message translates to:
  /// **'{user} aceptó compartir el dashboard \"{dashboard}\".'**
  String notificationAccepted(String user, String dashboard);

  /// No description provided for @notificationRejected.
  ///
  /// In es, this message translates to:
  /// **'{user} rechazó compartir el dashboard \"{dashboard}\".'**
  String notificationRejected(String user, String dashboard);

  /// No description provided for @accessLostNotice.
  ///
  /// In es, this message translates to:
  /// **'Ya no tenés acceso a ese dashboard: se muestra tu dashboard principal.'**
  String get accessLostNotice;

  /// No description provided for @movementCreatedBy.
  ///
  /// In es, this message translates to:
  /// **'Cargado por {name}'**
  String movementCreatedBy(String name);

  /// No description provided for @dashboardName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del dashboard'**
  String get dashboardName;

  /// No description provided for @dashboardDefaultName.
  ///
  /// In es, this message translates to:
  /// **'principal'**
  String get dashboardDefaultName;

  /// No description provided for @displayName.
  ///
  /// In es, this message translates to:
  /// **'Nombre para mostrar'**
  String get displayName;

  /// No description provided for @displayNameHint.
  ///
  /// In es, this message translates to:
  /// **'Lo ven las personas con las que compartís un dashboard. No tiene que ser único.'**
  String get displayNameHint;

  /// No description provided for @displayNameSaved.
  ///
  /// In es, this message translates to:
  /// **'Nombre guardado.'**
  String get displayNameSaved;

  /// No description provided for @yourDashboards.
  ///
  /// In es, this message translates to:
  /// **'Tus dashboards'**
  String get yourDashboards;

  /// No description provided for @sharedWithYou.
  ///
  /// In es, this message translates to:
  /// **'Compartidos con vos'**
  String get sharedWithYou;

  /// No description provided for @newDashboard.
  ///
  /// In es, this message translates to:
  /// **'Nuevo dashboard'**
  String get newDashboard;

  /// No description provided for @createDashboard.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get createDashboard;

  /// No description provided for @shareWithEmail.
  ///
  /// In es, this message translates to:
  /// **'Compartir con (correo de un usuario registrado)'**
  String get shareWithEmail;

  /// No description provided for @shareDashboard.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get shareDashboard;

  /// No description provided for @invitationSent.
  ///
  /// In es, this message translates to:
  /// **'Se envió la invitación a {email}. Cuando la acepte o la rechace te llega un aviso.'**
  String invitationSent(String email);

  /// No description provided for @dashboardMembers.
  ///
  /// In es, this message translates to:
  /// **'Integrantes'**
  String get dashboardMembers;

  /// No description provided for @ownerTag.
  ///
  /// In es, this message translates to:
  /// **'dueño'**
  String get ownerTag;

  /// No description provided for @ownedBy.
  ///
  /// In es, this message translates to:
  /// **'de {name}'**
  String ownedBy(String name);

  /// No description provided for @removeAccess.
  ///
  /// In es, this message translates to:
  /// **'Quitar acceso'**
  String get removeAccess;

  /// No description provided for @leaveDashboard.
  ///
  /// In es, this message translates to:
  /// **'Salir'**
  String get leaveDashboard;

  /// No description provided for @openDashboard.
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get openDashboard;

  /// No description provided for @clearDashboard.
  ///
  /// In es, this message translates to:
  /// **'Limpiar dashboard'**
  String get clearDashboard;

  /// No description provided for @deleteDashboard.
  ///
  /// In es, this message translates to:
  /// **'Eliminar dashboard'**
  String get deleteDashboard;

  /// No description provided for @confirmClearDashboard.
  ///
  /// In es, this message translates to:
  /// **'Se borran todos los movimientos, tickets y límites de \"{name}\". Se conservan las cuentas y las categorías. No se puede deshacer.'**
  String confirmClearDashboard(String name);

  /// No description provided for @confirmDeleteDashboard.
  ///
  /// In es, this message translates to:
  /// **'Se elimina \"{name}\" con todo su contenido y se quita el acceso a todos los invitados. No se puede deshacer.'**
  String confirmDeleteDashboard(String name);

  /// No description provided for @confirmLeaveDashboard.
  ///
  /// In es, this message translates to:
  /// **'Dejás de ver \"{name}\". Para volver, el dueño te tiene que invitar de nuevo.'**
  String confirmLeaveDashboard(String name);

  /// No description provided for @confirmRemoveMember.
  ///
  /// In es, this message translates to:
  /// **'{user} deja de ver \"{name}\".'**
  String confirmRemoveMember(String user, String name);

  /// No description provided for @dashboardCreated.
  ///
  /// In es, this message translates to:
  /// **'Se creó el dashboard \"{name}\".'**
  String dashboardCreated(String name);

  /// No description provided for @dashboardRenamed.
  ///
  /// In es, this message translates to:
  /// **'Se cambió el nombre.'**
  String get dashboardRenamed;

  /// No description provided for @dashboardClearedMsg.
  ///
  /// In es, this message translates to:
  /// **'Se limpió el dashboard.'**
  String get dashboardClearedMsg;

  /// No description provided for @dashboardDeletedMsg.
  ///
  /// In es, this message translates to:
  /// **'Se eliminó el dashboard.'**
  String get dashboardDeletedMsg;

  /// No description provided for @dashboardLeftMsg.
  ///
  /// In es, this message translates to:
  /// **'Saliste del dashboard.'**
  String get dashboardLeftMsg;

  /// No description provided for @accessRemovedMsg.
  ///
  /// In es, this message translates to:
  /// **'Se quitó el acceso.'**
  String get accessRemovedMsg;

  /// No description provided for @dashboardsNeedConnection.
  ///
  /// In es, this message translates to:
  /// **'Administrar y compartir dashboards necesita conexión.'**
  String get dashboardsNeedConnection;

  /// No description provided for @noNotifications2.
  ///
  /// In es, this message translates to:
  /// **'No tenés avisos.'**
  String get noNotifications2;

  /// No description provided for @errDashboardForbidden.
  ///
  /// In es, this message translates to:
  /// **'No tenés acceso a ese dashboard.'**
  String get errDashboardForbidden;

  /// No description provided for @errNotCreator.
  ///
  /// In es, this message translates to:
  /// **'Solo quien lo cargó puede modificarlo.'**
  String get errNotCreator;

  /// No description provided for @errOwnerOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo el dueño del dashboard puede hacer esto.'**
  String get errOwnerOnly;

  /// No description provided for @errUserNotRegistered.
  ///
  /// In es, this message translates to:
  /// **'Solo se puede compartir con usuarios registrados.'**
  String get errUserNotRegistered;

  /// No description provided for @errAlreadyMember.
  ///
  /// In es, this message translates to:
  /// **'Esa persona ya tiene acceso a este dashboard.'**
  String get errAlreadyMember;

  /// No description provided for @errSelfInvite.
  ///
  /// In es, this message translates to:
  /// **'No podés compartir un dashboard con vos mismo.'**
  String get errSelfInvite;

  /// No description provided for @errOwnerCannotLeave.
  ///
  /// In es, this message translates to:
  /// **'El dueño no puede salir de su dashboard.'**
  String get errOwnerCannotLeave;

  /// No description provided for @errPrincipalUndeletable.
  ///
  /// In es, this message translates to:
  /// **'El dashboard principal no se elimina; se puede limpiar.'**
  String get errPrincipalUndeletable;

  /// No description provided for @errNotPrincipal.
  ///
  /// In es, this message translates to:
  /// **'Solo se limpia el dashboard principal; los demás se eliminan.'**
  String get errNotPrincipal;

  /// No description provided for @errInvitationClosed.
  ///
  /// In es, this message translates to:
  /// **'La invitación ya fue respondida.'**
  String get errInvitationClosed;

  /// No description provided for @dashboardIsPrincipal.
  ///
  /// In es, this message translates to:
  /// **'Tu dashboard principal'**
  String get dashboardIsPrincipal;

  /// No description provided for @dashboardSharedCount.
  ///
  /// In es, this message translates to:
  /// **'Compartido · {count} integrantes'**
  String dashboardSharedCount(int count);

  /// No description provided for @mainCurrency.
  ///
  /// In es, this message translates to:
  /// **'Moneda principal'**
  String get mainCurrency;

  /// No description provided for @mainCurrencyHint.
  ///
  /// In es, this message translates to:
  /// **'Es la que se preselecciona y se muestra primero.'**
  String get mainCurrencyHint;

  /// No description provided for @mainCurrencySaved.
  ///
  /// In es, this message translates to:
  /// **'Se guardó la moneda principal.'**
  String get mainCurrencySaved;

  /// No description provided for @budgetCurrency.
  ///
  /// In es, this message translates to:
  /// **'Moneda del límite'**
  String get budgetCurrency;

  /// No description provided for @mixedCurrencies.
  ///
  /// In es, this message translates to:
  /// **'Mezcla monedas'**
  String get mixedCurrencies;

  /// No description provided for @budgetMixedCurrency.
  ///
  /// In es, this message translates to:
  /// **'Todas las cuentas de un límite deben ser de la misma moneda.'**
  String get budgetMixedCurrency;
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
