#!/bin/bash

###############################################################################
### 
###      Script para a criação de turma e usuários para o FTP
###  
###  
### 
###  O usuário permite que o aluno faça o upload do seu projeto (site) via 
###  FTP.
### 
###  O diretório Home do usuário será o diretório /projetos/turma/nome_do_aluno
### 
###  O diretório Home será onde o aluno fará o upload dos arquivos e onde 
###  estará hospedado o seu projeto.
### 
###  Formato do usuário: O usuário dos alunos (FTP) será o mesmo da primeira 
###  parte do e-mail 
###  educacional (sem o domínio), porém, sem o ponto separando o nome e 
###  sobrenome.
###  Exemplo: O usuário do aluno Fulano da Silva, que possui o email 
###  fulano.dsilva@senac.sp.br, será fulanodsilva.
### 
###
###  Modo de uso:
###    Para inserir somente um aluno:
###    $ ./gerenciar_usuarios_ftp --add turma nome_do_aluno
###   
###    Para remover um somente um aluno:
###    $ ./gerenciar_usuarios_ftp --rm turma nome_do_aluno
###   
###    Para inserir somente um grupo de alunos usando um arquivo .csv:
###    $ ./gerenciar_usuarios_ftp --add --csv arquivo.csv
###   
###    Para remover um somente um alunos usando um arquivo .csv:
###    $ ./gerenciar_usuarios_ftp --csv arquivo.csv
###
###  
###  Formato do arquivo .csv:
###    turma01,nome_do_aluno01
###    turma02,nome_do_aluno02
###    turma02,nome_do_aluno03
###    turma02,nome_do_aluno04
### 
###############################################################################

$1=turma
$2=nomeAluno

echo 



## Criação de usuários




# Criar o diretório `/projetos/turma01`. Neste diretório ficará as pastas HOME dos usuários.

# ```bash
# mkdir -p /projetos/turma01
# chown root:www-data /projetos/turma01/
# chmod 751 /projetos/turma01
# ```

# <br/>

# Criar o diretório `/projetos/turma01/aluno01`. Este diretório será a pasta HOME do usuário `aluno01`.

# ```bash
# mkdir -p /projetos/turma01/aluno01
# chown aluno01:www-data /projetos/turma01/aluno01
# chmod 2750 /projetos/turma01/aluno01
# ```
# Obs.: No comando `chmod`, o número `2` significa que os arquivos e subpastas criados ali irá herdar o grupo do diretório, em ver de herdar o grupo do usuário que criou.

# <br/>

# Criar uma shell restrita para as contas dos alunos. 

# As contas de aluno não devem ter shell de verdade. O vsftpd exige que a shell do usuário exista em `/etc/shells`, senão o login FTP é recusado. 

# Criar o "shell"
# ```bash
# cat << EOF > /bin/shell_ftp
# #!/bin/sh

# echo "Esta conta e' apenas para upload via FTP."
# sleep 3
# EOF
# ```

# <br/>

# Atribuir permissão de execução

# ```bash
# chmod +x /bin/shell_ftp
# ```

# <br/>

# Adicionar o shell ao arquivo `/etc/shells`

# ```bash
# echo '/bin/shell_ftp' >> /etc/shells
# ```

# <br/>

# Criar o usuário `aluno01`

# ```bash
# useradd --no-create-home --home /projetos/turma01/aluno01 --shell /usr/sbin/nologin aluno01 
# ``` 

# <br/>