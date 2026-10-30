import 'dart:math';
import 'receipt_spatial_parser.dart';

/// Resultado de encadenar una parte con la anterior.
enum TicketJoinStatus {
  /// Se encontró una sola superposición válida (la más larga y de mejor puntaje).
  ok,

  /// No hay una superposición que coincida: la parte no se une.
  noOverlap,

  /// Hay más de una superposición igual de buena: se une con la mejor y se avisa para revisar.
  ambiguous,
}

/// Con qué se encontró la superposición.
enum TicketJoinMethod {
  /// Secuencia de códigos de barras repetidos (los productos de Coto tienen un código de 12 a 14 dígitos).
  codes,

  /// Secuencia de filas de texto parecidas (tickets sin códigos o con códigos ilegibles).
  text,
}

/// Cómo se encadenó la parte [part] (1 = la primera) con la anterior.
class TicketPartJoin {
  final int part;
  final TicketJoinStatus status;
  final TicketJoinMethod? method;

  /// Filas del comienzo de [part] descartadas por repetidas (o sueltas en el borde).
  final int overlapRows;

  /// Similitud promedio de la superposición (0..1).
  final double score;

  const TicketPartJoin({required this.part, required this.status, this.method, this.overlapRows = 0, this.score = 0});
}

/// Filas del ticket largo unidas, o la primera parte que no se pudo encadenar.
class TicketMergeResult {
  /// Filas unidas, con su texto ORIGINAL (las de A hasta la superposición más las de B después de ella).
  final List<SpatialRow> rows;
  final List<TicketPartJoin> joins;

  const TicketMergeResult({required this.rows, required this.joins});

  /// Primera parte que no se pudo encadenar con la anterior (null si se unieron todas).
  TicketPartJoin? get failed => joins.where((j) => j.status == TicketJoinStatus.noOverlap).firstOrNull;

  /// Partes unidas con una superposición ambigua (conviene revisar sus renglones).
  List<TicketPartJoin> get ambiguous => joins.where((j) => j.status == TicketJoinStatus.ambiguous).toList();
}

/// Une las filas de las partes de un ticket largo (de arriba hacia abajo) eliminando solo la parte
/// repetida entre fotos consecutivas A y B. Busca la superposición entre las últimas [window] filas de A y
/// las primeras [window] de B:
///  1. Por CÓDIGOS DE BARRAS: al menos [minAnchors] códigos consecutivos repetidos (similitud >= [codeThreshold],
///     tolera un dígito mal leído). Es lo más firme: no depende de cómo se agruparon las filas ni de errores
///     en los nombres. El corte es la fila del último código repetido. El primer código de B y el último de A
///     pueden estar cortados por el borde.
///  2. Si no alcanza, por TEXTO: al menos [minRun] filas CONSECUTIVAS con similitud (Levenshtein normalizada)
///     >= [threshold], en cualquier lugar de esas ventanas; las filas sueltas del borde (sombras, medias
///     líneas) que quedan después de la superposición en A o antes en B se descartan.
///  Entre varias superposiciones gana la más larga y de mejor puntaje (y la que descarta menos filas); si queda
///  empatada con otra alineación, es ambigua: se une igual y se avisa. Sin superposición válida NO se une.
///  Un producto repetido fuera de la superposición queda (los dos KRACHITOS con códigos distintos).
class TicketRowMerger {
  final int window;
  final int minRun;
  final double threshold;
  final int minAnchors;
  final double codeThreshold;

  const TicketRowMerger({this.window = 15, this.minRun = 3, this.threshold = 0.85, this.minAnchors = 2, this.codeThreshold = 0.9});

  TicketMergeResult merge(List<List<SpatialRow>> parts) {
    if (parts.isEmpty) return const TicketMergeResult(rows: [], joins: []);
    var rows = List<SpatialRow>.of(parts.first);
    final joins = <TicketPartJoin>[const TicketPartJoin(part: 1, status: TicketJoinStatus.ok)];
    for (var p = 1; p < parts.length; p++) {
      final join = this.join(rows, parts[p], p + 1);
      joins.add(join.$1);
      if (join.$1.status == TicketJoinStatus.noOverlap) break; // no se une: hay que rehacer esa parte
      rows = join.$2;
    }
    return TicketMergeResult(rows: _reindex(rows), joins: joins);
  }

  /// Superposición de A (filas ya unidas) con B: cómo se encadenó y las filas resultantes.
  (TicketPartJoin, List<SpatialRow>) join(List<SpatialRow> a, List<SpatialRow> b, int part) =>
      _joinByCodes(a, b, part) ?? _joinByText(a, b, part) ?? (TicketPartJoin(part: part, status: TicketJoinStatus.noOverlap), a);

