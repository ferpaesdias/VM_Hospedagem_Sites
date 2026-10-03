#!/usr/bin/env python3
"""
Painel web da VM-Hospedagem — docentes e alunos.

Docentes: criam, removem e redefinem a senha de contas de aluno.
Alunos: alteram a própria senha e gerenciam os arquivos do site.

Este backend roda como o usuário "painel" e NÃO tem acesso direto a senhas
nem às pastas dos alunos. Tudo que exige root passa por:
  - gerenciar_usuarios_ftp  (criar/remover contas)
  - painel-helper           (conferir/trocar senha, arquivos do aluno)
ambos via sudo.
"""
import hmac
import json
import logging
import os
import pwd
import re
import subprocess
import threading
import time
from datetime import timedelta
from functools import wraps

from flask import Flask, abort, jsonify, request, send_from_directory, session

SCRIPT = os.environ.get("PAINEL_SCRIPT", "/usr/local/sbin/gerenciar_usuarios_ftp")
HELPER = os.environ.get("PAINEL_HELPER", "/usr/local/sbin/painel-helper")
TOKEN = os.environ.get("PAINEL_TOKEN", "")
SEGREDO = os.environ.get("PAINEL_SEGREDO", "")
DIR_TRABALHO = os.environ.get("PAINEL_DIR_TRABALHO", "/var/lib/painel")
RAIZ = "/projetos"
SHELL_FTP = "/bin/shell_ftp"
MAX_LOTE = 50
MAX_ARQUIVO = 20 * 1024 * 1024
# Senha de toda conta nova (e de toda senha redefinida). O aluno é obrigado
# a trocá-la no primeiro acesso ao painel.
SENHA_INICIAL = os.environ.get("PAINEL_SENHA_INICIAL", "123@mudar")

RE_TURMA = re.compile(r"^[a-zA-Z0-9]{1,32}$")
RE_LOGIN = re.compile(r"^[a-z][a-z0-9]{0,31}$")
DIR_STATIC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")

if not TOKEN or len(SEGREDO) < 32:
    raise SystemExit("Defina PAINEL_TOKEN e PAINEL_SEGREDO (32+ caracteres) em /etc/painel/painel.env")

app = Flask(__name__, static_folder=None)
app.secret_key = SEGREDO
app.config.update(
    MAX_CONTENT_LENGTH=MAX_ARQUIVO + 1024,
    SESSION_COOKIE_NAME="painel_sessao",
    SESSION_COOKIE_PATH="/_painel/",      # nunca é enviado aos sites dos alunos
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Strict",
    PERMANENT_SESSION_LIFETIME=timedelta(hours=8),
)
trava_script = threading.Lock()
trava_tentativas = threading.Lock()
tentativas = {}  # login -> [falhas, bloqueado_ate]

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
log = logging.getLogger("painel")


class ErroApi(Exception):
    def __init__(self, mensagem, status=400):
        super().__init__(mensagem)
        self.mensagem, self.status = mensagem, status


@app.errorhandler(ErroApi)
def tratar_erro(e):
    return jsonify(mensagem=e.mensagem), e.status


@app.errorhandler(413)
def grande_demais(_):
    return jsonify(mensagem="Arquivo grande demais (máximo 20 MB)."), 413


# ---------------------------------------------------------------------------
# Segurança das requisições
# ---------------------------------------------------------------------------
@app.before_request
def verificar_requisicao():
    # Só aceita requisições que passaram pelo Nginx (que injeta o token).
    if not hmac.compare_digest(request.headers.get("X-Painel-Token", ""), TOKEN):
        abort(403)
    # CSRF: alterações exigem um cabeçalho que outro site não consegue enviar.
    if request.method not in ("GET", "HEAD") and request.headers.get("X-Painel") != "1":
        abort(403)


def requer(papel, liberar_troca=False):
    def decorador(f):
        @wraps(f)
        def envoltorio(*args, **kwargs):
            if session.get("papel") != papel:
                raise ErroApi("Sua sessão expirou. Entre de novo.", 401)
            if session.get("trocar_senha") and not liberar_troca:
                raise ErroApi("Troque a senha inicial antes de continuar.", 409)
            return f(*args, **kwargs)
        return envoltorio
    return decorador


