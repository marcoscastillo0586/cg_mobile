// CRAP por función (complejidad ciclomática × cobertura) para lib/ de cg_mobile.
//   CRAP = c² · (1 − cov)³ + c      c = complejidad, cov = fracción de líneas cubiertas
// Uso (desde cg_mobile): flutter test --coverage
//                        dart run tools/crap/bin/crap.dart [--min 10]
// Lee coverage/lcov.info; un archivo que no figura cuenta como 0 %.
import 'dart:io';
import 'dart:math';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

double crap(int c, double cov) => c * c * pow(1 - cov, 3).toDouble() + c;

/// Cada punto de decisión suma 1 (if, ?:, case, bucles, catch, &&, ||, ??). Las funciones anidadas
/// se miden aparte.
class _Complexity extends RecursiveAstVisitor<void> {
  final AstNode root;
  int value = 1;
  _Complexity(this.root);

  bool _nested(AstNode n) => n != root && (n is FunctionExpression || n is FunctionDeclaration);

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (_nested(node) && node.parent != root) return;
    super.visitFunctionExpression(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (_nested(node)) return;
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitIfStatement(IfStatement node) => _count(node, super.visitIfStatement);
  @override
  void visitIfElement(IfElement node) => _count(node, super.visitIfElement);
  @override
  void visitConditionalExpression(ConditionalExpression node) => _count(node, super.visitConditionalExpression);
  @override
  void visitSwitchCase(SwitchCase node) => _count(node, super.visitSwitchCase);
  @override
  void visitSwitchPatternCase(SwitchPatternCase node) => _count(node, super.visitSwitchPatternCase);
  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) => _count(node, super.visitSwitchExpressionCase);
  @override
  void visitForStatement(ForStatement node) => _count(node, super.visitForStatement);
  @override
  void visitForElement(ForElement node) => _count(node, super.visitForElement);
  @override
  void visitWhileStatement(WhileStatement node) => _count(node, super.visitWhileStatement);
  @override
  void visitDoStatement(DoStatement node) => _count(node, super.visitDoStatement);
  @override
  void visitCatchClause(CatchClause node) => _count(node, super.visitCatchClause);

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.type;
    if (op == TokenType.AMPERSAND_AMPERSAND || op == TokenType.BAR_BAR || op == TokenType.QUESTION_QUESTION) value++;
    super.visitBinaryExpression(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (node.operator.type == TokenType.QUESTION_QUESTION_EQ) value++;
    super.visitAssignmentExpression(node);
  }

  void _count<T extends AstNode>(T node, void Function(T) visitChildren) {
    value++;
    visitChildren(node);
  }
}

int complexityOf(AstNode fn) {
  final v = _Complexity(fn);
  fn.visitChildren(v);
  return v.value;
}

class Row {
  final String file;
  final int line;
  final String name;
  final int complexity;
  final double coverage;
  Row(this.file, this.line, this.name, this.complexity, this.coverage);
  double get crapScore => crap(complexity, coverage);
}

/// líneas instrumentadas → veces ejecutada, por archivo (rutas relativas con '/').
Map<String, Map<int, int>> readLcov(File f) {
  final out = <String, Map<int, int>>{};
  if (!f.existsSync()) return out;
  Map<int, int>? current;
  for (final line in f.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      final path = line.substring(3).replaceAll('\\', '/');
      final i = path.indexOf('lib/');
      current = out.putIfAbsent(i >= 0 ? path.substring(i) : path, () => {});
    } else if (line.startsWith('DA:') && current != null) {
      final parts = line.substring(3).split(',');
      current[int.parse(parts[0])] = int.parse(parts[1]);
    }
  }
  return out;
}

double coverageBetween(Map<int, int>? lines, int start, int end) {
  if (lines == null) return 0;
  var total = 0, hit = 0;
  lines.forEach((l, hits) {
    if (l >= start && l <= end) {
      total++;
      if (hits > 0) hit++;
    }
  });
  return total == 0 ? 1 : hit / total;
}

class _Functions extends RecursiveAstVisitor<void> {
  final String file;
  final LineInfo lines;
  final Map<int, int>? cov;
  final rows = <Row>[];
  _Functions(this.file, this.lines, this.cov);

  void _add(AstNode node, String name) {
    final start = lines.getLocation(node.offset).lineNumber;
    final end = lines.getLocation(node.end).lineNumber;
    rows.add(Row(file, start, name, complexityOf(node), coverageBetween(cov, start, end)));
  }

  String _owner(AstNode n) {
    for (AstNode? p = n.parent; p != null; p = p.parent) {
      if (p is ClassDeclaration) return '${p.namePart.typeName.lexeme}.';
      if (p is MixinDeclaration) return '${p.name.lexeme}.';
      if (p is ExtensionDeclaration) return '${p.name?.lexeme ?? 'extension'}.';
    }
    return '';
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _add(node, node.name.lexeme);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _add(node, '${_owner(node)}${node.name.lexeme}');
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _add(node, '${_owner(node)}${node.name?.lexeme ?? 'new'}');
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.parent is! FunctionDeclaration) {
      final call = node.thisOrAncestorOfType<MethodInvocation>();
      _add(node, '(closure en ${call?.methodName.name ?? '?'})');
    }
    super.visitFunctionExpression(node);
  }
}

void main(List<String> args) {
  final minAt = args.indexOf('--min');
  final min = minAt >= 0 ? double.parse(args[minAt + 1]) : 10.0;
  final coverage = readLcov(File('coverage/lcov.info'));
  final rows = <Row>[];
  final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  for (final f in files) {
    final rel = f.path.replaceAll('\\', '/');
    if (rel.contains('/l10n/app_localizations')) continue; // generado
    final result = parseString(content: f.readAsStringSync(), path: f.absolute.path, throwIfDiagnostics: false);
    final v = _Functions(rel, result.lineInfo, coverage[rel]);
    result.unit.accept(v);
    rows.addAll(v.rows);
  }
  rows.sort((a, b) => b.crapScore.compareTo(a.crapScore));
  final over = rows.where((r) => r.crapScore >= min).toList();
  for (final r in over) {
    stdout.writeln('${r.crapScore.toStringAsFixed(1).padLeft(7)}  c=${r.complexity.toString().padLeft(2)}  '
        'cov=${(r.coverage * 100).toStringAsFixed(0).padLeft(3)}%  ${r.file}:${r.line}  ${r.name}');
  }
  stdout.writeln('\n${over.length} de ${rows.length} funciones con CRAP ≥ ${min.toStringAsFixed(0)}');
  exitCode = over.isEmpty ? 0 : 1;
}
