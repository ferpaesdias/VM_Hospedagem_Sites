#!/bin/bash
###############################################################################
#
#   gerenciar_usuarios_ftp.sh — cria e remove contas de aluno
#
#   Cada aluno tem uma conta Linux, usada no FTP e no painel web.
#   O HOME do aluno, /projetos/<turma>/<login>/, é também a raiz do site,
#   publicada pelo Nginx em http://[IP]/<turma>/<login>/.
#
#   USO (como root)
#     gerenciar_usuarios_ftp.sh --add     <turma> <login>
#     gerenciar_usuarios_ftp.sh --rm      <turma> <login>
#     gerenciar_usuarios_ftp.sh --add-csv <arquivo.csv>
#     gerenciar_usuarios_ftp.sh --rm-csv  <arquivo.csv>
#     gerenciar_usuarios_ftp.sh --help
#
#   LOGIN
#     Parte do e-mail antes do @, sem o ponto:
#     fulano.dsilva@escola.edu.br  ->  fulanodsilva
#
#   CSV
#     Um aluno por linha, no formato turma,login (aceita ponto e vírgula).
#     Linhas vazias, comentários (#) e a linha de cabeçalho são ignorados.
#
#   SENHA
#     Toda conta nova recebe a senha inicial SENHA_INICIAL. O painel web
#     obriga o aluno a trocá-la no primeiro acesso.
#
#   ATENÇÃO
#     Remover um aluno apaga a conta e TODOS os arquivos do site, sem volta.
#     Se for o último aluno da turma, a pasta da turma também é removida.
#
###############################################################################

set -o nounset -o pipefail

readonly RAIZ="/projetos"
readonly SHELL_FTP="/bin/shell_ftp"
readonly SENHA_INICIAL="123@mudar"
readonly ARQUIVO_LOG="/var/log/vm_hospedagem.log"
readonly RE_TURMA='^[A-Za-z0-9]{1,32}$'
readonly RE_LOGIN='^[a-z][a-z0-9]{0,31}$'

#### ------------------------------------------------------------------------
#### Mensagens: vão para a tela e para o arquivo de log
#### ------------------------------------------------------------------------
function log() {
  local nivel=$1
  shift
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$nivel" "$*" >> "$ARQUIVO_LOG"
  if [[ $nivel == "ERRO" ]]; then
    echo "ERRO: $*" >&2
  else
    echo "$*"
  fi
}

function falhar() {
  log ERRO "$@"
  exit 1
}

#### ------------------------------------------------------------------------
#### Preparação
#### ------------------------------------------------------------------------
function checar_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "ERRO: execute como root (sudo)." >&2
    exit 1
  fi
}

function preparar_log() {
  touch "$ARQUIVO_LOG"
  chown root:adm "$ARQUIVO_LOG"
  chmod 640 "$ARQUIVO_LOG"
}

# Shell das contas de aluno: impede login por SSH/console, mas é aceito
# pelo vsftpd porque está listado em /etc/shells.
function garantir_shell_ftp() {
  if [[ ! -x $SHELL_FTP ]]; then
    printf '#!/bin/sh\necho "Esta conta é apenas para envio de arquivos (FTP)."\nsleep 3\n' > "$SHELL_FTP"
    chmod 755 "$SHELL_FTP"
  fi
  grep --quiet --line-regexp "$SHELL_FTP" /etc/shells || echo "$SHELL_FTP" >> /etc/shells
}

#### ------------------------------------------------------------------------
#### Validações
#### ------------------------------------------------------------------------
function validar() {
  local turma=$1 login=$2
  if [[ ! $turma =~ $RE_TURMA ]]; then
    log ERRO "Turma inválida: \"$turma\". Use só letras e números (até 32)."
    return 1
  fi
  if [[ ! $login =~ $RE_LOGIN ]]; then
    log ERRO "Login inválido: \"$login\". Use letras minúsculas e números, começando por letra (até 32)."
    return 1
  fi
}

# Verdadeiro se a conta segue o padrão de aluno DESTA turma
function eh_aluno_da_turma() {
  local turma=$1 login=$2 home shell
  home=$(getent passwd "$login" | cut -d: -f6)
  shell=$(getent passwd "$login" | cut -d: -f7)
  [[ $home == "$RAIZ/$turma/$login" && $shell == "$SHELL_FTP" ]]
}

# Pede confirmação só quando há alguém no terminal.
# Chamadas sem terminal (como as do painel web) seguem direto.
function confirmar() {
  local resposta
  [[ -t 0 ]] || return 0
  read -r -p "$1 [s/N] " resposta
  [[ $resposta =~ ^[sS]$ ]]
}

#### ------------------------------------------------------------------------
#### Criar e remover
#### ------------------------------------------------------------------------
function criar_aluno() {
  local turma=$1 login=$2
  local home="$RAIZ/$turma/$login"

  validar "$turma" "$login" || return 1

  if id "$login" &> /dev/null; then
    if eh_aluno_da_turma "$turma" "$login"; then
      log INFO "$turma/$login: a conta já existe. Nada foi alterado."
      return 0
    fi
    log ERRO "$turma/$login: já existe um usuário \"$login\" fora deste padrão (outra turma, docente ou sistema)."
    return 1
  fi

  if [[ -e $home ]]; then
    log ERRO "$turma/$login: a pasta $home já existe sem conta. Verifique e remova-a antes."
    return 1
  fi

  # Pasta da turma: o aluno atravessa (x), mas não lista as pastas dos colegas
  mkdir -p "$RAIZ/$turma"
  chown root:www-data "$RAIZ/$turma"
  chmod 751 "$RAIZ/$turma"

  if ! useradd --no-create-home --home-dir "$home" --shell "$SHELL_FTP" "$login"; then
    log ERRO "$turma/$login: o useradd falhou."
    return 1
  fi
  echo "$login:$SENHA_INICIAL" | chpasswd

  # Raiz do site: o Nginx (grupo www-data) só lê; o setgid faz os arquivos
  # novos herdarem o grupo www-data
  mkdir "$home"
  chown "$login":www-data "$home"
  chmod 2750 "$home"

  # Única pasta onde o PHP do site pode gravar
  mkdir "$home/uploads"
  chown "$login":www-data "$home/uploads"
  chmod 2770 "$home/uploads"

  log INFO "$turma/$login: conta criada. Senha inicial: $SENHA_INICIAL"
}