def ip():
    return request.headers.get("X-Real-IP", request.remote_addr)


def quem():
    return f"{session.get('papel', '?')}={session.get('login', '?')}"


# ---------------------------------------------------------------------------
# Chamadas privilegiadas
# ---------------------------------------------------------------------------
def helper(*args, entrada=b""):
    r = subprocess.run(["sudo", "-n", HELPER, *args], input=entrada,
                       capture_output=True, timeout=120, cwd=DIR_TRABALHO)
    if r.returncode == 0:
        return json.loads(r.stdout or b"{}")
    try:
        mensagem = json.loads(r.stderr).get("erro")
    except ValueError:
        mensagem = None
    if r.returncode != 1 or not mensagem:
        log.error("helper %s falhou (%s): %s", args[:2], r.returncode, r.stderr[-300:])
        raise ErroApi("Falha interna do painel. Avise o docente.", 500)
    raise ErroApi(mensagem, 400)


def executar_script(*args):
    with trava_script:
        # stdin vazio: o script nunca pede confirmação quando chamado pelo painel
        r = subprocess.run(["sudo", "-n", SCRIPT, *args], capture_output=True, stdin=subprocess.DEVNULL,
                           text=True, timeout=120, cwd=DIR_TRABALHO)
    if r.returncode != 0:
        log.warning("script %s saiu com %s: %s", args, r.returncode, (r.stderr or r.stdout).strip())
    return r


# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------
def bloqueado(login):
    with trava_tentativas:
        falhas, ate = tentativas.get(login, (0, 0))
        return ate > time.time()


def registrar_falha(login):
    with trava_tentativas:
        falhas, _ = tentativas.get(login, (0, 0))
        falhas += 1
        tentativas[login] = (0, time.time() + 300) if falhas >= 5 else (falhas, 0)


@app.post("/api/login")
def login():
    dados = request.get_json(silent=True) or {}
    login_ = str(dados.get("login", "")).strip().lower()
    senha = dados.get("senha", "")
    if not RE_LOGIN.match(login_) or not isinstance(senha, str) or not senha or len(senha) > 128 or "\n" in senha:
        raise ErroApi("Login ou senha incorretos.", 401)
    if bloqueado(login_):
        raise ErroApi("Muitas tentativas erradas. Aguarde 5 minutos.", 429)
    try:
        info = helper("auth", login_, entrada=senha.encode())
    except ErroApi as e:
        if e.status == 400:
            registrar_falha(login_)
            log.warning("login recusado: %s ip=%s", login_, ip())
            raise ErroApi("Login ou senha incorretos.", 401)
        raise
    with trava_tentativas:
        tentativas.pop(login_, None)
    session.clear()
    session.permanent = True
    session.update(login=login_, papel=info["papel"], turma=info.get("turma"),
                   trocar_senha=info["papel"] == "aluno" and senha == SENHA_INICIAL)
    log.info("login %s ip=%s", quem(), ip())
    return sessao()


@app.post("/api/logout")
def logout():
    log.info("logout %s", quem())
    session.clear()
    return jsonify(ok=True)


@app.get("/api/sessao")
def sessao():
    if "papel" not in session:
        raise ErroApi("Não autenticado.", 401)
    dados = {"login": session["login"], "papel": session["papel"], "turma": session.get("turma"),
             "trocar_senha": bool(session.get("trocar_senha"))}
    if session["papel"] == "docente":
        dados["senha_inicial"] = SENHA_INICIAL
    return jsonify(dados)


# ---------------------------------------------------------------------------
# Docente: contas de aluno
# ---------------------------------------------------------------------------
def validar(turma, aluno):
    if not isinstance(turma, str) or not RE_TURMA.match(turma):
        return "Turma inválida. Use só letras e números (até 32)."
    if not isinstance(aluno, str) or not RE_LOGIN.match(aluno):
        return "Login inválido. Use letras minúsculas e números, começando por letra (até 32)."
    return None


