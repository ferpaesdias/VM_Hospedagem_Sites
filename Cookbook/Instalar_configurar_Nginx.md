# Instalar e configurar o Nginx


Passos necessários:

- [Instalar e configurar o Nginx](#instalar-e-configurar-o-nginx)
  - [1. Atualizar sistema e instalar softwares necessários](#1-atualizar-sistema-e-instalar-softwares-necessários)
  - [2. Configurar o Nginx para usar o diretório /projetos](#2-configurar-o-nginx-para-usar-o-diretório-projetos)

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

Crie o arquivo `/etc/nginx/sites-available/projetos`

<br/>

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

<br/>

Crie o arquivo `/sites/index.html` para testar o Nginx


```bash
sudo echo "Teste Site Default" | sudo tee /sites/index.html
```

<br/>

Use o comando `curl` para testar o acesso localmente.


```bash
$ curl localhost
Teste Site Default
```

Se retornar a mensagem `Teste Site Default` significa que o Nginx está OK.
