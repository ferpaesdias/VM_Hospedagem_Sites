<?php
require __DIR__ . '/inc/inicio.php';

$titulo = 'Deu certo!';
$pagina = 'index.php';
$visitas = registrar_visita();
$itens = checagens();
$todos_ok = !in_array(false, array_column($itens, 0), true);
$recados = count(ler_json('mural.json', []));

require __DIR__ . '/inc/topo.php';
?>
<section class="hero" data-confete="<?= $todos_ok ? 'sim' : 'nao' ?>">
  <canvas id="confete" aria-hidden="true"></canvas>
  <p class="chapeu">Servidor de hospedagem dos alunos</p>
  <h1><?= $todos_ok ? 'Deu certo!' : 'Quase lá!' ?></h1>
  <p class="sub">
    <?php if ($todos_ok): ?>
      Esta página foi enviada pela conta de um aluno, entregue pelo Nginx e montada agora mesmo pelo PHP.
      Cada etapa da configuração está funcionando.
    <?php else: ?>
      A página chegou até você, mas alguma etapa ainda precisa de ajuste. Veja abaixo o que falta.
    <?php endif; ?>
  </p>
  <div class="acoes">
    <a class="botao principal" href="mural.php">Deixe um recado</a>
    <a class="botao" href="sobre.php">Como este servidor funciona</a>
  </div>
</section>

<section class="painel-checagens" aria-labelledby="t-checagens">
  <div class="cabecalho-terminal" aria-hidden="true"><span></span><span></span><span></span><code>checagem ao vivo</code></div>
  <h2 id="t-checagens" class="oculto">Checagem da configuração</h2>
  <ul class="checagens">
    <?php foreach ($itens as $i => [$ok, $rotulo, $detalhe]): ?>
      <li class="<?= $ok === true ? 'ok' : ($ok === false ? 'falha' : 'neutro') ?>" style="--i: <?= $i ?>">
        <span class="marca" aria-hidden="true"><?= $ok === true ? '✓' : ($ok === false ? '✗' : '–') ?></span>
        <span class="texto">
          <strong><?= h($rotulo) ?></strong>
          <span class="oculto"><?= $ok === true ? '(funcionando)' : ($ok === false ? '(com problema)' : '(não verificado)') ?></span>
          <small><?= h($detalhe) ?></small>
        </span>
      </li>
    <?php endforeach; ?>
  </ul>
  <p class="dica-recarregar">Recarregue a página: o número de visitas sobe (gravado em <code>uploads/contador.json</code>) e o contador da sessão também.</p>
</section>

<section class="numeros" aria-label="Números">
  <div<?= $visitas === null ? ' title="A pasta uploads não aceita gravação"' : '' ?>><strong><?= $visitas ?? '–' ?></strong><span>visitas à página inicial</span></div>
  <div><strong><?= (int) $recados ?></strong><span>recados no mural</span></div>
  <div><strong><?= count(array_filter(array_column($itens, 0), fn ($ok) => $ok === true)) ?>/<?= count($itens) ?></strong><span>checagens aprovadas</span></div>
</section>
<?php require __DIR__ . '/inc/rodape.php'; ?>