def conta(nome):
    try:
        return pwd.getpwnam(nome)
    except KeyError:
        return None


def turma_do_aluno(pw):
    if pw.pw_shell != SHELL_FTP:
        return None
    partes = pw.pw_dir.rstrip("/").split("/")
    if len(partes) != 4 or "/" + partes[1] != RAIZ or partes[3] != pw.pw_name:
        return None
    return partes[2]


def ultima_linha(r):
    texto = (r.stderr or "").strip() or (r.stdout or "").strip()
    return texto.splitlines()[-1] if texto else ""


def adicionar(turma, aluno):
    """Retorna (status, mensagem)."""
    erro = validar(turma, aluno)
    if erro:
        return "erro", erro
    pw = conta(aluno)
    if pw:
        t = turma_do_aluno(pw)
        if t == turma:
            return "ignorado", "A conta já existe nesta turma. Nada foi alterado."
        if t:
            return "erro", f"Esse login já existe na turma {t}."
        return "erro", "Já existe um usuário do sistema com esse login."
    r = executar_script("--add", turma, aluno)
    pw = conta(aluno)
    if pw is None or turma_do_aluno(pw) != turma:
        return "erro", ultima_linha(r) or "O script não concluiu a criação da conta."
    # Garante a senha inicial padrão, qualquer que seja a senha usada pelo script
    try:
        helper("redefinir", aluno, entrada=SENHA_INICIAL.encode())
    except ErroApi:
        return "criado", "Conta criada, mas a senha inicial não foi definida. Use Redefinir senha."
    return "criado", f"Conta criada. Senha inicial: {SENHA_INICIAL}"


def remover(turma, aluno):
    erro = validar(turma, aluno)
    if erro:
        return "erro", erro
    pw = conta(aluno)
    if pw is None:
        return "ignorado", "Conta não encontrada. Nada foi removido."
    t = turma_do_aluno(pw)
    if t is None:
        return "erro", "Esse login não é uma conta de aluno. Remoção bloqueada."
    if t != turma:
        return "erro", f"Esse aluno está na turma {t}, não em {turma}."
    r = executar_script("--rm", turma, aluno)
    if conta(aluno) is not None:
        return "erro", ultima_linha(r) or "O script não concluiu a remoção."
    return "removido", "Conta e arquivos do site removidos."


@app.get("/api/alunos")
@requer("docente")
def listar():
    turmas = {}
    for pw in pwd.getpwall():
        t = turma_do_aluno(pw)
        if t:
            turmas.setdefault(t, []).append({"aluno": pw.pw_name, "pasta_ok": os.path.isdir(pw.pw_dir)})
    lista = [{"turma": t, "alunos": sorted(a, key=lambda x: x["aluno"])} for t, a in sorted(turmas.items())]
    return jsonify(turmas=lista)


@app.post("/api/alunos")
@requer("docente")
def criar_um():
    d = request.get_json(silent=True) or {}
    turma, aluno = d.get("turma"), d.get("aluno")
    status, mensagem = adicionar(turma, aluno)
    log.info("%s add %s/%s -> %s", quem(), turma, aluno, status)
    return jsonify(status=status, mensagem=mensagem), 201 if status == "criado" else 200 if status == "ignorado" else 409


@app.delete("/api/alunos/<turma>/<aluno>")
@requer("docente")
def remover_um(turma, aluno):
    status, mensagem = remover(turma, aluno)
    log.info("%s rm %s/%s -> %s", quem(), turma, aluno, status)
    return jsonify(status=status, mensagem=mensagem), 409 if status == "erro" else 200