  (TicketPartJoin, List<SpatialRow>)? _joinByCodes(List<SpatialRow> a, List<SpatialRow> b, int part) {
    final aFrom = max(0, a.length - window);
    final bTo = min(b.length, window);
    final anchorsA = [
      for (var i = aFrom; i < a.length; i++)
        if (barcode(a[i].fullText) case final k?) (row: i, key: k)
    ];
    final anchorsB = [
      for (var j = 0; j < bTo; j++)
        if (barcode(b[j].fullText) case final k?) (row: j, key: k)
    ];
    if (anchorsA.length < minAnchors || anchorsB.length < minAnchors) return null;

    _Candidate? best;
    var tied = false;
    for (var ia = 0; ia < anchorsA.length; ia++) {
      // El primer código de B puede estar cortado por el borde (jb = 1).
      for (var jb = 0; jb <= 1 && jb < anchorsB.length; jb++) {
        var len = 0;
        var sum = 0.0;
        while (ia + len < anchorsA.length && jb + len < anchorsB.length) {
          final s = similarity(anchorsA[ia + len].key, anchorsB[jb + len].key);
          if (s < codeThreshold) break;
          sum += s;
          len++;
        }
        // Hasta el último código de A (o el penúltimo, si el último está cortado).
        final reachesEnd = ia + len == anchorsA.length || ia + len == anchorsA.length - 1;
        if (len < minAnchors || !reachesEnd) continue;
        final cutA = anchorsA[ia + len - 1].row;
        final cutB = anchorsB[jb + len - 1].row;
        final c = _Candidate(cutA: cutA, cutB: cutB, length: len, score: sum / len, discarded: a.length - 1 - cutA);
        (best, tied) = _pick(best, tied, c);
      }
    }
    if (best == null) return null;
    return _result(a, b, part, best, tied, TicketJoinMethod.codes);
  }

  (TicketPartJoin, List<SpatialRow>)? _joinByText(List<SpatialRow> a, List<SpatialRow> b, int part) {
    final na = a.map((r) => normalize(r.fullText)).toList();
    final nb = b.map((r) => normalize(r.fullText)).toList();
    final aFrom = max(0, a.length - window);
    final bTo = min(b.length, window);

    _Candidate? best;
    var tied = false;
    for (var i = aFrom; i < a.length; i++) {
      for (var j = 0; j < bTo; j++) {
        var len = 0;
        var sum = 0.0;
        while (i + len < a.length && j + len < bTo) {
          final s = similarity(na[i + len], nb[j + len]);
          if (s < threshold) break;
          sum += s;
          len++;
        }
        if (len < minRun) continue;
        final cutA = i + len - 1;
        final cutB = j + len - 1;
        final c = _Candidate(cutA: cutA, cutB: cutB, length: len, score: sum / len, discarded: (a.length - 1 - cutA) + j);
        (best, tied) = _pick(best, tied, c);
      }
    }
    if (best == null) return null;
    return _result(a, b, part, best, tied, TicketJoinMethod.text);
  }

  /// La más larga, de mejor puntaje y que descarta menos filas. Otra igual con otra alineación = ambigua.
  static (_Candidate, bool) _pick(_Candidate? best, bool tied, _Candidate c) {
    if (best == null || c.betterThan(best)) return (c, false);
    if (c.ties(best) && c.offset != best.offset) return (c.discarded < best.discarded ? c : best, true);
    return (best, tied);
  }

  /// A hasta el final de la superposición + B después de ella (texto original).
  static (TicketPartJoin, List<SpatialRow>) _result(
    List<SpatialRow> a,
    List<SpatialRow> b,
    int part,
    _Candidate best,
    bool tied,
    TicketJoinMethod method,
  ) {
    final merged = [...a.sublist(0, best.cutA + 1), ...b.sublist(best.cutB + 1)];
    final status = tied ? TicketJoinStatus.ambiguous : TicketJoinStatus.ok;
    return (TicketPartJoin(part: part, status: status, method: method, overlapRows: best.cutB + 1, score: best.score), merged);
  }

  static List<SpatialRow> _reindex(List<SpatialRow> rows) => [
        for (final (i, r) in rows.indexed)
          SpatialRow(index: i + 1, topY: r.topY, bottomY: r.bottomY, elements: r.elements, fullText: r.fullText, fotoOrigen: r.fotoOrigen),
      ];

  /// Código de barras de la fila: la secuencia de 12 a 14 dígitos más larga (null si no tiene).
  static String? barcode(String text) {
    String? best;
    for (final m in RegExp(r'(?<!\d)\d{12,14}(?!\d)').allMatches(text)) {
      final code = m.group(0)!;
      if (best == null || code.length > best.length) best = code;
    }
    return best;
  }

  /// Solo para comparar: mayúsculas, sin espacios repetidos ni en los extremos.
  static String normalize(String text) => text.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// 1 - distancia de Levenshtein / largo mayor (1 = iguales).
  static double similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1;
    final longest = max(a.length, b.length);
    return 1 - _levenshtein(a, b) / longest;
  }

  static int _levenshtein(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      prev = cur;
    }
    return prev[b.length];
  }
}

class _Candidate {
  /// Última fila de la superposición en A y en B (se corta ahí).
  final int cutA;
  final int cutB;
  final int length;
  final double score;

  /// Filas sueltas del borde que se descartan (después de la superposición en A y antes en B).
  final int discarded;

  const _Candidate({required this.cutA, required this.cutB, required this.length, required this.score, required this.discarded});

  /// Alineación entre A y B (dos candidatos con el mismo offset son la misma superposición).
  int get offset => cutA - cutB;

  bool betterThan(_Candidate o) =>
      length > o.length ||
      (length == o.length && score > o.score + 1e-9) ||
      (length == o.length && (score - o.score).abs() <= 1e-9 && discarded < o.discarded && offset == o.offset);

  bool ties(_Candidate o) => length == o.length && (score - o.score).abs() <= 1e-9;
}
