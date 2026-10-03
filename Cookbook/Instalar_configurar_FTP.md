# Instalar e configurar o FTP

Passos necessários:

- [Instalar e configurar o FTP](#instalar-e-configurar-o-ftp)
  - [1. Instalar o vsftpd](#1-instalar-o-vsftpd)
  - [2. Configurar o vsftpd](#2-configurar-o-vsftpd)
  - [3. Serviço vsftpd](#3-serviço-vsftpd)
  - [4. Testes](#4-testes)

**Obs**.: Execute os comandos a partir da raiz deste repositório. O arquivo de configuração fica na pasta [`config/`](../config) e é copiado pronto, sem edição.   

**Obs**.: Os comandos precisam de privilégios de root. Execute os comandos como `root` ou use o `sudo`.

<br/>

*** 

## 1. Instalar o vsftpd

```bash
apt update
apt upgrade -y
apt install -y vsftpd
```

<br/>

*** 

## 2. Configurar o vsftpd

O vsftpd não tem uma pasta `conf.d/`: toda a configuração fica em `/etc/vsftpd.conf`. Por isso o arquivo deste repositório **substitui** o original por inteiro, e já traz as opções do arquivo padrão do Debian que precisam ser mantidas.

Faça um backup do arquivo original e copie o arquivo [`config/vsftpd.conf`](../config/vsftpd.conf):

```bash
cp /etc/vsftpd.conf /etc/vsftpd.conf.original
cp config/vsftpd.conf /etc/vsftpd.conf
```

<br/>

Conteúdo do arquivo:

```bash
# ---------------------------------------------------------------------------
# Serviço
# ---------------------------------------------------------------------------

# Funciona como daemon independente, gerenciado pelo systemd.
listen=YES

# Desativa o IPv6. O vsftpd não ouve IPv4 e IPv6 ao mesmo tempo com uma só instância.
listen_ipv6=NO

# Configuração de autenticação em /etc/pam.d/vsftpd.
# Sem esta linha, o vsftpd procura outro nome de serviço e recusa todas as senhas.
pam_service_name=vsftpd

# Pasta vazia usada internamente pelo vsftpd para isolar seus processos.
secure_chroot_dir=/var/run/vsftpd/empty

# ---------------------------------------------------------------------------
# Quem pode entrar
# ---------------------------------------------------------------------------

# Desativa o acesso anônimo.
anonymous_enable=NO

# Permite que os usuários locais (/etc/passwd) façam login.
# O root continua bloqueado pelo arquivo /etc/ftpusers.
local_enable=YES

# ---------------------------------------------------------------------------
# Envio de arquivos e permissões
# ---------------------------------------------------------------------------

# Permite enviar, apagar, renomear arquivos e criar pastas.
write_enable=YES

# Permissão dos arquivos e pastas enviados:
# pastas 750 (rwxr-x---) e arquivos 640 (rw-r-----).
# Com o setgid da pasta do aluno, o grupo fica www-data e o Nginx consegue ler.
local_umask=027

# ---------------------------------------------------------------------------
# Isolamento
# ---------------------------------------------------------------------------

# Cada usuário fica preso dentro do próprio HOME, como se ele fosse a raiz (/).
chroot_local_user=YES

# Permite gravar na raiz do chroot, que para o aluno é a raiz do site.
# Atenção: a diretiva é "writeable", com "e".
allow_writeable_chroot=YES

# ---------------------------------------------------------------------------
# Conexão
# ---------------------------------------------------------------------------

# Modo ativo: o servidor conecta a partir da porta 20.
connect_from_port_20=YES

# Modo passivo (usado pelo FileZilla e pela maioria dos clientes).
# Faixa fixa de portas, para facilitar a liberação num firewall.
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100

# Desconecta clientes parados há 10 minutos.
idle_session_timeout=600

# ---------------------------------------------------------------------------
# Log
# ---------------------------------------------------------------------------

# Registra os envios e downloads em /var/log/vsftpd.log.
xferlog_enable=YES

# Horários no fuso do sistema (America/Sao_Paulo), não em UTC.
use_localtime=YES

# ---------------------------------------------------------------------------
# Criptografia
# ---------------------------------------------------------------------------

# FTP sem TLS por enquanto: as senhas trafegam em texto claro.
# Uso restrito a rede confiável até a configuração do FTPS.
ssl_enable=NO
```
- No vsftpd, comentários só podem ficar em **linhas próprias**. Um comentário no fim da linha (`opcao=valor  # comentário`) faz o serviço falhar com `status=2/INVALIDARGUMENT`.
- As contas de aluno usam o shell `/bin/shell_ftp`, que impede o login por SSH. O vsftpd aceita esse shell porque o script de contas o registra em `/etc/shells`.
- Se a VM tiver firewall, libere as portas `21/tcp` e `40000-40100/tcp` (modo passivo).

<br/>

*** 

## 3. Serviço vsftpd

Habilitar e reiniciar o serviço:

```bash
systemctl enable vsftpd.service
systemctl restart vsftpd.service
systemctl status vsftpd.service
```

<br/>

**Obs**.: Depois de alterar o `/etc/vsftpd.conf`, é preciso `systemctl restart vsftpd.service`.

<br/>

*** 

## 4. Testes

Crie uma conta de teste com o script do repositório (o guia [Gerenciar contas de alunos](Gerenciar_contas_de_alunos.md) explica o script em detalhes):

```bash
bash Cookbook/gerenciar_usuarios_ftp.sh --add turmateste teste
```

<br/>

Liste a pasta do aluno pelo FTP. Devem aparecer só os itens do site, como `uploads`:

```bash
curl -u teste:123@mudar ftp://localhost/
```

Output:
```bash
drwxrws---    2 1004     33           4096 Oct 01 17:08 uploads
```

<br/>

Envie um arquivo e confira que o Nginx já publica:

```bash
echo '<h1>Enviado pelo FTP</h1>' > /tmp/index.html
curl -su teste:123@mudar -T /tmp/index.html ftp://localhost/
curl -s http://localhost/turmateste/teste/
```

Output:

```bash
<h1>Enviado pelo FTP</h1>
```

<br/>

Confira que o aluno não sai da própria pasta. Dentro do chroot não existe `/etc`, então o servidor nega o acesso:

```bash
curl -u teste:123@mudar ftp://localhost/etc/passwd
```

Output:
```bash
curl: (9) Server denied you to change to the given directory
```

<br/>

Os envios ficam registrados no log:

```bash
tail /var/log/vsftpd.log
```

<br/>

Remova a conta de teste (o script pede confirmação):

```bash
bash Cookbook/gerenciar_usuarios_ftp.sh --rm turmateste teste
rm /tmp/index.html
```
