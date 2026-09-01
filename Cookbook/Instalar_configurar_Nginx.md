# Instalar e configurar o Nginx

Passos necessários:

- [Instalar e configurar o Nginx](#instalar-e-configurar-o-nginx)
  - [1. Atualizar sistema e instalar softwares necessários](#1-atualizar-sistema-e-instalar-softwares-necessários)
  - [2. Configurar o Nginx para usar o diretório /projetos](#2-configurar-o-nginx-para-usar-o-diretório-projetos)
  - [3. Ajustar permissões do diretório `/projetos`](#3-ajustar-permissões-do-diretório-projetos)
  - [4. Serviço Nginx](#4-serviço-nginx)
  - [5. Testes](#5-testes)

**Obs**.: Considere que a VM já tenha um disco adicional configurado.

<br/>

*** 

## 1. Atualizar sistema e instalar softwares necessários

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y nginx curl
```

<br/>

*** 

## 2. Configurar o Nginx para usar o diretório /projetos

Será usado o diretório `/projetos` criados em [Instalar e configurar o Nginx](Configurar_Sistema_Operacional.md).

Crie novamente o arquivo `/etc/nginx/sites-available/projetos` com o conteúdo abaixo:

```bash
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;                 # O "_" responde por IP (qualquer host)

    root /projetos;
    index index.html index.htm;

    # roteia turmaXX/aluno/ automaticamente pelo sistema de arquivos
    location / {

        # Opção que não lista o conteúdo dos diretórios    
        autoindex off;
        try_files $uri $uri/ =404;
    }

    # bloqueia arquivos ocultos (.git, .env, .htpasswd, etc.)
    location ~ /\. {
        deny all;
    }
}
```

Crie um link simbólico do arquivo `/etc/nginx/sites-available/projetos` em `/etc/nginx/sites-enabled/`:

```bash
ln -s /etc/nginx/sites-available/projetos /etc/nginx/sites-enabled
```

<br/>

Remova o link simbólico da configuração padrão do Nginx:

```bash
rm /etc/nginx/sites-enabled/default
```

<br/>

Teste a configuração do Nginx

```bash
nginx -t
```

<br/>

Output:

```bash
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```
Obs.: Se a saída do comando for diferente, verifique a configuração do Nginx.

<br/>

*** 

## 3. Ajustar permissões do diretório `/projetos`

Permitir acesso total ao usuário `root` e leitura e execução para o usuário `www-data`:

```bash
chown root:www-data /projetos
chmod 750 /projetos
```
Obs.: `www-data` é o usuário padrão do Nginx. 

<br/>

*** 

## 4. Serviço Nginx

Habilitar e reiniciar o serviço do Nginx:

```bash
systemctl enable nginx.service
systemctl restart nginx.service
```

<br/>

Verifique o status do serviço do Nginx:

```bash
systemctl status nginx.service
```

<br/>

*** 

## 5. Testes

<br/>

Crie o arquivo `/projetos/index.html` para testar o Nginx


```bash
echo '<h1>Teste Site Default</h1>' > /projetos/index.html
```

<br/>

Use o comando `curl` para testar o acesso localmente.

```bash
curl localhost
```

Output:
```bash
Teste Site Default
```
Obs.: Se retornar a mensagem `Teste Site Default` significa que o Nginx está OK.

<br/>

Depois do teste, remova o arquivo:

```bash
rm /projetos/index.html
```