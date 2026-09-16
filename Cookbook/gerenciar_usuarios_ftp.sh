#!/bin/bash

###############################################################################
###
###      Script para criar e remover contas de aluno no servidor FTP
###
###  ──────────────────────────────────────────────────────────────────────
###  CONTEXTO
###  ──────────────────────────────────────────────────────────────────────
###
###  Cada aluno recebe uma conta no sistema para enviar os arquivos do seu
###  projeto (site) via FTP.
###
###  O diretório HOME do aluno é /projetos/turmaXX/nome_aluno/ e serve, ao
###  mesmo tempo, como raiz do site publicada pelo Nginx: os arquivos
###  enviados via FTP aparecem imediatamente no endereço público do aluno.
###
###  ──────────────────────────────────────────────────────────────────────
###  CONVENÇÃO DE NOMES DE USUÁRIO
###  ──────────────────────────────────────────────────────────────────────
###
###  O nome de usuário é derivado do e-mail educacional: usa-se a parte
###  antes do @ e remove-se o ponto entre nome e sobrenome.
###
###    E-mail: fulano.dsilva@escola.edu.br
###    Usuário: fulanodsilva
###
###  ──────────────────────────────────────────────────────────────────────
###  MODOS DE USO
###  ──────────────────────────────────────────────────────────────────────
###
###  Criar um único aluno:
###    $ ./gerenciar_usuarios_ftp --add turma nome_do_aluno
###
###  Remover um único aluno:
###    - Todos os projetos do aluno serão perdidos, não tem como recuperar
###    - Se for o último aluno da turma o diretório /projetos/[turma] será removido
###    $ ./gerenciar_usuarios_ftp --rm turma nome_do_aluno
###           
###  Criar vários alunos de uma vez a partir de um arquivo CSV:
###    $ ./gerenciar_usuarios_ftp --add-csv arquivo.csv
###
###  Remover vários alunos de uma vez a partir de um arquivo CSV:
###    $ ./gerenciar_usuarios_ftp --rm-csv arquivo.csv
###
###  ──────────────────────────────────────────────────────────────────────
###  FORMATO DO ARQUIVO CSV
###  ──────────────────────────────────────────────────────────────────────
###
###  Cada linha representa um aluno, no formato:  turma,nome_do_aluno
###
###    turma01,fulanodsilva
###    turma01,cicranodsantos
###    turma02,beltranodaraujo
###    turma02,mariadfreitas
###
###############################################################################

# Variáveis de entrada
OPCAO=$1
NOME_TURMA=$2
NOME_ALUNO=$3
ARQUIVO_LOG="vm_hospedagem.log"

#### ------------------------------------------------------
#### Função que imprime mensagem informativa formatada.
#### Os logs vão para o arquivo vm_hospedagem.log
#### ------------------------------------------------------
function log_erro() {
  local mensagem_erro=$*
  local data_hora
  data_hora=$(date '+[%Y-%m-%d %H:%M:%S]')
  printf "%s [ERRO] %s\n" "${data_hora}" "${mensagem_erro}" >> ${ARQUIVO_LOG}
  echo -e "\n$mensagem_erro"   #TODO: Remover está linha
  exit 1
}

#### ------------------------------------------------------
#### Função que imprime mensagem informativa formatada.
#### Os logs vão para o arquivo "vm_hospedagem.log"
#### ------------------------------------------------------

function log_info() {
  local mensagem_info=$*
  local data_hora
  data_hora=$(date '+[%Y-%m-%d %H:%M:%S]')
  printf "%s [INFO] %s\n" "${data_hora}" "${mensagem_info}" >> ${ARQUIVO_LOG}
  echo -e "\n$mensagem_info"   #TODO: Remover está linha
  # TODO: Ajustar a permissão do arquivo de log para quando o usuário não for root 
}

#### ------------------------------------------------------
#### Função que verifica se o que está executando o 
#### script é root
#### ------------------------------------------------------

function checar_root() {
  if [[ $EUID -ne 0 ]]; then
    log_erro "Este script deve ser executado como root."
  fi
}

#### ------------------------------------------------------
#### Função que cria o shell do usuário FTP
#### ------------------------------------------------------
function criar_shell_ftp() {
  local arquivo_shell="/bin/shell_ftp"

 # Verifica se o arquivo shell_ftp já existe, se não existe ele é criado
  if [[ ! -f "/bin/shell_ftp" ]]; then
    echo "O arquivo ${arquivo_shell} não existe, criando o arquivo"
    echo -e '#!/bin/sh\n\necho "Esta conta é apenas para upload via FTP."\nsleep 3' > \
      ${arquivo_shell}
  fi

  # Verifica se o arquivo existe e atribui permissão de execução ao arquivo
  [ -f ${arquivo_shell} ] && chmod +x ${arquivo_shell}

  # Adiciona o shell no arquivo de Shells do sistema
  grep --quiet "${arquivo_shell}" /etc/shells || echo "${arquivo_shell}" >> /etc/shells
}

#### ------------------------------------------------------
#### Função que valida o nome da turma 
#### Deve ter somente letras e/ou números
#### ------------------------------------------------------
function validar_nome_turma() {
  local nome_da_turma=$1
  if [[ ! $nome_da_turma =~ ^[a-zA-Z0-9]+$ ]]; then
    log_erro "Nome da turma inválido: \"${nome_da_turma}\". Use apenas letras e números."
  fi
}

