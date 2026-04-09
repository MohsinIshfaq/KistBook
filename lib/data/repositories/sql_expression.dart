SQLGroup andGroup(List<SQLExpression> expressions) =>
    SQLGroup(expressions, operator: 'AND');

SQLGroup orGroup(List<SQLExpression> expressions) =>
    SQLGroup(expressions, operator: 'OR');

abstract class SQLExpression {
  String buildQuery();

  List<Object?> get values;
}

class SQLCondition implements SQLExpression {
  const SQLCondition(this.field, this.comparator, this.value);

  final String field;
  final String comparator;
  final Object? value;

  @override
  String buildQuery() => '$field $comparator ?';

  @override
  List<Object?> get values => [value];
}

class SQLGroup implements SQLExpression {
  const SQLGroup(this.expressions, {this.operator = 'AND'});

  final List<SQLExpression> expressions;
  final String operator;

  @override
  String buildQuery() {
    final parts = expressions.map((expression) => expression.buildQuery()).join(' $operator ');
    return '($parts)';
  }

  @override
  List<Object?> get values => expressions.expand((expression) => expression.values).toList();
}
