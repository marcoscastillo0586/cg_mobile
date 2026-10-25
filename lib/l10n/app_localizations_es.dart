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

  @override
  String get selectAccount => 'Seleccioná una cuenta';

  @override
  String get operationNoLongerQueue => 'La operación ya no está en la cola';

  @override
  String get onlyEditsConflictCanRetried =>
      'Solo se reintentan ediciones en conflicto';

  @override
  String get voucherNoLongerExistsPhone =>
      'El comprobante ya no existe en el celular';

  @override
  String get onlyRejectedCreationsCanCorrected =>
      'Solo se corrigen altas rechazadas';

  @override
  String get unknownIcon => 'Ícono desconocido';

  @override
  String get account => 'La cuenta';

  @override
  String get currencyAccountMovementsCannotChange =>
      'No se puede cambiar la moneda de una cuenta con movimientos';

  @override
  String get noChangesSave => 'No hay cambios para guardar';

  @override
  String nameMustHaveLeastAccountnamemin(Object accountNameMin) {
    return 'El nombre debe tener al menos $accountNameMin caracteres';
  }

  @override
  String nameCannotExceedAccountnamemaxCharacters(Object accountNameMax) {
    return 'El nombre no puede superar $accountNameMax caracteres';
  }

  @override
  String get selectRangeReport => 'Selecciona rango para el reporte';

  @override
  String get reportsAnalytics => 'Reportes y Analíticas';

  @override
  String get refreshReport => 'Actualizar reporte';

  @override
  String get dayDay => 'Día a Día';

  @override
  String get month => 'Este Mes';

  @override
  String get previousMonth => 'Mes Anterior';

  @override
  String get currentYear => 'Año Actual';

  @override
  String get frequentConceptsDetail => 'Detalle de Conceptos Frecuentes';

  @override
  String get annualOverview => 'Ejercicio Anual';

  @override
  String get annualIncome => 'Ingresos Anuales';

  @override
  String get annualExpenses => 'Egresos Anuales';

  @override
  String get netBalance => 'Balance Neto';

  @override
  String get savingsRate => 'Tasa de Ahorro';

  @override
  String get incomeVsExpensesMonth => 'Ingresos vs Egresos Mes a Mes';

  @override
  String get detailedMonthlyBreakdown => 'Desglose Mensual Detallado';

  @override
  String incIngresoscents(Object ingresosCents) {
    return 'Ing: $ingresosCents';
  }

  @override
  String expEgresoscents(Object egresosCents) {
    return 'Egr: $egresosCents';
  }

  @override
  String get dailySpendingCurve => 'Curva de Gasto Diario';

  @override
  String get monthTotal => 'Total del Mes';

  @override
  String get highestPeak => 'Pico Más Alto';

  @override
  String get dailyExpenseTrend => 'Trayectoria Diaria de Egresos';

  @override
  String get noExpensesPeriod => 'No hay egresos en este período';

  @override
  String get totalExpenses => 'Total Gastos';

  @override
  String tostringasfixedTotal(Object toStringAsFixed) {
    return '$toStringAsFixed% del total';
  }

  @override
  String dayDianumSpentEgresoscents(Object diaNum, Object egresosCents) {
    return 'Día $diaNum\nGasto: $egresosCents';
  }

  @override
  String get searchItemPluCode => 'Buscar artículo o código PLU...';

  @override
  String get compareInflationBetweenPeriods =>
      'Comparar Inflación entre Períodos';

  @override
  String get noRecordedItemsFound => 'No se encontraron artículos registrados';

  @override
  String get itemsRecordedWhenYouEnter =>
      'Los artículos se registran al cargar tickets o egresos detallados';

  @override
  String get priceHistoryTrend => 'Historial de Precios y Tendencia';

  @override
  String get noHistoricalDataItem =>
      'No hay datos históricos para este artículo';

  @override
  String get currentPrice => 'Precio Actual';

  @override
  String get totalChange => 'Variación Total';

  @override
  String get historicalLow => 'Mínimo Histórico';

  @override
  String get historicalHigh => 'Máximo Histórico';

  @override
  String get unitPriceTrend => 'Evolución del Precio Unitario';

  @override
  String get purchaseHistory => 'Historial de Compras';

  @override
  String get inflationMonitor => 'Monitor de Inflación';

  @override
  String get comparisonIdenticalItemsPurchased =>
      'Comparativa de artículos idénticos comprados';

  @override
  String get noIdenticalItemsWerePurchased =>
      'No se detectaron artículos idénticos comprados en ambos períodos seleccionados.';

  @override
  String get personalAverageInflation => 'Inflación Promedio Personal';

  @override
  String productoscomunesItemsComparedProductosaumentaronWent(
      Object productosComunes, Object productosAumentaron) {
    return '$productosComunes artículos comparados ($productosAumentaron subieron de precio)';
  }

  @override
  String get detailItem => 'Detalle por Artículo';

  @override
  String beforePrecio1centsNowPrecio2cents(
      Object precio1Cents, Object precio2Cents) {
    return 'Antes: $precio1Cents ➔ Ahora: $precio2Cents';
  }

  @override
  String get loadingFinances => 'Cargando tu espacio financiero...';

  @override
  String get category2 => 'La categoría';

  @override
  String get systemReservedCategoriesCannotChanged =>
      'Las categorías reservadas del sistema no pueden modificarse ni eliminarse';

  @override
  String get categoryNameRequired => 'El nombre de la categoría es obligatorio';

  @override
  String nameCannotExceedCategorynamemaxCharacters(Object categoryNameMax) {
    return 'El nombre no puede superar $categoryNameMax caracteres';
  }

  @override
  String couldNotOpenLocalDatabase(Object e) {
    return 'No se pudo abrir la base local: $e';
  }

  @override
  String get filterBalancesUpDate => 'Filtrar saldos hasta fecha';

  @override
  String get refreshBalances => 'Actualizar saldos';

  @override
  String get settings => 'Ajustes y Configuración';

  @override
  String myAccountsAccounts(Object accounts) {
    return 'Mis Cuentas ($accounts)';
  }

  @override
  String get limitsBudgets => 'Límites y Presupuestos';

  @override
  String get consolidatedBalances => 'Saldos Consolidados';

  @override
  String get hideBalances => 'Ocultar saldos';

  @override
  String get filterDate => 'Filtrar por fecha';

  @override
  String untilFechaformatted(Object fechaFormatted) {
    return 'Hasta: $fechaFormatted';
  }

  @override
  String get selectSourceAccount => 'Debes seleccionar una cuenta de origen';

  @override
  String selectCategoryLineI(Object i) {
    return 'Debes seleccionar una categoría para el Renglón #$i';
  }

  @override
  String get qrReceiptsCannotConfirmedHere =>
      'No se pueden confirmar tickets QR en este contexto';

  @override
  String get accountNotServerYetSync =>
      'La cuenta todavía no está en el servidor: sincronizá y volvé a intentar';

  @override
  String get fillConceptField => 'Debe completar el campo Concepto';

  @override
  String categoryNameNotServerYet(Object name) {
    return 'La categoría $name todavía no está en el servidor: sincronizá';
  }

  @override
  String lineIMustHaveAmount(Object i) {
    return 'El Renglón #$i debe tener un monto mayor a 0';
  }

  @override
  String get expenseDate => 'Fecha del egreso';

  @override
  String get sourceAccount => 'Cuenta de Origen';

  @override
  String get generalConcept2 => 'Concepto General *';

  @override
  String get eGSupermarketBookstore => 'Ej: Supermercado, Librería...';

  @override
  String get addLine => 'Agregar Renglón';

  @override
  String get expenseTotal => 'Total del Gasto';

  @override
  String get scannedQrCodeNotValid =>
      'El código QR escaneado no es una dirección web válida (http/https).';

  @override
  String get loadingExpenses => 'Cargando gastos...';

  @override
  String receiptReadItemsLines(Object items) {
    return 'Ticket leído: $items renglones';
  }

  @override
  String get couldNotProcessQr => 'No se pudo procesar QR';

  @override
  String motivoDoYouWantScan(Object motivo) {
    return '$motivo\n\n¿Deseas intentar reescanear el QR o usar la lectura por fotos?';
  }

  @override
  String get usePhotos => 'Usar fotos';

  @override
  String get scannerNotAvailableDeviceSelect =>
      'El escáner no está disponible en este dispositivo. Selecciona fotos de la galería.';

  @override
  String get couldNotAccessGalleryCheck =>
      'No se pudo acceder a la galería. Verifica los permisos.';

  @override
  String lineRenglonnum(Object renglonNum) {
    return 'Renglón #$renglonNum';
  }

  @override
  String get deleteLine2 => 'Eliminar renglón';

  @override
  String get eGVegetablesMeatCleaning => 'Ej: Verduras, Carne, Limpieza...';

  @override
  String get selectDestinationAccount => 'Selecciona una cuenta de destino';

  @override
  String get incomeDate => 'Fecha del ingreso';

  @override
  String get amountAdd => 'Monto a Ingresar';

  @override
  String get conceptReason => 'Concepto / Motivo';

  @override
  String eGSalaryFreelancePayment(Object conceptoIngresoPorDefecto) {
    return 'Ej: Sueldo, Cobro freelance, Venta... (vacío: \"$conceptoIngresoPorDefecto\")';
  }

  @override
  String get recordIncome2 => 'Registrar Ingreso';

  @override
  String get amountMustGreaterThanZero => 'El monto debe ser mayor a cero';

  @override
  String get selectLeastOneCategory => 'Seleccione al menos una categoría';

  @override
  String mostBudgetmaxcategoriesCategories(Object budgetMaxCategories) {
    return 'Máximo $budgetMaxCategories categorías';
  }

  @override
  String get selectLeastOneAccountApply =>
      'Debe seleccionar al menos un lugar donde aplicar el límite de gastos';

  @override
  String get limit2 => 'El límite';

  @override
  String get invalidDate => 'Fecha inválida';

  @override
  String get endDateCannotBeforeStart =>
      'La fecha hasta no puede ser anterior a la fecha desde';

  @override
  String get generalConcept3 => 'El concepto general';

  @override
  String get changeAccountsTransferEditSource =>
      'Para cambiar las cuentas de una transferencia editá origen y destino';

  @override
  String get movementCannotMovedAccountAnother =>
      'No se puede mover el movimiento a una cuenta de otra moneda';

  @override
  String get transferLinesEditedAsPair =>
      'Los renglones de una transferencia se editan como par (origen, destino y monto)';

  @override
  String get concept2 => 'El concepto';

  @override
  String get incomesAlwaysUseReservedIncome =>
      'Los ingresos usan siempre la categoría reservada de ingresos';

  @override
  String get selectCategory => 'Seleccione una categoría';

  @override
  String categoryNameReservedCannotUsed(Object name) {
    return 'La categoría $name es reservada y no puede usarse en egresos';
  }

  @override
  String categoryNameInactive(Object name) {
    return 'La categoría $name está inactiva';
  }

  @override
  String get singleLineTransferCannotDeleted =>
      'No se puede eliminar un solo renglón de una transferencia; eliminá el movimiento completo';

  @override
  String get onlyLineVoucherDeleteWhole =>
      'Es el único renglón del comprobante; eliminá el movimiento completo';

  @override
  String get movementNotTransfer => 'El movimiento no es una transferencia';

  @override
  String get transferDoesNotHaveIts =>
      'La transferencia no tiene su par de renglones en el celular';

  @override
  String get sourceDestinationAccountsCannotSame =>
      'La cuenta de origen y de destino no pueden ser iguales';

  @override
  String get cannotTransferBetweenAccountsDifferent =>
      'No se puede transferir entre cuentas de distinta moneda';

  @override
  String get voucherNotPhoneSyncTry =>
      'El comprobante no está en el celular; sincronizá y volvé a intentar';

  @override
  String get lineNoLongerPhone => 'El renglón ya no está en el celular';

  @override
  String get voucherHasNotReachedServer =>
      'El comprobante todavía no llegó al servidor: sincronizá antes de editar o borrar sus renglones';

  @override
  String accountNameInactive(Object name) {
    return 'La cuenta $name está inactiva';
  }

  @override
  String get enterLeastOneExpense => 'Debe ingresar al menos un gasto';

  @override
  String get most300LinesPerExpense => 'Máximo 300 renglones por egreso';

  @override
  String get selectAccountDebit =>
      'Debe seleccionar un lugar para realizar el débito';

  @override
  String conceptLineI(Object i) {
    return 'El concepto del renglón $i';
  }

  @override
  String selectCategoryLineI2(Object i) {
    return 'Seleccione una categoría en el renglón $i';
  }

  @override
  String get selectDestinationAccount2 =>
      'Debe seleccionar la cuenta de destino';

  @override
  String get selectSourceAccount2 => 'Seleccione la cuenta de origen';

  @override
  String get selectDestinationAccount3 => 'Seleccione la cuenta de destino';

  @override
  String get cannotTransferBetweenAccountsDifferent2 =>
      'No se puede transferir entre cuentas de distinta moneda. Registrá un egreso y un ingreso con la cotización usada.';

  @override
  String conceptCannotExceedConceptmaxCharacters(Object conceptMax) {
    return 'El concepto no puede superar $conceptMax caracteres';
  }

  @override
  String get operationCorrectNoLongerRejected =>
      'La operación a corregir ya no está rechazada';

  @override
  String systemCategoryRoleMissingSync(Object role) {
    return 'Falta la categoría del sistema $role: sincronizá con conexión antes de cargar.';
  }

  @override
  String get languageDefaultCurrency => 'Idioma y Moneda por Defecto';

  @override
  String get appLanguage => 'Idioma de la Aplicación';

  @override
  String get defaultCurrencyNewAccounts =>
      'Moneda por Defecto (al crear cuentas)';

  @override
  String get sessionDiagnosticsDebug => 'Diagnóstico de sesión (debug)';

  @override
  String get n2ParallelGetAuthMe => '2 GET /auth/me en paralelo';

  @override
  String get management => 'Módulos de Gestión Administrativa';

  @override
  String get accountsPaymentMethods => 'Cuentas y Medios de Pago';

  @override
  String get manageBanksWalletsCash =>
      'Gestionar bancos, billeteras y efectivo (ABM Lugares)';

  @override
  String get createRenameActivateExpenseCategories =>
      'Crear, renombrar y activar categorías de gasto';

  @override
  String get budgetsSpendingCaps => 'Presupuestos y Topes de Gasto';

  @override
  String get monthlyLimitsAlertsOneTap =>
      'Límites mensuales, alertas y renovación en 1 tap';

  @override
  String get reportsPriceMonitor => 'Reportes y Monitor de Precios';

  @override
  String get visualAnalyticsChartsInflationTrends =>
      'Analíticas visuales, gráficos y evolución de inflación';

  @override
  String get appearanceTheme => 'Apariencia y Tema';

  @override
  String get displayMode => 'Modo de Visualización';

  @override
  String get initialSetup => 'Configuración Inicial';

  @override
  String get welcomePleaseChooseInitialPreferences =>
      '¡Bienvenido! Elegí tus preferencias iniciales:';

  @override
  String get n1UsualCurrencyDefault => '1. Moneda Habitual (Por Defecto)';

  @override
  String get n2PreferredLanguage => '2. Idioma de Preferencia';

  @override
  String get selectSourceDestinationAccounts =>
      'Selecciona cuenta de origen y destino';

  @override
  String get transferDate => 'Fecha de la transferencia';

  @override
  String get source => 'Desde (Origen)';

  @override
  String get selectSource => 'Seleccionar origen';

  @override
  String get swapAccounts => 'Invertir cuentas';

  @override
  String get destination => 'Hacia (Destino)';

  @override
  String get amountTransfer => 'Monto a Transferir';

  @override
  String get conceptReference => 'Concepto / Referencia';

  @override
  String get eGWithdrawal => 'Ej: Extraccion';

  @override
  String get confirmTransfer => 'Confirmar Transferencia';

  @override
  String notOnPhoneSync(String what) {
    return '$what no está en el celular; sincronizá y volvé a intentar';
  }

  @override
  String fieldRequired(String field) {
    return '$field es obligatorio';
  }

  @override
  String fieldTooLong(String field, int max) {
    return '$field no puede superar $max caracteres';
  }

  @override
  String amountOfMustBePositive(String what) {
    return 'El monto del $what debe ser mayor a cero';
  }

  @override
  String lineN(int n) {
    return 'renglón $n';
  }

  @override
  String get incomeWord => 'ingreso';

  @override
  String get transferWord => 'transferencia';

  @override
  String insufficientFundsTransfer(
      String amount, String account, String available) {
    return 'No dispone del saldo solicitado a transferir ($amount) en $account: disponible $available. Realizá un ingreso en la cuenta de origen.';
  }

  @override
  String insufficientFundsTransferEdit(String amount, String account) {
    return 'No dispone del saldo solicitado a transferir ($amount) en $account. Realizá un ingreso en la cuenta de origen.';
  }

  @override
  String categoryNotForBudgets(String name) {
    return 'La categoría $name no puede usarse en límites de gasto';
  }

  @override
  String get accountAlreadyActive => 'La cuenta ya está activa';

  @override
  String get accountAlreadyInactive => 'La cuenta ya está inactiva';

  @override
  String get categoryAlreadyActive => 'La categoría ya está activa';

  @override
  String get categoryAlreadyInactive => 'La categoría ya está inactiva';

  @override
  String get accountNameTaken => 'Ya existe una cuenta con ese nombre';

  @override
  String get accountNameTakenInactive =>
      'Ya existe una cuenta inactiva con ese nombre: activala';

  @override
  String get categoryNameTaken => 'Ya existe una categoría con ese nombre';

  @override
  String get categoryNameTakenInactive =>
      'Ya existe una categoría inactiva con ese nombre: activala';

  @override
  String get alreadyTriedSyncBeforeDiscard =>
      'Ya se intentó enviar: podría estar aplicada en el servidor. Sincronizá antes de descartarla.';

  @override
  String get comparison => 'Comparativa';

  @override
  String get prices => 'Precios';

  @override
  String get custom => 'Personalizado';

  @override
  String get surplus => 'Superávit';

  @override
  String get deficit => 'Déficit';

  @override
  String get income2 => 'Ingresos';

  @override
  String get expenses => 'Egresos';

  @override
  String get apply => 'Aplicar';

  @override
  String get clear => 'Limpiar';

  @override
  String get expenses2 => 'Gastos';

  @override
  String get transfer2 => 'Transferir';

  @override
  String get history => 'Historial';

  @override
  String get date => 'Fecha';

  @override
  String get destinationAccount => 'Cuenta de destino.';

  @override
  String get system => 'Sistema';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Oscuro';

  @override
  String get start => 'Comenzar';

  @override
  String linesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count renglones',
      one: '1 renglón',
    );
    return '$_temp0';
  }

  @override
  String purchasesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count compras',
      one: '1 compra',
    );
    return '$_temp0';
  }

  @override
  String ticketSumDiffers(String sum, String total, String diff) {
    return 'Suma de renglones ($sum) difiere del total del ticket ($total): diferencia $diff. Revisá los montos.';
  }

  @override
  String ticketReadSumTotal(String sum, String total) {
    return 'Ticket leído: suma $sum | total $total';
  }

  @override
  String ticketSumNoTotal(String sum) {
    return 'Suma de renglones: $sum (no se detectó un total en el ticket).';
  }

  @override
  String chartMonthTooltip(
      String month, String kind, String amount, String balance) {
    return '$month\n$kind: $amount\nBalance: $balance';
  }

  @override
  String get currencyArs => 'Pesos argentinos (ARS \$)';

  @override
  String get currencyUsd => 'Dólares (USD \$)';

  @override
  String get cameraPermissionDenied =>
      'Sin permiso para usar la cámara. Habilitalo en los ajustes del celular para leer el QR.';

  @override
  String get cameraUnsupported => 'Este celular no permite leer códigos QR.';

  @override
  String get cameraError => 'No se pudo usar la cámara.';

  @override
  String get errInsecureTransport =>
      'La dirección del servidor no usa HTTPS: esta versión de la app solo se conecta por HTTPS.';

  @override
  String get ticketAlreadyRegistered =>
      'Este ticket ya estaba registrado; no se cargó de nuevo.';

  @override
  String ticketRecordedNotOnPhoneYet(String error) {
    return 'Ticket registrado en el servidor, pero no se pudo traer al celular: $error. Va a aparecer en la próxima sincronización.';
  }

  @override
  String get syncOfflineSaved =>
      'Sin conexión con el servidor: lo que cargues se guarda en el celular y se envía cuando vuelva.';

  @override
  String get qrNeedsConnection => 'La lectura por QR necesita conexión';

  @override
  String savedThing(String what) {
    return '$what guardado.';
  }

  @override
  String get changesSaved => 'Cambios guardados.';

  @override
  String get dashboardYou => 'tú';

  @override
  String get dashboards => 'Dashboards';

  @override
  String get manageDashboards => 'Gestionar dashboards';

  @override
  String get chooseDashboard => 'Elegir dashboard';

  @override
  String get dashboardSharedTag => 'compartido';

  @override
  String get dashboardPrincipalTag => 'principal';

  @override
  String get invitationTitle => 'Te compartieron un dashboard';

  @override
  String invitationBody(String inviter, String email, String dashboard) {
    return '$inviter ($email) te invitó a compartir su dashboard \"$dashboard\".';
  }

  @override
  String get acceptInvitation => 'Aceptar';

  @override
  String get rejectInvitation => 'Rechazar';

  @override
  String notificationAccepted(String user, String dashboard) {
    return '$user aceptó compartir el dashboard \"$dashboard\".';
  }

  @override
  String notificationRejected(String user, String dashboard) {
    return '$user rechazó compartir el dashboard \"$dashboard\".';
  }

  @override
  String get accessLostNotice =>
      'Ya no tenés acceso a ese dashboard: se muestra tu dashboard principal.';

  @override
  String movementCreatedBy(String name) {
    return 'Cargado por $name';
  }

  @override
  String get dashboardName => 'Nombre del dashboard';

  @override
  String get dashboardDefaultName => 'principal';

  @override
  String get displayName => 'Nombre para mostrar';

  @override
  String get displayNameHint =>
      'Lo ven las personas con las que compartís un dashboard. No tiene que ser único.';

  @override
  String get displayNameSaved => 'Nombre guardado.';

  @override
  String get yourDashboards => 'Tus dashboards';

  @override
  String get sharedWithYou => 'Compartidos con vos';

  @override
  String get newDashboard => 'Nuevo dashboard';

  @override
  String get createDashboard => 'Crear';

  @override
  String get shareWithEmail =>
      'Compartir con (correo de un usuario registrado)';

  @override
  String get shareDashboard => 'Compartir';

  @override
  String invitationSent(String email) {
    return 'Se envió la invitación a $email. Cuando la acepte o la rechace te llega un aviso.';
  }

  @override
  String get dashboardMembers => 'Integrantes';

  @override
  String get ownerTag => 'dueño';

  @override
  String ownedBy(String name) {
    return 'de $name';
  }

  @override
  String get removeAccess => 'Quitar acceso';

  @override
  String get leaveDashboard => 'Salir';

  @override
  String get openDashboard => 'Abrir';

  @override
  String get clearDashboard => 'Limpiar dashboard';

  @override
  String get deleteDashboard => 'Eliminar dashboard';

  @override
  String get saveName => 'Guardar nombre';

  @override
  String confirmClearDashboard(String name) {
    return 'Se borran todos los movimientos, tickets y límites de \"$name\". Se conservan las cuentas y las categorías. No se puede deshacer.';
  }

  @override
  String confirmDeleteDashboard(String name) {
    return 'Se elimina \"$name\" con todo su contenido y se quita el acceso a todos los invitados. No se puede deshacer.';
  }

  @override
  String confirmLeaveDashboard(String name) {
    return 'Dejás de ver \"$name\". Para volver, el dueño te tiene que invitar de nuevo.';
  }

  @override
  String confirmRemoveMember(String user, String name) {
    return '$user deja de ver \"$name\".';
  }

  @override
  String dashboardCreated(String name) {
    return 'Se creó el dashboard \"$name\".';
  }

  @override
  String get dashboardRenamed => 'Se cambió el nombre.';

  @override
  String get dashboardClearedMsg => 'Se limpió el dashboard.';

  @override
  String get dashboardDeletedMsg => 'Se eliminó el dashboard.';

  @override
  String get dashboardLeftMsg => 'Saliste del dashboard.';

  @override
  String get accessRemovedMsg => 'Se quitó el acceso.';

  @override
  String get dashboardsNeedConnection =>
      'Administrar y compartir dashboards necesita conexión.';

  @override
  String get noNotifications2 => 'No tenés avisos.';

  @override
  String get errDashboardForbidden => 'No tenés acceso a ese dashboard.';

  @override
  String get errNotCreator => 'Solo quien lo cargó puede modificarlo.';

  @override
  String get errOwnerOnly => 'Solo el dueño del dashboard puede hacer esto.';

  @override
  String get errUserNotRegistered =>
      'Solo se puede compartir con usuarios registrados.';

  @override
  String get errAlreadyMember =>
      'Esa persona ya tiene acceso a este dashboard.';

  @override
  String get errSelfInvite => 'No podés compartir un dashboard con vos mismo.';

  @override
  String get errOwnerCannotLeave => 'El dueño no puede salir de su dashboard.';

  @override
  String get errPrincipalUndeletable =>
      'El dashboard principal no se elimina; se puede limpiar.';

  @override
  String get errNotPrincipal =>
      'Solo se limpia el dashboard principal; los demás se eliminan.';

  @override
  String get errInvitationClosed => 'La invitación ya fue respondida.';
}
