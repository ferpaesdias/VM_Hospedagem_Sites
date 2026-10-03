<?php
require __DIR__ . '/inc/inicio.php';

$titulo = 'Como este servidor funciona';
$pagina = 'sobre.php';
[$turma, $aluno] = turma_aluno();

$etapas = [
    ['Sistema operacional', 'Um disco dedicado foi formatado e montado em <code>/projetos</code>. Ali ficam os sites de todas as turmas.'],
    ['Nginx', 'O servidor web entrega os arquivos de <code>/projetos</code>. Cada aluno ganha um endereço no formato <code>/turma/aluno/</code>.'],
    ['FTP', 'O vsftpd deixa cada aluno enviar arquivos, preso dentro da própria pasta (chroot).'],
    ['PHP', 'O PHP-FPM executa os arquivos <code>.php</code>. O <code>open_basedir</code> impede que o PHP de um aluno leia a pasta de outro.'],
    ['Painel web', 'Docentes criam as contas pelo navegador, e os alunos trocam a senha e enviam arquivos sem precisar de um programa de FTP.'],
];
require __DIR__ . '/inc/topo.php';
?>
<section class="pagina">
  <h1>Como este servidor funciona</h1>
  <p class="sub">O caminho que esta página percorreu até chegar à sua tela.</p>

  <ol class="fluxo" aria-label="Caminho de uma requisição">
    <li><strong>Seu navegador</strong><small>pede <code><?= h(caminho_site()) ?></code></small></li>
    <li><strong>Nginx</strong><small>encontra a pasta do aluno</small></li>
    <li><strong>PHP-FPM</strong><small>executa <code>index.php</code></small></li>
    <li><strong>Pasta do aluno</strong><small><code>/projetos/<?= h($turma) ?>/<?= h($aluno) ?>/</code></small></li>
  </ol>

  <h2>As etapas da configuração</h2>
  <ol class="linha-do-tempo">
    <?php foreach ($etapas as $n => [$nome, $descricao]): ?>
      <li>
        <span class="numero" aria-hidden="true"><?= $n + 1 ?></span>
        <div><strong><?= h($nome) ?></strong><p><?= $descricao ?></p></div>
      </li>
    <?php endforeach; ?>
  </ol>

  <h2>Os arquivos deste site</h2>
  <p>Esta página foi dividida em vários arquivos, como em um projeto de verdade:</p>
  <pre class="arvore"><?= h($aluno) ?>/
├── index.php        página inicial e checagens
├── mural.php        mural de recados
├── sobre.php        esta página
├── inc/
│   ├── inicio.php   sessão, funções e checagens
│   ├── topo.php     cabeçalho e menu
│   └── rodape.php   rodapé
├── assets/
│   ├── estilo.css   aparência
│   └── festa.js     confete e contador de caracteres
└── uploads/         onde o PHP grava os recados</pre>
</section>
<?php require __DIR__ . '/inc/rodape.php'; ?>
