// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library linter.src.rules.always_require_non_null_named_parameters;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/ast.dart' show AstVisitor, TypedLiteral;
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:linter/src/analyzer.dart';

const desc = 'Use @required.';

const details = '''
**DO** specify `@required` on named parameter without default value on which an
assert(param != null) is done.

**GOOD:**
```
m1({@required a}) {
  assert(a != null);
}

m2({a: 1}) {
  assert(a != null);
}
```

**BAD:**
```
m1({a}) {
  assert(a != null);
}
```

NOTE: Only asserts at the start of the bodies will be taken into account.
''';

/// The name of `meta` library, used to define analysis annotations.
String _META_LIB_NAME = "meta";

/// The name of the top-level variable used to mark a required named parameter.
String _REQUIRED_VAR_NAME = "required";

bool _isRequired(Element element) =>
    element is PropertyAccessorElement &&
    element.name == _REQUIRED_VAR_NAME &&
    element.library?.name == _META_LIB_NAME;

class AlwaysRequireNonNullNamedParameters extends LintRule {
  AlwaysRequireNonNullNamedParameters()
      : super(
            name: 'always_require_non_null_named_parameters',
            description: desc,
            details: details,
            group: Group.style);

  @override
  AstVisitor getVisitor() => new Visitor(this);
}

class Visitor extends SimpleAstVisitor {
  final LintRule rule;

  Visitor(this.rule);

  void checkLiteral(TypedLiteral literal) {
    if (literal.typeArguments == null) {
      rule.reportLintForToken(literal.beginToken);
    }
  }

  @override
  visitFormalParameterList(FormalParameterList node) {
    final params = node.parameters
        // only named parameters
        .where((p) => p.kind == ParameterKind.NAMED)
        .map((p) => p as DefaultFormalParameter)
        // without default value
        .where((p) => p.defaultValue == null)
        // without @required
        .where((p) => !p.metadata.any((a) => _isRequired(a.element)))
        .toList();
    final parent = node.parent;
    if (parent is FunctionExpression) {
      _checkParams(params, parent.body);
    } else if (parent is ConstructorDeclaration) {
      _checkParams(params, parent.body);
    } else if (parent is MethodDeclaration) {
      _checkParams(params, parent.body);
    }
  }

  _checkParams(List<DefaultFormalParameter> params, FunctionBody body) {
    if (body is BlockFunctionBody) {
      final asserts =
          body.block.statements.takeWhile((e) => e is AssertStatement).toList();
      for (final param in params) {
        if (asserts.any((e) => _hasAssertNotNull(e, param.identifier.name))) {
          rule.reportLintForToken(param.identifier.beginToken);
        }
      }
    }
  }

  bool _hasAssertNotNull(AssertStatement node, String name) {
    final expression = node.condition.unParenthesized;
    if (expression is BinaryExpression &&
        expression.operator.type == TokenType.BANG_EQ) {
      final operands = [expression.leftOperand, expression.rightOperand];
      return operands.any((e) => e is NullLiteral) &&
          operands.any((e) => e is SimpleIdentifier && e.name == name);
    }
    return false;
  }
}