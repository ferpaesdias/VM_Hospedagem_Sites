# Instalar e configurar o Nginx


Passos necessários:

- [Instalar e configurar o Nginx](#instalar-e-configurar-o-nginx)
  - [1. Atualizar sistema e instalar softwares necessários](#1-atualizar-sistema-e-instalar-softwares-necessários)
  - [2. Configurar o Nginx para usar o diretório /sites](#2-configurar-o-nginx-para-usar-o-diretório-sites)

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

## 2. Configurar o Nginx para usar o diretório /sites

Renomeie o arquivo `/etc/nginx/sites-available/default`

```bash
sudo mv -v /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bkp
```

<br/>

Crie novamente o arquivo `/etc/nginx/sites-available/default` com o conteúdo abaixo:

```bash
server {
        listen 80 default_server;
        listen [::]:80 default_server;

        root /sites;

        index index.html index.htm index.nginx-debian.html;

        server_name _;

        location / {
                try_files $uri $uri/ =404;
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

Se retornar a mensagem `Teste Site Default` siginifica que o Nginx está OK.
