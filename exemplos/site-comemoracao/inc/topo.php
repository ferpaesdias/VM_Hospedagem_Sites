<?php
if (!defined('APP')) { http_response_code(403); exit; }
/** @var string $titulo  @var string $pagina */
[$turma, $aluno] = turma_aluno();
$menu = ['index.php' => 'Início', 'mural.php' => 'Mural de recados', 'sobre.php' => 'Como funciona'];
?>
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= h($titulo) ?> — <?= h($aluno) ?></title>
<link rel="stylesheet" href="assets/estilo.css">
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🎉</text></svg>">
</head>
<body>
<header class="topo">
  <div class="topo-dentro">
    <a class="endereco" href="index.php"><span class="seg"><?= h($turma) ?></span>/<span class="seg aluno"><?= h($aluno) ?></span>/</a>
    <nav aria-label="Páginas">
      <?php foreach ($menu as $arquivo => $rotulo): ?>
        <a href="<?= h($arquivo) ?>"<?= $arquivo === $pagina ? ' aria-current="page"' : '' ?>><?= h($rotulo) ?></a>
      <?php endforeach; ?>
    </nav>
  </div>
</header>
<main>
