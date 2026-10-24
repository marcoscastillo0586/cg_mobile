// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get cannotReachServerCheckConnection =>
      'No se pudo conectar con el servidor. Revisá tu conexión.';

  @override
  String get notSyncedSession => 'Sin sincronizar en esta sesión';

  @override
  String get syncing => 'Sincronizando…';

  @override
  String get completeMatchesServer => 'Completa: coincide con el servidor';

  @override
  String get notEverythingWasAppliedSee => 'No se aplicó todo: ver el detalle';

  @override
  String get doesNotMatchServer => 'No coincide con el servidor';

  @override
  String get syncFailed => 'Falló la sincronización';

  @override
  String get lastCompleteSync => 'Última sincronización completa';

  @override
  String get phone => 'En este celular';

  @override
  String get movements => 'comprobantes';

  @override
  String get lines => 'renglones';

  @override
  String get pendingSend => 'Pendientes de enviar';

  @override
  String get rejected => 'Rechazadas';

  @override
  String get conflict => 'En conflicto';

  @override
  String get pendingRejected => 'Pendientes y rechazados';

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get noAccountsPhoneSyncWhile =>
      'No hay cuentas en el celular. Sincronizá con conexión.';

  @override
  String willRecordIncomeThatAccount(Object name, Object queda) {
    return 'La cuenta $name queda en $queda. Registrá un ingreso en esa cuenta.';
  }

  @override
  String notEnoughBalanceTransferAvailable(
      Object total, Object name, Object disponible) {
    return 'No dispone del saldo solicitado a transferir ($total) en $name (disponible $disponible). Realizá un ingreso en la cuenta de origen.';
  }

  @override
  String get accounts => 'Cuentas y Medios de Pago';

  @override
  String get newAccount => 'Nueva cuenta';

  @override
  String get all => 'Todas';

  @override
  String get active => 'Activas';

  @override
  String get retry => 'Reintentar';

  @override
  String get noAccounts => 'No hay cuentas registradas';

  @override
  String get accountDeactivated => 'Cuenta desactivada.';

  @override
  String get accountActivated => 'Cuenta activada.';

  @override
  String get deleteAccount => '¿Eliminar la cuenta?';

  @override
  String get withoutMovementsDeletedMovementsDeactivated =>
      'Sin movimientos se elimina; con movimientos se desactiva.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get accountDeleted => 'Cuenta eliminada.';

  @override
  String get editAccount => 'Editar cuenta';

  @override
  String get name => 'Nombre';

  @override
  String get currency => 'Moneda';

  @override
  String get currencyLockedAccountHasMovements =>
      'La moneda no se cambia: la cuenta tiene movimientos.';

  @override
  String get icon => 'Ícono';

  @override
  String get save => 'Guardar';

  @override
  String get accountCreated => 'Cuenta creada.';

  @override
  String get accountUpdated => 'Cuenta actualizada.';

  @override
  String get inactive => 'Inactiva';

  @override
  String get movements2 => 'movimientos';

  @override
  String get pendingSync => ' · sin sincronizar';

  @override
  String get edit => 'Editar';

  @override
  String get deactivate => 'Desactivar';

  @override
  String get activate => 'Activar';

  @override
  String get code => 'Código';

  @override
  String get sessionExpiredPleaseSignAgain =>
      'Tu sesión expiró. Iniciá sesión nuevamente.';

  @override
  String signedOutDeviceButServer(Object detail) {
    return 'Se cerró la sesión en este celular, pero no se pudo avisar al servidor$detail.';
  }

  @override
  String get sign => 'Iniciar sesión';

  @override
  String get youExampleCom => 'tu@email.com';

  @override
  String get enterEmail => 'Ingresá tu email';

  @override
  String get invalidEmail => 'Email inválido';

  @override
  String get password => 'Contraseña';

  @override
  String get enterPassword => 'Ingresá tu contraseña';

  @override
  String get sign2 => 'Acceder';

  @override
  String get categories => 'Rubros y Categorías';

  @override
  String get newCategory => 'Nueva categoría';

  @override
  String get searchCategory => 'Buscar categoría';

  @override
  String get inactive2 => 'Inactivas';

  @override
  String get noCategories => 'No hay categorías';

  @override
  String get categoryDeactivated => 'Categoría desactivada.';

  @override
  String get categoryActivated => 'Categoría activada.';

  @override
  String get deleteCategory => '¿Eliminar la categoría?';

  @override
  String get categoryDeleted => 'Categoría eliminada.';

  @override
  String get renameCategory => 'Renombrar categoría';

  @override
  String get categoryCreated => 'Categoría creada.';

  @override
  String get categoryRenamed => 'Categoría renombrada.';

  @override
  String get inactive3 => 'inactiva';

  @override
  String get reserved => 'reservada';

  @override
  String get reserved2 => 'Reservada';

  @override
  String get rename => 'Renombrar';

  @override
  String get syncFailed2 => 'No se pudo sincronizar';

  @override
  String operationSWereNotApplied(Object needsAttention) {
    return '$needsAttention operación(es) no se aplicaron. Ver Ajustes → Pendientes y rechazados.';
  }

  @override
  String get localDataDoesNotMatch =>
      'Los datos locales no coinciden con el servidor; la próxima vez se descarga todo.';

  @override
  String get lastRate => 'Última cotización';

  @override
  String get exchangeRateOfflineUsdNot =>
      'Cotización: sin conexión · USD sin convertir';

  @override
  String get exchangeRateUnavailableUsdNot =>
      'Cotización no disponible · USD sin convertir';

  @override
  String get showingLastLoadedData =>
      'Se muestran los datos de la última carga';

  @override
  String get recordIncome => 'Registrá un ingreso';

  @override
  String get noExchangeRate => 'sin cotización';

  @override
  String get notifications => 'Novedades';

  @override
  String limitNearTop(Object titulo, Object porcentaje) {
    return 'Límite \'$titulo\' cercano al tope ($porcentaje%)';
  }

  @override
  String limitReached(Object titulo, Object porcentaje) {
    return 'Límite \'$titulo\' alcanzado ($porcentaje%)';
  }

  @override
  String limitHasFinishedExpired(Object titulo) {
    return 'El límite \'$titulo\' ha finalizado y está vencido';
  }

  @override
  String get noPendingNotifications => 'Sin novedades pendientes';

  @override
  String get balanceWillNegative => 'La cuenta queda en negativo';

  @override
  String get saveAnyway => 'Guardar igual';

  @override
  String get ticketRecordedServer => 'Ticket registrado en el servidor.';

  @override
  String get expense => 'Egreso';

  @override
  String get confirmingQrTicketRequiresConnection =>
      ' Confirmar un ticket QR requiere conexión.';

  @override
  String get correctExpense => 'Corregir Egreso';

  @override
  String get newExpense => 'Nuevo Egreso';

  @override
  String registerExpense(Object totalFormateado) {
    return 'Registrar Gasto ($totalFormateado)';
  }

  @override
  String get scanReceipt => 'Escanear ticket';

  @override
  String get scanTicketQr => 'Escanear QR del Ticket';

  @override
  String get pointCameraReceiptQrCode =>
      'Apuntá la cámara al código QR del ticket';

  @override
  String get ifMerchantNewPageText =>
      'Si este comercio es nuevo, el texto de la página se enviará a un servicio externo para aprender sus reglas.';

  @override
  String get featureNotAvailableNow => 'Función no disponible por ahora';

  @override
  String get addLeastOnePhotoReceipt =>
      'Debes agregar al menos una foto del ticket';

  @override
  String get noProductsWereDetectedReceipt =>
      'No se detectaron productos en el ticket.';

  @override
  String receiptReadDeviceLines(Object items) {
    return 'Ticket leído en el dispositivo ($items renglones)';
  }

  @override
  String couldNotReadReceipt(Object e) {
    return 'No se pudo leer el ticket: $e';
  }

  @override
  String get scanReceiptUsingAutoCrop =>
      'Escanéa el ticket con auto-recorte, lee el código QR o selecciona una foto desde tu galería.';

  @override
  String get readingReceiptDevice => 'Leyendo el ticket en el dispositivo...';

  @override
  String get extractingProductsNetAmountsDiscounts =>
      'Extrayendo productos, montos netos y descuentos...';

  @override
  String get noScansAddedYet => 'Aún no agregaste escaneos';

  @override
  String get useScanScanQrGallery =>
      'Usa el botón Escanear, Escanear QR o Galería inferior';

  @override
  String scan(Object numFoto) {
    return 'Escaneo #$numFoto del ticket';
  }

  @override
  String get scan2 => 'Escanear';

  @override
  String get scanQr => 'Escanear QR';

  @override
  String get gallery => 'Galería';

  @override
  String get finishLoading => 'Finalizar carga';

  @override
  String get readAi => 'Leer con IA';

  @override
  String get income => 'Ingreso';

  @override
  String get correctIncome => 'Corregir Ingreso';

  @override
  String get newIncome => 'Nuevo Ingreso';

  @override
  String get invalidAmountMax2Decimals => 'Importe inválido (máx. 2 decimales)';

  @override
  String get budgets => 'Límites y Presupuestos';

  @override
  String get newBudget => 'Nuevo límite';

  @override
  String get all2 => 'Todos';

  @override
  String get current => 'En curso';

  @override
  String get due => 'Vencidos';

  @override
  String get exceeded => 'Excedidos';

  @override
  String get noBudgets => 'No hay presupuestos';

  @override
  String get budgetRenewed => 'Límite renovado.';

  @override
  String get deleteBudget => '¿Eliminar el límite?';

  @override
  String get budgetDeleted => 'Límite eliminado.';

  @override
  String get editBudget => 'Editar límite';

  @override
  String get from => 'Desde';

  @override
  String get to => 'Hasta';

  @override
  String get limit => 'Límite de gasto';

  @override
  String get budgetUpdated => 'Límite actualizado.';

  @override
  String get categories2 => 'Categorías';

  @override
  String get accounts2 => 'Cuentas';

  @override
  String get budgetCreated => 'Límite creado.';

  @override
  String get currentBudgets => 'Presupuestos vigentes';

  @override
  String get limits => 'Total topes';

  @override
  String get spent => 'Gastado';

  @override
  String get remaining => 'Restante';

  @override
  String get excess => 'Excedente';

  @override
  String get left => 'Resta';

  @override
  String get renew => 'Renovar';

  @override
  String pending(Object pending) {
    return ' Pendientes: $pending.';
  }

  @override
  String savedPhoneWillSentServer(Object what, Object suffix) {
    return '$what guardado en el celular. Se enviará al servidor al sincronizar.$suffix';
  }

  @override
  String get couldNotReadDataPhone =>
      'No se pudieron leer los datos del celular';

  @override
  String savedPhoneSending(Object ok) {
    return '$ok Guardado en el celular; enviando…';
  }

  @override
  String get dateRange => 'Rango de fechas';

  @override
  String get movements3 => 'Movimientos';

  @override
  String get searchTextAmount => 'Buscar por texto o monto';

  @override
  String get results => 'resultados';

  @override
  String lastMovements(Object total) {
    return 'Últimos $total movimientos';
  }

  @override
  String get noMovements => 'No hay movimientos';

  @override
  String get will => 'queda en';

  @override
  String get recordIncomeThatAccount => 'Registrá un ingreso en esa cuenta.';

  @override
  String get savedPhoneSending2 => 'Guardado en el celular; enviando…';

  @override
  String get completeSourceDestinationValidAmount =>
      'Completá origen, destino y un monto válido';

  @override
  String get deleteMovement => '¿Eliminar el comprobante?';

  @override
  String get removedAllItsLines => 'Se elimina con todos sus renglones.';

  @override
  String get editMovement => 'Editar comprobante';

  @override
  String get movementNotPhoneWasDeleted =>
      'El comprobante no está en el celular (o se eliminó). Sincronizá y volvé a intentar.';

  @override
  String get deleteMovement2 => 'Eliminar comprobante';

  @override
  String get header => 'Encabezado';

  @override
  String get generalConcept => 'Concepto general';

  @override
  String get accountAllLines => 'Cuenta (todos los renglones)';

  @override
  String get saveHeader => 'Guardar encabezado';

  @override
  String get lines2 => 'Renglones';

  @override
  String get notServerYetLinesCan =>
      'Todavía no está en el servidor: los renglones se editan después de sincronizar.';

  @override
  String get transfer => 'Transferencia';

  @override
  String get from2 => 'Desde (origen)';

  @override
  String get to2 => 'Hacia (destino)';

  @override
  String get amount => 'Monto';

  @override
  String get saveTransfer => 'Guardar transferencia';

  @override
  String get concept => 'Concepto';

  @override
  String get category => 'Categoría';

  @override
  String get deleteLine => 'Borrar renglón';

  @override
  String get saveLine => 'Guardar renglón';

  @override
  String showingLinesFilter(Object details, Object detailsCount) {
    return 'Se muestran $details de $detailsCount renglones (filtro)';
  }

  @override
  String get unit => 'unit.';

  @override
  String get signOut => '¿Cerrar sesión?';

  @override
  String get allDataStoredPhoneWill =>
      'Se borrarán todos los datos guardados en este celular. Lo que ya está en el servidor no se toca.';

  @override
  String get signOut2 => 'Cerrar sesión';

  @override
  String get session => 'Sesión';

  @override
  String get offline => 'sin conexión';

  @override
  String get deletesDataStoredPhoneSettings =>
      'Borra los datos guardados en este celular. Se conservan los ajustes.';

  @override
  String get offlineData => 'Datos sin conexión';

  @override
  String get server => 'Servidor';

  @override
  String get apiAddress => 'Dirección de la API';

  @override
  String get notConfiguredApiBaseUrl => 'Sin configurar (API_BASE_URL)';

  @override
  String get discard => '¿Descartar?';

  @override
  String get serverVersionKeptChangeLost =>
      'Queda la versión del servidor. Tu cambio se pierde.';

  @override
  String get removedPhoneLocalBalanceReverted =>
      'Se quita del celular y el saldo local se revierte.';

  @override
  String get discard2 => 'Descartar';

  @override
  String get discarded => 'Descartada';

  @override
  String get nothingPendingEverythingWasApplied =>
      'Nada pendiente: todo se aplicó.';

  @override
  String get rejected2 => 'Rechazada';

  @override
  String get conflictServerVersionApplied =>
      'Conflicto (se aplicó la del servidor)';

  @override
  String get pending2 => 'Pendiente';

  @override
  String get reason => 'Motivo';

  @override
  String get attempts => 'Intentos';

  @override
  String get correct => 'Corregir';

  @override
  String get queuedAgainChanges => 'Reencolada con tus cambios';

  @override
  String get retryMyChanges => 'Reintentar con mis cambios';

  @override
  String get keepServerVersion => 'Quedarme con la del servidor';

  @override
  String get correctTransfer => 'Corregir Transferencia';

  @override
  String get transferMoney => 'Transferir Dinero';

  @override
  String noOtherAccount(Object currency) {
    return 'No hay otra cuenta en $currency';
  }

  @override
  String get selectDestination => 'Seleccionar destino';

  @override
  String get errInvalidCredentials => 'Email o contraseña incorrectos.';

  @override
  String get errAccountLocked =>
      'Demasiados intentos fallidos. Probá de nuevo en 15 minutos.';

  @override
  String get errRateLimited => 'Demasiadas solicitudes. Esperá un momento.';

  @override
  String get errInvalidRefresh => 'Tu sesión expiró. Iniciá sesión nuevamente.';

  @override
  String get errInvalidToken => 'Tu sesión expiró. Iniciá sesión nuevamente.';

  @override
  String get errUnauthorized => 'Tenés que iniciar sesión.';

  @override
  String get errNotFound =>
      'El servidor no tiene esta función o el dato no existe.';

  @override
  String get errDuplicate => 'Ya existe un registro con esos datos.';

  @override
  String get errEmailTaken => 'Ya existe una cuenta con ese email.';

  @override
  String get errInsufficientFunds =>
      'No dispone del saldo a transferir. Realizá un ingreso en la cuenta de origen.';

  @override
  String get errReservedCategory =>
      'Esa categoría está reservada por el sistema.';

  @override
  String get errSameAccount =>
      'La cuenta de origen y la de destino no pueden ser iguales.';

  @override
  String get errCurrencyMismatch =>
      'No se puede transferir entre cuentas de distinta moneda.';

  @override
  String get errAccountInactive => 'La cuenta está inactiva.';

  @override
  String get errAccountHasFunds =>
      'Esta cuenta tiene dinero, deje la cuenta vacía y vuelva a intentarlo.';

  @override
  String get errCurrencyLocked =>
      'No se puede cambiar la moneda de una cuenta con movimientos.';

  @override
  String get errDuplicateName => 'Ya existe otro registro con ese nombre.';

  @override
  String get errInvalidPeriod =>
      'La fecha hasta no puede ser anterior a la fecha desde.';

  @override
  String get errLastDetail =>
      'Es el único renglón del comprobante; eliminá el movimiento completo.';

  @override
  String get errTransferEdit =>
      'Una transferencia se edita como par (origen, destino y monto).';

  @override
  String get errVersionConflict => 'El registro cambió en el servidor.';

  @override
  String get errCategoryInactive => 'La categoría está inactiva.';

  @override
  String get errCatalogNotSynced =>
      'Faltan datos del servidor en el celular: sincronizá con conexión.';

  @override
  String get errInternalError => 'Error interno del servidor.';

  @override
  String get errNotAvailable => 'Función no disponible por ahora.';

  @override
  String get errConfigMissing =>
      'La app no tiene configurada la dirección del servidor (API_BASE_URL).';

  @override
  String get errUnexpectedResponse => 'El servidor respondió algo inesperado.';

  @override
  String errInvalidData(String message) {
    return 'Datos inválidos: $message';
  }

  @override
  String get errNetwork =>
      'No se pudo conectar con el servidor. Revisá tu conexión.';
}
