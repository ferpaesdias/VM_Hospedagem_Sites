# Instalar e configurar o Painel Web

Painel acessado pelo navegador em `http://[IP]:8080/_painel/`.

- **Docentes:** criam e removem contas de aluno (individualmente ou com `.csv`) e redefinem senhas.
- **Alunos:** entram com o mesmo login e senha do FTP, enviam e apagam os arquivos do site, esvaziam a pasta `uploads/` e alteram a senha.

Passos necessários:

- [Instalar e configurar o Painel Web](#instalar-e-configurar-o-painel-web)
  - [1. Instalar softwares necessários](#1-instalar-softwares-necessários)
  - [2. Instalar os scripts](#2-instalar-os-scripts)
  - [3. Criar o usuário do painel e liberar o sudo](#3-criar-o-usuário-do-painel-e-liberar-o-sudo)
  - [4. Copiar o painel](#4-copiar-o-painel)
  - [5. Criar o token e a chave de sessão](#5-criar-o-token-e-a-chave-de-sessão)
  - [6. Cadastrar os docentes](#6-cadastrar-os-docentes)
  - [7. Serviço do painel](#7-serviço-do-painel)
  - [8. Configurar o Nginx](#8-configurar-o-nginx)
  - [9. Testes](#9-testes)
  - [Como o painel funciona](#como-o-painel-funciona)

**Obs**.: Execute os comandos a partir da raiz deste repositório. O painel usa HTTP sem TLS, assim como o FTP: as senhas trafegam em texto claro, então use só em rede confiável.   

**Obs**.: Os comandos precisam de privilégios de root. Execute os comandos como `root` ou use o `sudo`.

<br/>

***

## 1. Instalar softwares necessários

```bash
apt update
apt install -y python3-flask gunicorn apache2-utils openssl
```
- `python3-flask` e `gunicorn`: executam o backend do painel.
- `apache2-utils`: fornece o comando `htpasswd` (senhas dos docentes no painel).

<br/>

***

## 2. Instalar os scripts

```bash
install -m 750 -o root -g root Cookbook/gerenciar_usuarios_ftp.sh /usr/local/sbin/gerenciar_usuarios_ftp
install -m 750 -o root -g root painel/painel-helper /usr/local/sbin/painel-helper
```
- `gerenciar_usuarios_ftp`: cria e remove as contas (veja [Gerenciar contas de alunos](Gerenciar_contas_de_alunos.md)).
- `painel-helper`: confere e troca senhas e grava os arquivos **como o próprio aluno**, com as mesmas permissões do FTP.

<br/>

***

## 3. Criar o usuário do painel e liberar o sudo

O painel roda com um usuário próprio, sem login. **Não use o `www-data`**: os sites PHP dos alunos rodam como `www-data` e teriam acesso ao sudo.

```bash
useradd --system --home /var/lib/painel --create-home --shell /usr/sbin/nologin painel
```

<br/>

O usuário `painel` só pode executar os dois scripts do passo anterior:

```bash
install -m 440 painel/deploy/sudoers-painel /etc/sudoers.d/painel
visudo -cf /etc/sudoers.d/painel
```

<br/>

***

## 4. Copiar o painel

```bash
mkdir -p /opt/painel/static
cp painel/app.py /opt/painel/
cp painel/static/index.html /opt/painel/static/
chown -R root:painel /opt/painel
chmod -R u=rwX,g=rX,o= /opt/painel
```

<br/>

***

## 5. Criar o token e a chave de sessão

- **Token:** garante que só o Nginx fala com o backend.
- **Chave de sessão:** assina o cookie de login.

Nenhum dos dois pode ser lido pelo `www-data`.

```bash
TOKEN=$(openssl rand -hex 32)
SEGREDO=$(openssl rand -hex 32)

mkdir -p /etc/painel
printf 'PAINEL_TOKEN=%s\nPAINEL_SEGREDO=%s\n' "$TOKEN" "$SEGREDO" | sudo tee /etc/painel/painel.env > /dev/null
chmod 600 /etc/painel/painel.env

tee /etc/nginx/painel-proxy.conf > /dev/null << FIM
proxy_set_header X-Painel-Token "${TOKEN}";
proxy_set_header Host \$host;
proxy_set_header X-Real-IP \$remote_addr;
proxy_read_timeout 300s;
client_max_body_size 21m;
FIM
chmod 600 /etc/nginx/painel-proxy.conf
```

<br/>

A senha inicial das contas de aluno é `123@mudar`. Para usar outra, acrescente `PAINEL_SENHA_INICIAL=...` ao `/etc/painel/painel.env` e altere a variável `SENHA_INICIAL` do script `gerenciar_usuarios_ftp`.

<br/>

***

## 6. Cadastrar os docentes

Os docentes têm uma senha própria do painel, diferente da senha Linux (que dá acesso ao `sudo`). A opção `-B` (bcrypt) é obrigatória. O `-c` cria o arquivo: use só no primeiro docente.

```bash
htpasswd -B -C 10 -c /etc/painel/docentes.htpasswd fernandopdias
htpasswd -B -C 10 /etc/painel/docentes.htpasswd outrodocente
chmod 600 /etc/painel/docentes.htpasswd
```

<br/>

Para trocar a senha de um docente, rode o mesmo comando sem o `-c`. Para remover um docente:

```bash
htpasswd -D /etc/painel/docentes.htpasswd outrodocente
```

<br/>

***

## 7. Serviço do painel

```bash
cp painel/deploy/painel.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now painel.service
systemctl status painel.service
```

<br/>

**Obs**.: Sempre que o `app.py` for atualizado, reinicie o serviço com `systemctl restart painel.service`. Mudanças só no `index.html` não precisam de reinício.

<br/>

***

## 8. Configurar o Nginx

O painel fica em um `server` próprio, na porta 8080. Por estar em outra porta, ele é outra origem para o navegador. Assim, um JavaScript ou PHP colocado no site de um aluno não consegue usar a sessão de quem está logado no painel.

```bash
cp painel/deploy/nginx-painel /etc/nginx/sites-available/painel
ln -s /etc/nginx/sites-available/painel /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx.service
```

<br/>

Se a VM tiver firewall, libere a porta `8080/tcp`.

<br/>

***

## 9. Testes

A página deve responder `200`:

```bash
curl -I http://localhost:8080/_painel/
```

<br/>

A API sem login deve responder `401`:

```bash
curl -i http://localhost:8080/_painel/api/sessao
```

<br/>

Direto no backend, sem passar pelo Nginx, deve responder `403`:

```bash
curl -I http://127.0.0.1:8001/api/sessao
```

<br/>

Logins, envios de arquivo e ações dos docentes ficam registrados no journal:

```bash
journalctl -u painel.service -f
```

<br/>

***

## Como o painel funciona

| Arquivo | Onde fica | Função |
|---|---|---|
| `painel/app.py` | `/opt/painel/app.py` | Backend (Flask). Roda como `painel`, sem acesso direto a senhas nem às pastas dos alunos |
| `painel/static/index.html` | `/opt/painel/static/index.html` | Página única: login, área do docente e área do aluno, com tema claro e escuro |
| `painel/painel-helper` | `/usr/local/sbin/painel-helper` | Operações privilegiadas: confere e troca senhas, grava e apaga arquivos como o aluno |
| `Cookbook/gerenciar_usuarios_ftp.sh` | `/usr/local/sbin/gerenciar_usuarios_ftp` | Cria e remove contas |
| `painel/deploy/sudoers-painel` | `/etc/sudoers.d/painel` | Libera para o `painel` apenas os dois scripts acima |
| `painel/deploy/painel.service` | `/etc/systemd/system/painel.service` | Serviço do Gunicorn, em `127.0.0.1:8001` |
| `painel/deploy/nginx-painel` | `/etc/nginx/sites-available/painel` | Porta 8080, com limite de tentativas de login |

Pontos de segurança:

- O helper só opera em contas de aluno (shell `/bin/shell_ftp` e HOME em `/projetos/turma/login`). Contas de docentes e do sistema nunca são tocadas.
- Para gravar, listar e apagar arquivos, o helper vira o próprio aluno (`setuid`). Dentro da `uploads/`, o que o aluno não consegue apagar é apagado como `www-data`. Nenhuma remoção é feita como root.
- Depois de 5 senhas erradas, o login fica bloqueado por 5 minutos. O Nginx também limita as tentativas por IP.
