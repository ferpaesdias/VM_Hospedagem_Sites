# Instalar e configurar o FTP

Passos necessários:

- [Instalar e configurar o FTP](#instalar-e-configurar-o-ftp)
  - [1. Atualizar sistema e instalar softwares necessários](#1-atualizar-sistema-e-instalar-softwares-necessários)
  - [2. Configurar o vsftpd](#2-configurar-o-vsftpd)

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
