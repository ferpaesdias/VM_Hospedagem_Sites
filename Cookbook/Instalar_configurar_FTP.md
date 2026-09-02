# Instalar e configurar o FTP

Passos necessários:

- [Instalar e configurar o FTP](#instalar-e-configurar-o-ftp)
  - [1. Atualizar sistema e instalar softwares necessários](#1-atualizar-sistema-e-instalar-softwares-necessários)
  - [2. Configurar o vsftpd](#2-configurar-o-vsftpd)
  - [3. Criação de usuários](#3-criação-de-usuários)

**Obs**.: Considere que a VM já tenha um disco adicional configurado.

<br/>

*** 

## 1. Atualizar sistema e instalar softwares necessários

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y vsftpd
```

<br/>

*** 

## 2. Configurar o vsftpd

Faça um backup do arquivo de configuração atual:

```bash
cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
```

<br/>

Edite o arquivo de configuração para ficar igual está abaixo:


```bash
# Faz com que o o vsftpd funcione como standalone, ele funcionará como um daemon normal gerenciado pelo systemd.
listen=YES

# Desativa o IPv6. O vsftpd não funciona ouvindo IPv4 e IPv6 ao mesmo tempo.
listen_ipv6=NO

# Desativa acesso anônimo.
anonymous_enable=NO

# Permite que os usuários locais (/etc/passwd) façam login.
local_enable=YES

# Permite o upload de arquivos.
write_enable=YES

# Aplica permissão em pastas e arquivos que os alunos fizerem upload
# As pastas ficarão com permissão 750 (rwxr-x---) e os arquivos ficarão com permissão 640 (rw-r-----).
local_umask=027

# O usuário do FTP ficará "preso" dentro de seu diretório HOME como se fosse a raiz (/) do sistema. 
chroot_local_user=YES

# O usuário do FTP poderá terá permissão para criar pastas e arquivos.
allow_writeable_chroot=YES
```
<br/>

*** 

## 3. Criação de usuários


Criar o usuário `aluno01`

```bash
useradd --no-create-home --home /projetos/turma01/aluno01 --shell /usr/sbin/nologin aluno01 
``` 

<br/>

Criar o diretório `/projetos/turma01`. Neste diretório ficará as pastas HOME dos usuários.

```bash
mkdir -p /projetos/turma01
chown root:www-data /projetos/turma01/
chmod 751 /projetos /projetos/turma01
```

<br/>

Criar o diretório `/projetos/turma01/aluno01`. Este diretório será a pasta HOME do usuário `aluno01`.

```bash
mkdir -p /projetos/turma01/aluno01
chown aluno01:www-data /projetos/turma01/aluno01
chmod 2750 /projetos/turma01/aluno01
```
Obs.: No comando `chmod`, o número `2` significa que os arquivos e subpastas criados ali irá herdar o grupo do diretório, em ver de herdar o grupo do usuário que criou.


Criar uma shell restrita para as contas dos alunos. 

As contas de aluno não devem ter shell de verdade. O vsftpd exige que a shell do usuário exista em `/etc/shells`, senão o login FTP é recusado. 

Criar o "shell"
```bash
cat << EOF > /bin/shell_ftp
#!/bin/sh

echo "Esta conta e' apenas para upload via FTP."
sleep 3
EOF
```

<br/>

Atribuir permissão de execução

```bash
chmod +x /bin/shell_ftp
```

<br/>

Adicionar o shell ao arquivo `/etc/shells`

```bash
echo '/bin/shell_ftp' >> /etc/shells
```