@app.post("/api/alunos/<turma>/<aluno>/senha")
@requer("docente")
def redefinir_senha(turma, aluno):
    pw = conta(aluno)
    if validar(turma, aluno) or pw is None or turma_do_aluno(pw) != turma:
        raise ErroApi("Aluno não encontrado nesta turma.", 404)
    helper("redefinir", aluno, entrada=SENHA_INICIAL.encode())
    log.info("%s redefiniu senha de %s/%s", quem(), turma, aluno)
    return jsonify(mensagem=f"Senha de {aluno} redefinida para {SENHA_INICIAL}. O aluno deverá trocá-la no próximo acesso.")


@app.post("/api/lote")
@requer("docente")
def lote():
    d = request.get_json(silent=True) or {}
    acao, linhas = d.get("acao"), d.get("linhas")
    if acao not in ("add", "rm") or not isinstance(linhas, list):
        raise ErroApi("Requisição inválida.")
    if len(linhas) > MAX_LOTE:
        raise ErroApi(f"Envie no máximo {MAX_LOTE} linhas por vez.", 413)
    resultados = []
    for linha in linhas:
        linha = linha if isinstance(linha, dict) else {}
        turma, aluno = linha.get("turma"), linha.get("aluno")
        status, mensagem = adicionar(turma, aluno) if acao == "add" else remover(turma, aluno)
        log.info("%s %s-lote %s/%s -> %s", quem(), acao, turma, aluno, status)
        resultados.append({"turma": turma, "aluno": aluno, "status": status, "mensagem": mensagem})
    return jsonify(resultados=resultados)


# ---------------------------------------------------------------------------
# Aluno: senha e arquivos
# ---------------------------------------------------------------------------
@app.post("/api/senha")
@requer("aluno", liberar_troca=True)
def trocar_senha():
    d = request.get_json(silent=True) or {}
    nova = d.get("nova", "")
    # No primeiro acesso o aluno acabou de entrar com a senha inicial:
    # não é preciso digitá-la de novo.
    primeiro_acesso = bool(session.get("trocar_senha"))
    atual = SENHA_INICIAL if primeiro_acesso else d.get("atual", "")
    if not all(isinstance(x, str) and x and "\n" not in x and len(x) <= 128 for x in (atual, nova)):
        raise ErroApi("Preencha a senha atual e a nova senha.")
    if nova == SENHA_INICIAL:
        raise ErroApi("Escolha uma senha diferente da senha inicial.")
    helper("senha", session["login"], entrada=f"{atual}\n{nova}\n".encode())
    session["trocar_senha"] = False
    log.info("%s %s", quem(), "criou a senha no primeiro acesso" if primeiro_acesso else "alterou a própria senha")
    return jsonify(ok=True)


def caminho_param():
    c = request.args.get("caminho", "")
    if len(c) > 1024:
        raise ErroApi("Caminho longo demais.")
    return c


@app.get("/api/arquivos")
@requer("aluno")
def arquivos_listar():
    return jsonify(helper("ls", session["login"], caminho_param()))


@app.put("/api/arquivos")
@requer("aluno")
def arquivos_enviar():
    caminho = caminho_param()
    dados = request.get_data(cache=False)
    r = helper("put", session["login"], caminho, entrada=dados)
    log.info("%s enviou %s (%s bytes)", quem(), caminho, r.get("tamanho"))
    return jsonify(r)


@app.delete("/api/arquivos")
@requer("aluno")
def arquivos_apagar():
    caminho = caminho_param()
    helper("rm", session["login"], caminho)
    log.info("%s apagou %s", quem(), caminho)
    return jsonify(ok=True)


@app.post("/api/uploads/esvaziar")
@requer("aluno")
def esvaziar_uploads():
    r = helper("esvaziar", session["login"])
    log.info("%s esvaziou uploads/ (%s removidos, %s falhas)", quem(), r.get("removidos"), len(r.get("falhas", [])))
    return jsonify(r)


@app.post("/api/pastas")
@requer("aluno")
def pasta_criar():
    caminho = str((request.get_json(silent=True) or {}).get("caminho", ""))
    helper("mkdir", session["login"], caminho)
    return jsonify(ok=True)


@app.get("/")
def pagina():
    return send_from_directory(DIR_STATIC, "index.html")


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8001, debug=False)
