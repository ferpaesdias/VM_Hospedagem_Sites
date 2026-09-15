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
  # TODO: Ajustar a permissão do arquivo de log para quando o usuário não for root 
}


#### ------------------------------------------------------
#### Função que verifica se o usuário é root
#### ------------------------------------------------------

function checar_root() {
  if [[ $EUID -ne 0 ]]; then
  log_erro "Este script deve ser executado como root."
  echo "Erro: Este script deve ser executado como root."
  exit 1
fi
}
checar_root


#### ------------------------------------------------------
#### Função que verifica qual é a opção 
#### (--add, --rm, --add-csv, --rm-csv)
#### ------------------------------------------------------

function verifica_opcao() {
  local opcao_comando
  opcao_comando=$1
}

### TODO: Continuar aqui





# -------------------------------------------

# # Função que valida o nome da turma (somente letras e/ou números)
# function validar_nome_turma() {
#   local nome_da_turma
#   nome_da_turma=$1
#   if [[ ! $nome_da_turma =~ ^[a-zA-Z0-9]+$ ]]; then
#     log_erro "Nome da turma inválido: ${nome_da_turma}. Use apenas letras e números."
#     echo -e "\nErro: Nome da turma inválido: ${nome_da_turma}. \nUse apenas letras e números."
#     exit 1
#   fi
# }
# validar_nome_turma "$NOME_TURMA"

# # -------------------------------------------

# # Função que valida o nome do aluno (somente letras e/ou números) 
# function validar_nome_aluno() { 
#   local nome_da_aluno=$1
#   if [[ ! $nome_da_aluno =~ ^[a-zA-Z0-9]+$ ]]; then
#     log_erro "Nome do aluno inválido: ${nome_da_aluno}. Use apenas letras e números."
#     echo -e "\nErro: Nome da turma inválido: ${nome_da_aluno}. \nUse apenas letras e números."
#     exit 1
#   fi
# }

# validar_nome_aluno "$NOME_ALUNO"

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