function remover_aluno() {
  local turma=$1 login=$2
  local home="$RAIZ/$turma/$login"
  local saida

  validar "$turma" "$login" || return 1

  if ! id "$login" &> /dev/null; then
    log ERRO "$turma/$login: a conta não existe."
    return 1
  fi
  if ! eh_aluno_da_turma "$turma" "$login"; then
    log ERRO "$turma/$login: não é uma conta de aluno desta turma. Remoção bloqueada."
    return 1
  fi

  # Encerra sessões FTP abertas; sem isso o deluser recusa a remoção
  pkill -KILL -u "$login" 2> /dev/null

  if ! saida=$(deluser --remove-home "$login" 2>&1); then
    log ERRO "$turma/$login: o deluser falhou: $saida"
    return 1
  fi
  # Garante que a pasta sumiu, mesmo com arquivos de outro dono (www-data)
  [[ -d $home ]] && rm -rf -- "$home"

  # Remove a pasta da turma se ela ficou vazia
  rmdir "$RAIZ/$turma" 2> /dev/null

  log INFO "$turma/$login: conta e arquivos removidos."
}

#### ------------------------------------------------------------------------
#### CSV
#### ------------------------------------------------------------------------
function aparar() {
  local texto=$1
  texto="${texto#"${texto%%[![:space:]]*}"}"
  texto="${texto%"${texto##*[![:space:]]}"}"
  printf '%s' "$texto"
}

function processar_csv() {
  local acao=$1 arquivo=$2
  local linha turma login resto num=0 primeira=1 ok=0 erros=0
  local funcao="criar_aluno"
  [[ $acao == "rm" ]] && funcao="remover_aluno"

  [[ -r $arquivo ]] || falhar "Não foi possível ler o arquivo \"$arquivo\"."

  if [[ $acao == "rm" ]]; then
    confirmar "Remover TODAS as contas listadas em $arquivo, com os sites?" || { echo "Cancelado."; return 1; }
  fi

  while IFS= read -r linha || [[ -n $linha ]]; do
    num=$((num + 1))
    linha=$(aparar "$linha")
    [[ -z $linha || $linha == \#* ]] && continue

    IFS=',;' read -r turma login resto <<< "$linha"
    turma=$(aparar "${turma:-}")
    login=$(aparar "${login:-}")
    login=${login,,}

    if (( primeira )); then
      primeira=0
      [[ ${turma,,} == "turma" ]] && continue   # cabeçalho
    fi

    if [[ -n ${resto:-} || -z $login ]]; then
      log ERRO "Linha $num: esperado turma,login."
      erros=$((erros + 1))
      continue
    fi

    if "$funcao" "$turma" "$login"; then
      ok=$((ok + 1))
    else
      erros=$((erros + 1))
    fi
  done < <(sed -e '1s/^\xEF\xBB\xBF//' -e 's/\r$//' "$arquivo")   # remove o BOM do Excel e o fim de linha do Windows

  log INFO "CSV $arquivo ($acao): $ok linha(s) processada(s), $erros com erro."
  (( erros == 0 ))
}

#### ------------------------------------------------------------------------
#### Ajuda e ponto de entrada
#### ------------------------------------------------------------------------
function exibir_ajuda() {
  cat << AJUDA
Uso:
  $(basename "$0") --add     <turma> <login>   Cria a conta de um aluno
  $(basename "$0") --rm      <turma> <login>   Remove a conta e o site do aluno
  $(basename "$0") --add-csv <arquivo.csv>     Cria as contas listadas no CSV
  $(basename "$0") --rm-csv  <arquivo.csv>     Remove as contas listadas no CSV
  $(basename "$0") --help                      Mostra esta ajuda

CSV: um aluno por linha, no formato turma,login
Log: $ARQUIVO_LOG
AJUDA
}

function main() {
  local opcao=${1:-}

  case $opcao in
    -h|--help)
      exibir_ajuda
      exit 0
      ;;
    --add|--rm)
      [[ $# -eq 3 ]] || { exibir_ajuda >&2; exit 1; }
      ;;
    --add-csv|--rm-csv)
      [[ $# -eq 2 ]] || { exibir_ajuda >&2; exit 1; }
      ;;
    *)
      exibir_ajuda >&2
      exit 1
      ;;
  esac

  checar_root
  preparar_log

  case $opcao in
    --add)
      garantir_shell_ftp
      criar_aluno "$2" "$3"
      ;;
    --rm)
      confirmar "Remover a conta $2/$3 e TODOS os arquivos do site?" || { echo "Cancelado."; exit 1; }
      remover_aluno "$2" "$3"
      ;;
    --add-csv)
      garantir_shell_ftp
      processar_csv add "$2"
      ;;
    --rm-csv)
      processar_csv rm "$2"
      ;;
  esac
}

main "$@"
