/* Confete na página inicial e contador de caracteres no mural. */
(function () {
  "use strict";

  /* ---------- Confete ---------- */
  var canvas = document.getElementById("confete");
  var hero = document.querySelector(".hero");
  var semMovimento = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function soltarConfete(quantidade) {
    if (!canvas || semMovimento) return;
    var ctx = canvas.getContext("2d");
    var cores = ["#F7941D", "#FFCE00", "#22A861", "#3FA9F5", "#FFFFFF"];
    var escala = window.devicePixelRatio || 1;
    var largura = canvas.clientWidth, altura = canvas.clientHeight;
    canvas.width = largura * escala; canvas.height = altura * escala;
    ctx.setTransform(escala, 0, 0, escala, 0, 0);

    var pedacos = [];
    for (var i = 0; i < quantidade; i++) {
      pedacos.push({
        x: largura / 2 + (Math.random() - 0.5) * largura * 0.3,
        y: altura * 0.55,
        vx: (Math.random() - 0.5) * 14,
        vy: -(Math.random() * 13 + 6),
        giro: Math.random() * Math.PI,
        vgiro: (Math.random() - 0.5) * 0.3,
        tam: Math.random() * 7 + 5,
        cor: cores[i % cores.length],
        redondo: Math.random() < 0.3
      });
    }
    var inicio = performance.now();
    function quadro(agora) {
      var t = agora - inicio;
      ctx.clearRect(0, 0, largura, altura);
      pedacos.forEach(function (p) {
        p.vy += 0.32; p.vx *= 0.99; p.x += p.vx; p.y += p.vy; p.giro += p.vgiro;
        ctx.save();
        ctx.globalAlpha = Math.max(0, 1 - t / 3500);
        ctx.translate(p.x, p.y); ctx.rotate(p.giro); ctx.fillStyle = p.cor;
        if (p.redondo) { ctx.beginPath(); ctx.arc(0, 0, p.tam / 2, 0, Math.PI * 2); ctx.fill(); }
        else ctx.fillRect(-p.tam / 2, -p.tam / 4, p.tam, p.tam / 2);
        ctx.restore();
      });
      if (t < 3500) requestAnimationFrame(quadro);
      else ctx.clearRect(0, 0, largura, altura);
    }
    requestAnimationFrame(quadro);
  }

  if (hero && hero.dataset.confete === "sim") {
    setTimeout(function () { soltarConfete(160); }, 300);
    var titulo = hero.querySelector("h1");
    if (titulo) {
      titulo.title = "Clique para mais confete";
      titulo.addEventListener("click", function () { soltarConfete(120); });
    }
  }

  /* ---------- Contador de caracteres do mural ---------- */
  var texto = document.getElementById("texto");
  var contador = document.getElementById("contador-texto");
  if (texto && contador) {
    var atualizar = function () {
      var resta = texto.maxLength - texto.value.length;
      contador.textContent = resta + (resta === 1 ? " caractere restante" : " caracteres restantes");
      contador.classList.toggle("pouco", resta <= 20);
    };
    texto.addEventListener("input", atualizar);
    atualizar();
  }
})();
