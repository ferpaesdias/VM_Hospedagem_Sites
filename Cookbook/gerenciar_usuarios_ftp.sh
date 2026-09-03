



















# ## 3. Criação de usuários


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