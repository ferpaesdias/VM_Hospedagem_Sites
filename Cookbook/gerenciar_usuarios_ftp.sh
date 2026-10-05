#!/bin/bash
###############################################################################
#
#   gerenciar_usuarios_ftp.sh — cria e remove contas de aluno
#
#   Cada aluno tem uma conta Linux, usada no FTP e no painel web.
#   O HOME do aluno, /projetos/<turma>/<login>/, é também a raiz do site,
#   publicada pelo Nginx em http://[IP]/<turma>/<login>/.
#
#   Se o MariaDB estiver instalado, cada aluno também recebe um banco de dados
#   e um usuário do banco, ambos com o nome do login. O usuário só enxerga o
#   próprio banco, que é gerenciado pelo phpMyAdmin.
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
#     O usuário do banco também nasce com SENHA_INICIAL, mas é independente da
#     conta Linux: o aluno a troca pelo phpMyAdmin.
#
#   ATENÇÃO
#     Remover um aluno apaga a conta, TODOS os arquivos do site e o banco de
#     dados, sem volta. Se for o último aluno da turma, a pasta da turma
#     também é removida.
#
###############################################################################

set -o nounset -o pipefail

readonly RAIZ="/projetos"
readonly SHELL_FTP="/bin/shell_ftp"
readonly SENHA_INICIAL="123@mudar"
readonly ARQUIVO_LOG="/var/log/vm_hospedagem.log"
readonly RE_TURMA='^[A-Za-z0-9]{1,32}$'
readonly RE_LOGIN='^[a-z][a-z0-9]{0,31}$'
# Nomes que o MariaDB já usa: um aluno com esse login receberia acesso ao banco do sistema
readonly RE_BANCO_RESERVADO='^(mysql|sys|test|root|mariadb)$'

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
#### Banco de dados (MariaDB)
#### O login já foi validado por RE_LOGIN (só letras minúsculas e números),
#### então pode ser usado direto nos comandos SQL.
#### ------------------------------------------------------------------------
function mariadb_instalado() {
  command -v mariadb &> /dev/null
}

# Retorna a quantidade (0 ou 1) de usuários do banco com o nome do login
function usuario_do_banco() {
  mariadb --batch --skip-column-names --execute \
    "SELECT COUNT(*) FROM mysql.user WHERE User='$1' AND Host='localhost'"
}

# Cria o banco e o usuário do aluno. Pode ser executada várias vezes: o que já
# existe não é alterado, nem a senha do usuário do banco.
function criar_banco() {
  local turma=$1 login=$2
  local existe_usuario existe_banco

  mariadb_instalado || return 0   # sem MariaDB, a conta é criada sem banco

  if [[ $login =~ $RE_BANCO_RESERVADO ]]; then
    log ERRO "$turma/$login: o nome \"$login\" é reservado pelo MariaDB. O banco não foi criado."
    return 1
  fi

  existe_usuario=$(usuario_do_banco "$login") \
    || { log ERRO "$turma/$login: não foi possível acessar o MariaDB. O banco não foi criado."; return 1; }
  existe_banco=$(mariadb --batch --skip-column-names --execute \
    "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$login'")

  # Um banco com esse nome que não é do aluno não pode ser entregue a ele
  if [[ $existe_banco == 1 && $existe_usuario == 0 ]]; then
    log ERRO "$turma/$login: já existe um banco \"$login\" sem usuário de aluno. O banco não foi criado."
    return 1
  fi

  if ! mariadb --execute "
    CREATE DATABASE IF NOT EXISTS \`$login\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS '$login'@'localhost' IDENTIFIED BY '$SENHA_INICIAL' WITH MAX_USER_CONNECTIONS 5;
    GRANT ALL PRIVILEGES ON \`$login\`.* TO '$login'@'localhost';"; then
    log ERRO "$turma/$login: o MariaDB falhou ao criar o banco."
    return 1
  fi

  [[ $existe_usuario == 0 ]] && log INFO "$turma/$login: banco de dados criado."
  return 0
}

# Remove o banco e o usuário do aluno. Só remove se o usuário do banco existir:
# um banco que não é de aluno nunca é apagado pelo nome.
function remover_banco() {
  local turma=$1 login=$2
  local existe_usuario

  mariadb_instalado || return 0

  existe_usuario=$(usuario_do_banco "$login") \
    || { log ERRO "$turma/$login: não foi possível acessar o MariaDB. Remova o banco depois: DROP DATABASE \`$login\`; DROP USER '$login'@'localhost';"; return 1; }
  [[ $existe_usuario == 1 ]] || return 0

  if ! mariadb --execute "DROP DATABASE IF EXISTS \`$login\`; DROP USER IF EXISTS '$login'@'localhost';"; then
    log ERRO "$turma/$login: o MariaDB falhou ao remover o banco. Remova depois: DROP DATABASE \`$login\`; DROP USER '$login'@'localhost';"
    return 1
  fi
  log INFO "$turma/$login: banco de dados removido."
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
      log INFO "$turma/$login: a conta já existe. A senha e os arquivos não foram alterados."
      criar_banco "$turma" "$login"   # completa o banco de contas criadas antes do MariaDB
      return
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

  criar_banco "$turma" "$login"
}

function remover_aluno() {
  local turma=$1 login=$2
  local home="$RAIZ/$turma/$login"
  local saida falha_banco=0

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

  # Uma falha no banco não impede a remoção da conta: o erro fica no log, com o comando para remover à mão
  remover_banco "$turma" "$login" || falha_banco=1

  if ! saida=$(deluser --remove-home "$login" 2>&1); then
    log ERRO "$turma/$login: o deluser falhou: $saida"
    return 1
  fi
  # Garante que a pasta sumiu, mesmo com arquivos de outro dono (www-data)
  [[ -d $home ]] && rm -rf -- "$home"

  # Remove a pasta da turma se ela ficou vazia
  rmdir "$RAIZ/$turma" 2> /dev/null

  log INFO "$turma/$login: conta e arquivos removidos."
  (( falha_banco == 0 ))
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
    confirmar "Remover TODAS as contas listadas em $arquivo, com os sites e os bancos de dados?" || { echo "Cancelado."; return 1; }
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
  $(basename "$0") --rm      <turma> <login>   Remove a conta, o site e o banco do aluno
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
      confirmar "Remover a conta $2/$3, TODOS os arquivos do site e o banco de dados?" || { echo "Cancelado."; exit 1; }
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