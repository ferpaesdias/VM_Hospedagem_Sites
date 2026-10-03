<?php if (!defined('APP')) { http_response_code(403); exit; } ?>
</main>
<footer class="rodape">
  <p>Publicado por <strong><?= h(turma_aluno()[1]) ?></strong> em <code><?= h(caminho_site()) ?></code>
  <?php $total = $visitas ?? total_visitas(); if ($total !== null): ?> — <strong><?= (int) $total ?></strong> visita(s) à página inicial<?php endif; ?></p>
</footer>
<script src="assets/festa.js"></script>
</body>
</html>
