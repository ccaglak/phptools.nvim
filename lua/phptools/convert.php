<?php

require_once __DIR__ . '/parser/vendor/autoload.php';

use PhpParser\Error;
use PhpParser\ParserFactory;
use PhpParser\NodeTraverser;
use PhpParser\NodeVisitorAbstract;
use PhpParser\Node\Stmt\If_;
use PhpParser\Node\Stmt\Switch_;
use PhpParser\Node\Stmt\Case_;
use PhpParser\Node\Expr\BinaryOp\Equal;
use PhpParser\Node\Expr\BinaryOp\Identical;
use PhpParser\Node\Expr\BinaryOp\BooleanAnd;
use PhpParser\Node\Expr\BinaryOp\BooleanOr;
use PhpParser\Node\Scalar\String_;
use PhpParser\PrettyPrinter;
use PhpParser\Comment;

function convertIfToSwitch($code)
{
  $parser = (new ParserFactory)->createForNewestSupportedVersion();

  try {
    $ast = $parser->parse($code);
  } catch (Error $error) {
    echo "Parse error: {$error->getMessage()}\n";
    return;
  }

  $traverser = new NodeTraverser();
  $visitor = new class extends NodeVisitorAbstract {
    public function leaveNode($node)
    {
      if ($node instanceof If_) {
        return $this->convertToSwitch($node);
      }
    }

    private function convertToSwitch(If_ $ifNode)
    {
      $switchCases = [];
      $currentNode = $ifNode;
      $switchExpr = null;

      do {
        $caseValue = null;
        $caseStmts = $currentNode->stmts;

        list($switchExpr, $caseValue) = $this->processCondition($currentNode->cond, $switchExpr);

        $case = new Case_($caseValue, $caseStmts);
        $case->setAttribute('comments', $currentNode->getComments());
        $switchCases[] = $case;

        if ($currentNode->else) {
          $defaultCase = new Case_(null, $currentNode->else->stmts);
          $defaultCase->setAttribute('comments', $currentNode->else->getComments());
          $switchCases[] = $defaultCase;
          break;
        }

        if (!empty($currentNode->elseifs)) {
          $currentNode = $currentNode->elseifs[0];
        } else {
          break;
        }
      } while (true);

      $switchNode = new Switch_($switchExpr ?? new String_('true'), $switchCases);
      $switchNode->setAttribute('comments', $ifNode->getComments());
      return $switchNode;
    }

    private function processCondition($condition, $currentSwitchExpr)
    {
      if ($condition instanceof Equal || $condition instanceof Identical) {
        return [$currentSwitchExpr ?? $condition->left, $condition->right];
      } elseif ($condition instanceof BooleanAnd || $condition instanceof BooleanOr) {
        $leftExpr = $this->processCondition($condition->left, $currentSwitchExpr);
        $rightExpr = $this->processCondition($condition->right, $currentSwitchExpr);
        $combinedExpr = $condition instanceof BooleanAnd ? 'and' : 'or';
        return [
          $currentSwitchExpr ?? new String_('true'),
          new String_("({$this->conditionToString($leftExpr[1])}) $combinedExpr ({$this->conditionToString($rightExpr[1])})")
        ];
      } else {
        return [$currentSwitchExpr ?? new String_('true'), new String_($this->conditionToString($condition))];
      }
    }

    private function conditionToString($condition)
    {
      $prettyPrinter = new PrettyPrinter\Standard;
      return trim($prettyPrinter->prettyPrint([$condition]));
    }
  };

  $traverser->addVisitor($visitor);
  $modifiedAst = $traverser->traverse($ast);

  $prettyPrinter = new PrettyPrinter\Standard;
  return $prettyPrinter->prettyPrintFile($modifiedAst);
}



// Example usage
$code = <<<'CODE'
<?php
if ($x == 1 && $y > 0) {
    echo "One and positive";
} elseif ($x == 2 || $y < 0) {
    echo "Two or negative";
} elseif ($x >= 3 && $x <= 5) {
    echo "Between three and five";
} elseif ($x % 2 == 0) {
    echo "Even number";
} else {
    echo "Other cases";
}
CODE;

$result = convertIfToSwitch($code);
echo $result;
