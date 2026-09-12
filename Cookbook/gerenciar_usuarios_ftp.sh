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
###    $ ./gerenciar_usuarios_ftp --add --csv arquivo.csv
###
###  Remover vários alunos de uma vez a partir de um arquivo CSV:
###    $ ./gerenciar_usuarios_ftp --rm --csv arquivo.csv
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

# Função que verifica se o usuário é root:
function verifica_usuario_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Este script deve ser executado como root." >&2
    exit 1
  fi  
}

verifica_usuario_root
