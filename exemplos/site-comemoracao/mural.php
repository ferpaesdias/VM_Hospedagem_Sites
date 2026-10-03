<?php
require __DIR__ . '/inc/inicio.php';

$titulo = 'Mural de recados';
$pagina = 'mural.php';
$erro = '';
$nome = '';
$texto = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $nome = trim((string) ($_POST['nome'] ?? ''));
    $texto = trim((string) ($_POST['texto'] ?? ''));

    if (!csrf_valido($_POST['csrf'] ?? null)) {
        $erro = 'O formulário expirou. Tente enviar de novo.';
    } elseif (($_POST['site'] ?? '') !== '') {
        $erro = 'Envio recusado.'; // campo escondido preenchido: provavelmente um robô
    } elseif ($nome === '' || $texto === '') {
        $erro = 'Preencha o seu nome e o recado.';
    } elseif (comprimento($nome) < 0 || comprimento($texto) < 0) {
        $erro = 'O texto tem caracteres inválidos.';
    } elseif (comprimento($nome) > 40 || comprimento($texto) > 280) {
        $erro = 'O nome pode ter até 40 caracteres e o recado até 280.';
    } elseif (!pasta_dados_ok()) {
        $erro = 'A pasta uploads/ não existe ou não tem permissão de escrita.';
    } else {
        $salvo = alterar_json('mural.json', [], function (array $lista) use ($nome, $texto) {
            $lista[] = ['nome' => $nome, 'texto' => $texto, 'quando' => date('c')];
            return array_slice($lista, -MAX_RECADOS);
        });
        if ($salvo === null) {
            $erro = 'Não foi possível gravar o recado.';
        } else {
            $_SESSION['aviso'] = 'Recado publicado. Ele foi gravado em uploads/mural.json.';
            header('Location: mural.php', true, 303); // evita reenviar ao recarregar
            exit;
        }
    }
}

$aviso = $_SESSION['aviso'] ?? '';
unset($_SESSION['aviso']);
$recados = array_reverse(ler_json('mural.json', []));

require __DIR__ . '/inc/topo.php';
?>
<section class="pagina">
  <h1>Mural de recados</h1>
  <p class="sub">Deixe um recado para comemorar. Cada mensagem é gravada pelo PHP em <code>uploads/mural.json</code>, a única pasta onde o site pode escrever.</p>

  <?php if (!pasta_dados_ok()): ?>
    <p class="aviso erro">A pasta <code>uploads/</code> não foi encontrada ou não tem permissão de escrita, então o mural não consegue salvar recados.</p>
  <?php endif; ?>
  <?php if ($aviso !== ''): ?><p class="aviso ok" role="status"><?= h($aviso) ?></p><?php endif; ?>
  <?php if ($erro !== ''): ?><p class="aviso erro" role="alert"><?= h($erro) ?></p><?php endif; ?>

  <form class="formulario" method="post" action="mural.php">
    <input type="hidden" name="csrf" value="<?= h(token_csrf()) ?>">
    <div class="isca" aria-hidden="true"><label>Não preencha <input type="text" name="site" tabindex="-1" autocomplete="off"></label></div>
    <label for="nome">Seu nome</label>
    <input type="text" id="nome" name="nome" maxlength="40" required value="<?= h($nome) ?>">
    <label for="texto">Recado</label>
    <textarea id="texto" name="texto" maxlength="280" rows="3" required><?= h($texto) ?></textarea>
    <div class="linha-envio">
      <small id="contador-texto" aria-live="polite">280 caracteres restantes</small>
      <button class="botao principal" type="submit">Publicar recado</button>
    </div>
  </form>

  <h2><?= count($recados) ?> recado(s)</h2>
  <?php if (!$recados): ?>
    <p class="vazio">Ninguém escreveu ainda. Seja o primeiro!</p>
  <?php else: ?>
    <ul class="recados">
      <?php foreach ($recados as $i => $r): ?>
        <li style="--cor: <?= $i % 4 ?>">
          <p><?= nl2br(h($r['texto'] ?? '')) ?></p>
          <footer><strong><?= h($r['nome'] ?? '') ?></strong>
            <time datetime="<?= h($r['quando'] ?? '') ?>"><?= h(isset($r['quando']) ? date('d/m/Y H:i', strtotime($r['quando'])) : '') ?></time></footer>
        </li>
      <?php endforeach; ?>
    </ul>
  <?php endif; ?>
</section>
<?php require __DIR__ . '/inc/rodape.php'; ?>
