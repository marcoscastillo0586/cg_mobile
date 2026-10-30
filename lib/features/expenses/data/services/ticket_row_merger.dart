import 'dart:math';
import 'receipt_spatial_parser.dart';

/// Resultado de encadenar una parte con la anterior.
enum TicketJoinStatus {
  /// Se encontró una sola superposición válida (la más larga y de mejor puntaje).
  ok,

  /// No hay una secuencia de filas consecutivas que coincida: la parte no se une.
  noOverlap,

  /// Hay más de una superposición igual de buena: se une con la mejor y se avisa para revisar.
  ambiguous,
}

/// Cómo se encadenó la parte [part] (1 = la primera) con la anterior.
class TicketPartJoin {
  final int part;
  final TicketJoinStatus status;

  /// Filas superpuestas (repetidas en las dos partes) que se descartaron de [part].
  final int overlapRows;

  /// Similitud promedio de la superposición (0..1).
  final double score;

  const TicketPartJoin({required this.part, required this.status, this.overlapRows = 0, this.score = 0});
}

/// Filas del ticket largo unidas, o la primera parte que no se pudo encadenar.
class TicketMergeResult {
  /// Filas unidas, con su texto ORIGINAL (las de A más las de B después de la superposición).
  final List<SpatialRow> rows;
  final List<TicketPartJoin> joins;

  const TicketMergeResult({required this.rows, required this.joins});

  /// Primera parte que no se pudo encadenar con la anterior (null si se unieron todas).
  TicketPartJoin? get failed => joins.where((j) => j.status == TicketJoinStatus.noOverlap).firstOrNull;

  /// Partes unidas con una superposición ambigua (conviene revisar sus renglones).
  List<TicketPartJoin> get ambiguous => joins.where((j) => j.status == TicketJoinStatus.ambiguous).toList();
}

/// Une las filas de las partes de un ticket largo (de arriba hacia abajo) eliminando solo la parte
/// repetida entre fotos consecutivas A y B:
///  - compara las últimas [window] filas de A con las primeras [window] de B, normalizadas solo para comparar;
///  - la superposición es una secuencia de al menos [minRun] filas CONSECUTIVAS con similitud
///    (Levenshtein normalizada) >= [threshold]; nunca una fila aislada;
///  - la última fila de A y la primera de B pueden estar cortadas por el borde y no coincidir;
///  - entre varias superposiciones, la más larga y de mejor puntaje; si queda empatada con otra, es ambigua:
///    se une igual (prefiriendo la que llega al final exacto de A, sin descartar filas) y se avisa;
///  - sin superposición válida NO se une. Un producto repetido fuera de la superposición queda.
class TicketRowMerger {
  final int window;
  final int minRun;
  final double threshold;

  const TicketRowMerger({this.window = 15, this.minRun = 3, this.threshold = 0.85});

  TicketMergeResult merge(List<List<SpatialRow>> parts) {
    if (parts.isEmpty) return const TicketMergeResult(rows: [], joins: []);
    var rows = List<SpatialRow>.of(parts.first);
    final joins = <TicketPartJoin>[const TicketPartJoin(part: 1, status: TicketJoinStatus.ok)];
    for (var p = 1; p < parts.length; p++) {
      final join = _join(rows, parts[p], p + 1);
      joins.add(join.$1);
      if (join.$1.status == TicketJoinStatus.noOverlap) break; // no se une: hay que rehacer esa parte
      rows = join.$2;
    }
    return TicketMergeResult(rows: _reindex(rows), joins: joins);
  }

  /// Superposición de A (filas ya unidas) con B: devuelve cómo se encadenó y las filas resultantes.
  (TicketPartJoin, List<SpatialRow>) _join(List<SpatialRow> a, List<SpatialRow> b, int part) {
    final na = a.map((r) => normalize(r.fullText)).toList();
    final nb = b.map((r) => normalize(r.fullText)).toList();
    final aFrom = max(0, a.length - window);
    final bTo = min(b.length, window);

    _Candidate? best;
    var tied = false;
    for (var i = aFrom; i < a.length; i++) {
      // B puede empezar con su primera fila cortada por el borde (j = 1).
      for (var j = 0; j <= 1 && j < bTo; j++) {
        var len = 0;
        var sum = 0.0;
        while (i + len < a.length && j + len < bTo) {
          final s = similarity(na[i + len], nb[j + len]);
          if (s < threshold) break;
          sum += s;
          len++;
        }
        // Tiene que llegar al final de A (o a su penúltima fila, si la última está cortada).
        final reachesEnd = i + len == a.length || i + len == a.length - 1;
        if (len < minRun || !reachesEnd) continue;
        final c = _Candidate(aStart: i, bStart: j, length: len, score: sum / len, reachesExactEnd: i + len == a.length);
        if (best == null || c.betterThan(best)) {
          best = c;
          tied = false;
        } else if (c.ties(best) && c.offset != best.offset) {
          tied = true;
          if (c.reachesExactEnd && !best.reachesExactEnd) best = c; // empate: no descartar la última fila de A
        }
      }
    }

    if (best == null) return (TicketPartJoin(part: part, status: TicketJoinStatus.noOverlap), a);
    // A hasta el final de la superposición (sin su última fila si estaba cortada) + B después de ella.
    final merged = [...a.sublist(0, best.aStart + best.length), ...b.sublist(best.bStart + best.length)];
    final status = tied ? TicketJoinStatus.ambiguous : TicketJoinStatus.ok;
    return (TicketPartJoin(part: part, status: status, overlapRows: best.length, score: best.score), merged);
  }

  static List<SpatialRow> _reindex(List<SpatialRow> rows) => [
        for (final (i, r) in rows.indexed)
          SpatialRow(index: i + 1, topY: r.topY, bottomY: r.bottomY, elements: r.elements, fullText: r.fullText, fotoOrigen: r.fotoOrigen),
      ];

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
  final int aStart;
  final int bStart;
  final int length;
  final double score;

  /// Termina en la última fila de A (no supone que esa fila esté cortada).
  final bool reachesExactEnd;

  const _Candidate({required this.aStart, required this.bStart, required this.length, required this.score, required this.reachesExactEnd});

  /// Alineación entre A y B (dos candidatos con el mismo offset son la misma superposición).
  int get offset => aStart - bStart;

  bool betterThan(_Candidate o) => length > o.length || (length == o.length && score > o.score + 1e-9);

  bool ties(_Candidate o) => length == o.length && (score - o.score).abs() <= 1e-9;
}
