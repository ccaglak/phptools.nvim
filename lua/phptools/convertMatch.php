<?php

require_once __DIR__ . '/parser/vendor/autoload.php';

use PhpParser\Error;
use PhpParser\ParserFactory;
use PhpParser\Node\Stmt\If_;
use PhpParser\Node\Expr\BinaryOp\Equal;
use PhpParser\PrettyPrinter;
use PhpParser\Node;

function convertIfToMatch($code)
{
  $parser = (new ParserFactory)->createForNewestSupportedVersion();

  try {
    $ast = $parser->parse($code);
  } catch (Error $error) {
    echo "Parse error: {$error->getMessage()}\n";
    return;
  }

  $nodeFinder = new PhpParser\NodeFinder;
  $ifNodes = $nodeFinder->findInstanceOf($ast, If_::class);

  if (empty($ifNodes)) {
    echo "No if statement found\n";
    return;
  }

  $ifNode = $ifNodes[0];
  $arms = [];

  // Process the main if condition
  $arms[] = createMatchArm($ifNode->cond, $ifNode->stmts);

  // Process all elseif conditions
  foreach ($ifNode->elseifs as $elseif) {
    $arms[] = createMatchArm($elseif->cond, $elseif->stmts);
  }

  // Process the else condition
  if ($ifNode->else) {
    $arms[] = new Node\MatchArm(
      null,
      new Node\Expr\FuncCall(
        new Node\Name('echo'),
        $ifNode->else->stmts[0]->exprs
      )
    );
  }

  $matchNode = new Node\Expr\Match_(
    new Node\Expr\Variable('x'),
    $arms
  );

  $prettyPrinter = new PrettyPrinter\Standard;
  return $prettyPrinter->prettyPrint([new Node\Stmt\Expression($matchNode)]);
}

function createMatchArm($condition, $stmts)
{
  return new Node\MatchArm(
    [$condition],
    new Node\Expr\FuncCall(
      new Node\Name('echo'),
      $stmts[0]->exprs
    )
  );
}



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

$result = convertIfToMatch($code);
echo $result;