#### ------------------------------------------------------
#### Função que cria uma turma e o diretório 
#### /projetos/[turma]/
#### ------------------------------------------------------
function criar_turma() {
  local nome_turma=$1

  echo -e "\nCriando o arquivo /projetos/${nome_turma}"
  mkdir -p /projetos/"${nome_turma}"
  chown root:www-data /projetos/"${nome_turma}"
  chmod 751 /projetos/"${nome_turma}"
}

#### ------------------------------------------------------
#### Função que valida o nome do usuário
#### Deve ter somente letras e/ou números
#### ------------------------------------------------------
function validar_nome_aluno() { 
  local nome_da_aluno=$1
  if [[ ! $nome_da_aluno =~ ^[a-zA-Z0-9]+$ ]]; then
    log_erro "Nome do aluno inválido: \"${nome_da_aluno}\". Use apenas letras e números."
  fi
}

#### ------------------------------------------------------
#### Função que cria um usuário e o diretório HOME
#### ------------------------------------------------------
function criar_usuario() {
  local nome_turma=$1
  local nome_usuario=$2
  local senha_usuario="123"
  local arquivo_shell="/bin/shell_ftp"
  
  # Verifica se o usuário já existe
  if id "$nome_usuario" > /dev/null 2>&1 ; then
    log_info "$nome_usuario: Este usuário já existe!" 

    # verifica se o HOME está seguindo o padrão do sistema
    local usuario_home
    usuario_home=$(getent passwd "$nome_usuario" | cut -d: -f 6)
    local usuario_shell
    usuario_shell=$(getent passwd "$nome_usuario" | cut -d: -f 7)
    if [ "$usuario_home" != /projetos/"${nome_turma}"/"${nome_usuario}" ] || \
       [ "$usuario_shell" != "${arquivo_shell}" ]; then
      log_erro "O diretório HOME ou o SHELL do usuário estão fora do padrão.\nVerifique e execute o script novamente"
    fi
  fi

  # Criando o usuário
  echo -e "\nCriando o usuário ${nome_usuario}"
  useradd --no-create-home --home /projetos/"${nome_turma}"/"${nome_usuario}" \
          --shell ${arquivo_shell} "${nome_usuario}"
  echo "${nome_usuario}:${senha_usuario}" | chpasswd        

  # Criando o diretório HOME do usuário e configurando permissões 
  mkdir -p /projetos/"${nome_turma}"/"${nome_usuario}"
  chown "${nome_usuario}":www-data /projetos/"${nome_turma}"/"${nome_usuario}"
  chmod 2750 /projetos/"${nome_turma}"/"${nome_usuario}"
}

#### ------------------------------------------------------
#### Função que remove um usuário e o seu diretório HOME
#### ------------------------------------------------------
function remover_usuario() {
  local nome_turma=$1
  local nome_usuario=$2
  local usuario_home
  usuario_home="/projetos/${nome_turma}/${nome_usuario}"
  
  # Verifica se o usuário já existe e, caso exista, o remove
  if id "$nome_usuario" > /dev/null 2>&1 ; then
    deluser --remove-home "$nome_usuario" 
  fi

  # Confere se o diretório HOME do usuário foi removido
  if [ -d "$usuario_home" ]; then
    rm -rf "$usuario_home"
  fi

  # Verifica se o diretório da turma está vazio e, caso esteja, o remove
  rmdir "/projetos/${nome_turma}" 2>/dev/null
}

#### ------------------------------------------------------
#### Função que verifica qual é a opção 
#### (--add, --rm, --add-csv, --rm-csv)
#### ------------------------------------------------------

function verifica_opcao() {
  local opcao_comando
  opcao_comando=$1
  local nome_turma
  nome_turma=$2
  local nome_aluno
  nome_aluno=$3

  case $opcao_comando in
    --add)
      checar_root
      criar_shell_ftp
      # validar_nome_turma "$nome_turma";
      # criar_turma "$nome_turma";
      # validar_nome_aluno "$nome_aluno";
      # criar_usuario "$nome_turma" "$nome_aluno"
      ;;

    --rm)
      remover_usuario "$nome_turma" "$nome_aluno";       
      ;;
    
    --add-csv)  definir_opcao "add-csv";  shift ;;
    
    --rm-csv)   definir_opcao "add-rm";   shift ;;


  esac
}

#### ------------------------------------------------------
#### Executando as funções
#### ------------------------------------------------------
verifica_opcao "$OPCAO" "$NOME_TURMA" "$NOME_ALUNO"


# -------------------------------------------

# # Função que exibe ajuda caso o usuário digite --help ou -h
# function exibir_ajuda() { 
  
#   echo "Uso: $0 [--add | --rm] [--csv arquivo.csv] turma nome_aluno"
#   echo "       $0 --help"
#   echo ""
#   echo "Opções:"
#   echo "  --add           Adiciona um aluno ao servidor FTP"
#   echo "  --rm            Remove um aluno do servidor FTP"
#   echo "  --csv arquivo   Lê os alunos de um arquivo CSV (turma,nome_aluno)"
#   echo "  --help, -h      Exibe esta mensagem de ajuda"
# }

# # Verifica se o usuário digitou --help ou -h
# if [[ "$1" == "--help" || "$1" == "-h" ]]; then
#   exibir_ajuda
#   exit 0
# fi

# # -------------------------------------------


# # # -------------------------------------------


# function usuario_existe() { :; }
# function diretorio_existe() { :; }
# function garantir_shell_ftp() { :; }
# function garantir_diretorio_turma() { :; }
# function criar_aluno() { :; }
# function confirmar_operacao() { :; }
# function remover_aluno() { :; }
# function parsear_argumentos() { :; }
# function main() { :; }
# function processar_csv_add() { :; }
# function processar_csv_rm() { :; }


