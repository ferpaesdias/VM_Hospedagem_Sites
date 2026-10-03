# Instalar e configurar o Nginx e o PHP

Passos necessários:

- [Instalar e configurar o Nginx e o PHP](#instalar-e-configurar-o-nginx-e-o-php)
  - [1. Instalar softwares necessários](#1-instalar-softwares-necessários)
  - [2. Ajustar permissões do diretório `/projetos`](#2-ajustar-permissões-do-diretório-projetos)
  - [3. Configurar o Nginx](#3-configurar-o-nginx)
  - [4. Configurar o PHP](#4-configurar-o-php)
  - [5. Serviços](#5-serviços)
  - [6. Testes](#6-testes)

**Obs**.: Execute os comandos a partir da raiz deste repositório. Os dois arquivos de configuração ficam na pasta [`config/`](../config) e são copiados prontos, sem edição.

<br/>

*** 

## 1. Instalar softwares necessários

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y nginx curl php-fpm php-mysql php-mbstring php-xml php-curl php-gd php-zip php-sqlite3
```
- `nginx`: servidor web.
- `php-fpm`: executa os arquivos `.php` entregues pelo Nginx. Roda como `www-data`, o mesmo grupo das pastas dos alunos.
- `php-mysql`, `php-mbstring` etc.: extensões mais usadas em projetos de alunos.
- `curl`: usado nos testes.

**Obs**.: Não instale o pacote `php` sozinho: ele pode puxar o Apache (`libapache2-mod-php`) como dependência. O `php-fpm` basta.

<br/>

*** 

## 2. Ajustar permissões do diretório `/projetos`

Será usado o diretório `/projetos` criado em [Configurar o Sistema Operacional](Configurar_Sistema_Operacional.md).

```bash
sudo chown root:www-data /projetos
sudo chmod 751 /projetos
```
- `www-data` é o usuário do Nginx e do PHP-FPM, e precisa ler as pastas.
- O `1` final (execução para "outros") permite que cada aluno atravesse `/projetos` até a própria pasta. Com `750`, os alunos não conseguem chegar ao próprio `HOME`.

<br/>

*** 

## 3. Configurar o Nginx

Todo PHP roda como `www-data`, o mesmo usuário para todos os alunos. Sem cuidado, o PHP de um aluno conseguiria ler o código dos colegas. A configuração isola cada aluno:

- **`open_basedir`:** prende o PHP de `/turma/aluno/` à pasta do próprio aluno.
- **`session.cookie_path`:** faz o cookie de sessão valer só para o site do aluno. Sem isso, o mesmo visitante teria a mesma sessão em todos os sites.
- **PHP bloqueado na `uploads/`:** a pasta onde o PHP grava nunca executa código.

Como esses valores são definidos por `PHP_ADMIN_VALUE`, os alunos não conseguem alterá-los com `ini_set()`.

<br/>

Copie o arquivo [`config/nginx-projetos`](../config/nginx-projetos), ative-o e desative o site padrão do Nginx:

```bash
sudo cp config/nginx-projetos /etc/nginx/sites-available/projetos
sudo ln -s /etc/nginx/sites-available/projetos /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
```

<br/>

Conteúdo do arquivo:

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    # O "_" responde por IP (qualquer host)
    server_name _;

    root /projetos;
    index index.php index.html index.htm;

    # Tamanho máximo de envio por formulário (igual ao upload_max_filesize do PHP)
    client_max_body_size 20M;

    # Bloqueia arquivos ocultos (.git, .env, .htpasswd, .user.ini etc.).
    # Precisa vir antes dos blocos PHP, senão um arquivo como .teste.php seria executado.
    location ~ /\. {
        deny all;
    }

    # Arquivos estáticos, sem listar o conteúdo das pastas
    location / {
        autoindex off;
        try_files $uri $uri/ =404;
    }

    # Arquivos gravados na pasta uploads/ nunca são executados como PHP.
    # Precisa vir antes do bloco do PHP dos alunos: o Nginx testa as regex em ordem.
    location ~ ^/[A-Za-z0-9]+/[A-Za-z0-9]+/uploads/.*\.php$ {
        return 403;
    }

    # PHP de cada aluno: $1 = turma, $2 = aluno
    #   open_basedir:        o PHP só enxerga a pasta do próprio aluno
    #                        (/tmp é necessário para o upload de arquivos por formulário)
    #   session.cookie_path: o cookie de sessão vale só para o site do aluno
    # A quebra de linha dentro das aspas separa as duas diretivas.
    location ~ ^/([A-Za-z0-9]+)/([A-Za-z0-9]+)/.*\.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_param PHP_ADMIN_VALUE "open_basedir=/projetos/$1/$2/:/tmp/:/var/lib/php/sessions/
session.cookie_path=/$1/$2/";
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    }

    # PHP fora de /turma/aluno/ não executa
    location ~ \.php$ {
        return 403;
    }
}
```
- Com `index.php` na diretiva `index`, `http://[IP]/turma/aluno/` abre o `index.php` do aluno. Se ele não existir, o Nginx usa o `index.html`.
- O `snippets/fastcgi-php.conf` do Debian impede a execução de arquivos PHP inexistentes, o que corrige a antiga falha do `cgi.fix_pathinfo`.

<br/>

Teste a configuração:

```bash
sudo nginx -t
```

Output:

```bash
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

<br/>

*** 

## 4. Configurar o PHP

As configurações do PHP ficam num arquivo próprio em `conf.d/`. Ele é lido depois do `php.ini`, então os valores dele prevalecem sem precisar editar o `php.ini`.

```bash
sudo cp config/php-hospedagem.ini /etc/php/8.4/fpm/conf.d/99-hospedagem.ini
```

<br/>

Conteúdo do arquivo [`config/php-hospedagem.ini`](../config/php-hospedagem.ini):

```ini
; Fuso horário usado por date(), DateTime etc.
date.timezone = America/Sao_Paulo

; Tamanho máximo de arquivo enviado por formulário.
; O post_max_size precisa ser maior ou igual ao upload_max_filesize.
; No Nginx, o client_max_body_size está em 20M.
upload_max_filesize = 20M
post_max_size = 21M

; Funções que executam comandos do sistema. O open_basedir não vale para
; esses comandos: com elas, um aluno poderia ler ou apagar os sites dos colegas.
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,pcntl_exec

; Desativa os arquivos .user.ini, que deixariam o aluno mudar configurações do PHP.
user_ini.filename =

; Não revela a versão do PHP no cabeçalho das respostas.
expose_php = Off
```
- O `disable_functions` só funciona em arquivos `.ini`: ele não pode ser definido pelo `PHP_ADMIN_VALUE` do Nginx.
- O `99-` no nome garante que este arquivo seja lido por último em `conf.d/`.

<br/>

*** 

## 5. Serviços

Habilitar e reiniciar o Nginx e o PHP-FPM:

```bash
sudo systemctl enable nginx.service php8.4-fpm.service
sudo systemctl restart php8.4-fpm.service nginx.service
```

<br/>

Verifique o status:

```bash
systemctl status nginx.service php8.4-fpm.service
```

<br/>

**Obs**.: Depois de alterar o arquivo do Nginx, basta `sudo nginx -t && sudo systemctl reload nginx.service`. Depois de alterar o arquivo do PHP, é preciso `sudo systemctl restart php8.4-fpm.service`.

<br/>

*** 

## 6. Testes

Crie uma pasta de teste no formato `/turma/aluno/`, com uma página HTML, uma página PHP e um PHP dentro da `uploads/`:

```bash
sudo mkdir -p /projetos/turmateste/aluno/uploads
echo '<h1>Nginx OK</h1>' | sudo tee /projetos/turmateste/aluno/index.html > /dev/null
echo '<?php echo "PHP OK - ", date_default_timezone_get(), " - ", date("d/m/Y H:i"), "\n";' | sudo tee /projetos/turmateste/aluno/teste.php > /dev/null
echo '<?php echo "não deveria executar";' | sudo tee /projetos/turmateste/aluno/uploads/teste.php > /dev/null
sudo chown -R root:www-data /projetos/turmateste
```

<br/>

Página estática:

```bash
$ curl http://localhost/turmateste/aluno/
<h1>Nginx OK</h1>
```

<br/>

PHP e fuso horário (a hora deve ser a de Brasília):

```bash
$ curl http://localhost/turmateste/aluno/teste.php
PHP OK - America/Sao_Paulo - 01/10/2026 16:31
```

<br/>

PHP dentro da `uploads/` não executa:

```bash
$ curl -s -o /dev/null -w "%{http_code}\n" http://localhost/turmateste/aluno/uploads/teste.php
403
```

<br/>

Depois dos testes, remova a pasta:

```bash
sudo rm -r /projetos/turmateste
```

<br/>

O teste completo, com uma conta de aluno de verdade, está no final do guia [Gerenciar contas de alunos](Gerenciar_contas_de_alunos.md#6-teste-completo).
