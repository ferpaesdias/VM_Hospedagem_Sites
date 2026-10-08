# Instalar e configurar o MariaDB e o phpMyAdmin

Cada aluno recebe **um banco de dados próprio** e um usuário do banco, ambos com o nome do login. O usuário só enxerga o próprio banco. O aluno gerencia o banco pelo **phpMyAdmin** e o site dele (PHP) se conecta ao MariaDB por `localhost`.

O banco é criado pelo script `gerenciar_usuarios_ftp` (veja [Gerenciar contas de alunos](Gerenciar_contas_de_alunos.md)) quando o MariaDB está instalado. Por isso, siga este guia **antes** de criar as contas dos alunos.

Passos necessários:

- [Instalar e configurar o MariaDB e o phpMyAdmin](#instalar-e-configurar-o-mariadb-e-o-phpmyadmin)
  - [1. Instalar softwares necessários](#1-instalar-softwares-necessários)
  - [2. Proteger o MariaDB](#2-proteger-o-mariadb)
  - [3. Configurar o phpMyAdmin](#3-configurar-o-phpmyadmin)
  - [4. Configurar o Nginx](#4-configurar-o-nginx)
  - [5. Serviços](#5-serviços)
  - [6. Banco de dados dos alunos](#6-banco-de-dados-dos-alunos)
  - [7. Testes](#7-testes)
  - [8. Como o aluno usa o banco no site](#8-como-o-aluno-usa-o-banco-no-site)

**Obs**.: Execute os comandos a partir da raiz deste repositório. Os dois arquivos de configuração ficam na pasta [`config/`](../config) e são copiados prontos, sem edição.   

**Obs**.: Os comandos precisam de privilégios de root. Execute os comandos como `root` ou use o `sudo`.

**Obs**.: Este guia continua o [Instalar e configurar o Nginx e o PHP](Instalar_configurar_Nginx_PHP.md): o PHP-FPM e a extensão `php-mysql` já foram instalados lá.

<br/>

***

## 1. Instalar softwares necessários

```bash
apt update
apt upgrade -y
apt install -y mariadb-server
```
- `mariadb-server`: servidor de banco de dados.

<br/>

Confirme que o pacote do phpMyAdmin existe nos repositórios:

```bash
apt-cache policy phpmyadmin
```

<br/>

Instale o phpMyAdmin sem o Apache e sem o assistente de banco de dados do pacote:

```bash
echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends phpmyadmin
```
- `--no-install-recommends`: o Apache é um pacote recomendado do phpMyAdmin. Sem esta opção, ele seria instalado junto e brigaria com o Nginx pela porta 80.
- `dbconfig-install false`: não cria o banco `phpmyadmin` (armazenamento de configurações), que os alunos não usam.
- `reconfigure-webserver` vazio: o pacote não tenta configurar nenhum servidor web.

Os arquivos do phpMyAdmin ficam em `/usr/share/phpmyadmin` e as configurações, em `/etc/phpmyadmin`.

<br/>

***

## 2. Proteger o MariaDB

```bash
mariadb-secure-installation
```

Respostas recomendadas:
- Senha atual do `root`: apenas `Enter`.
- Trocar para autenticação `unix_socket`: **n** (o `root` já entra pelo `unix_socket`, sem senha, com `sudo mariadb`).
- Trocar a senha do `root`: **n**.
- Remover usuários anônimos: **Y**.
- Desabilitar o login remoto do `root`: **Y**.
- Remover o banco `test`: **Y**.
- Recarregar as tabelas de privilégios: **Y**.

<br/>

Confirme que o MariaDB escuta **somente** em `127.0.0.1`:

```bash
ss -tlnp | grep 3306
```

Output:

```bash
LISTEN 0      80         127.0.0.1:3306       0.0.0.0:*    users:(("mariadbd",pid=1234,fd=22))
```
- Se aparecer `0.0.0.0:3306`, o banco está aberto para a rede. Confira o parâmetro `bind-address` em `/etc/mysql/mariadb.conf.d/50-server.cnf`.

<br/>

***

## 3. Configurar o phpMyAdmin

Copie o arquivo [`config/phpmyadmin.php`](../config/phpmyadmin.php) para a pasta `conf.d/` do phpMyAdmin. Ele é lido no final do `config.inc.php` e não é sobrescrito nas atualizações do pacote:

```bash
cp config/phpmyadmin.php /etc/phpmyadmin/conf.d/99-hospedagem.php
```

<br/>

Conteúdo do arquivo:

```php
<?php
// /etc/phpmyadmin/conf.d/99-hospedagem.php
// Lido pelo phpMyAdmin no final do config.inc.php e preservado nas atualizações.
//
// O servidor é indicado pelo número 1 e não pela variável $i: quando este arquivo
// é carregado, o config.inc.php do pacote já avançou o $i para 2, e as opções
// seriam aplicadas a um servidor que não existe.

// Aceita somente o login dos alunos: o root do MariaDB e contas sem senha ficam bloqueados.
$cfg['Servers'][1]['AllowRoot'] = false;
$cfg['Servers'][1]['AllowNoPassword'] = false;

// Esconde os bancos do sistema. A proteção de verdade vem dos GRANTs: cada aluno só acessa o próprio banco.
$cfg['Servers'][1]['hide_db'] = '^(information_schema|performance_schema|mysql|sys)$';

// Sem armazenamento de configurações do phpMyAdmin (banco "phpmyadmin"):
// o aluno não precisa dele, e o pacote deixa um usuário de controle sem senha configurado.
$cfg['Servers'][1]['controluser'] = '';
$cfg['Servers'][1]['controlpass'] = '';
$cfg['Servers'][1]['pmadb'] = '';

// Não mostra dados do servidor na tela inicial nem consulta novas versões na internet.
$cfg['ShowServerInfo'] = false;
$cfg['VersionCheck'] = false;
```
- O `root` do MariaDB usa o `unix_socket` e não faz login por senha. Mesmo assim, o `AllowRoot` impede qualquer tentativa pelo navegador.
- O `hide_db` só esconde os bancos do sistema na tela. Quem impede o acesso de verdade são as permissões do usuário de cada aluno.

<br/>

***

## 4. Configurar o Nginx

O phpMyAdmin ficará em um `server` próprio, na **porta 8081**, no endereço `/_phpmyadmin/`. As duas escolhas protegem a sessão do phpMyAdmin do código que os alunos enviam:

- **Porta própria:** é outra origem para o navegador, então os sites dos alunos (porta 80) não conseguem usar a sessão do phpMyAdmin. É o mesmo cuidado do painel web, na porta 8080.
- **Endereço `/_phpmyadmin/`:** os cookies não separam portas, e o navegador enviaria o cookie do phpMyAdmin também aos sites dos alunos. Com o cookie restrito ao caminho `/_phpmyadmin/`, ele nunca é enviado a um site de aluno, pois turma e aluno usam só letras e números e nunca começam com `_`.

<br/>

Copie o arquivo [`config/nginx-phpmyadmin`](../config/nginx-phpmyadmin) e ative-o:

```bash
cp config/nginx-phpmyadmin /etc/nginx/sites-available/phpmyadmin
ln -s /etc/nginx/sites-available/phpmyadmin /etc/nginx/sites-enabled/
```

<br/>

Conteúdo do arquivo:

```nginx
# /etc/nginx/sites-available/phpmyadmin
# phpMyAdmin em porta própria (8081), no endereço /_phpmyadmin/.
#   - Porta própria: outra origem para o navegador, então os sites dos alunos
#     (porta 80) não conseguem usar a sessão do phpMyAdmin.
#   - Endereço /_phpmyadmin/: o cookie de sessão só vale para esse caminho.
#     Os cookies não separam portas, mas nenhum site de aluno começa com "_"
#     (turma e aluno usam só letras e números).

server {
    listen 8081;
    listen [::]:8081;

    server_name _;

    # Importação de arquivos .sql (igual ao upload_max_filesize do PHP)
    client_max_body_size 20M;

    location = /               { return 301 /_phpmyadmin/; }
    location = /_phpmyadmin    { return 301 /_phpmyadmin/; }

    location ^~ /_phpmyadmin/ {
        alias /usr/share/phpmyadmin/;
        index index.php;

        # Bloqueia arquivos ocultos e as pastas internas do phpMyAdmin
        location ~ /\. {
            deny all;
        }
        location ~ ^/_phpmyadmin/(libraries|templates|setup)/ {
            deny all;
        }

        # Com "alias", o caminho do script é informado de forma explícita.
        #   open_basedir:        pastas do pacote phpmyadmin (as mesmas do /etc/phpmyadmin/apache.conf)
        #                        mais /tmp (importação de arquivos) e as sessões do PHP
        #   session.cookie_path: o cookie de sessão vale só para o /_phpmyadmin/
        # Os dois valores precisam ser definidos em TODA requisição: o PHP-FPM mantém os
        # valores da requisição anterior do mesmo processo, inclusive os dos sites dos alunos.
        # A quebra de linha dentro das aspas separa as duas diretivas.
        location ~ ^/_phpmyadmin/(.+\.php)$ {
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME /usr/share/phpmyadmin/$1;
            fastcgi_param PHP_ADMIN_VALUE "open_basedir=/usr/share/phpmyadmin/:/usr/share/doc/phpmyadmin/:/etc/phpmyadmin/:/var/lib/phpmyadmin/:/usr/share/php/:/usr/share/javascript/:/tmp/:/var/lib/php/sessions/
session.cookie_path=/_phpmyadmin/";
            fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        }
    }

    location / {
        return 404;
    }
}
```
- O `client_max_body_size 20M` combina com o `upload_max_filesize` do [`config/php-hospedagem.ini`](../config/php-hospedagem.ini): o aluno importa arquivos `.sql` de até 20 MB.
- Os valores do `open_basedir` são os mesmos do arquivo `/etc/phpmyadmin/apache.conf`, que o pacote instala para o Apache. Para conferir na sua versão:

```bash
grep open_basedir /etc/phpmyadmin/apache.conf
```

<br/>

Teste a configuração:

```bash
nginx -t
```

Output:

```bash
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

<br/>

***

## 5. Serviços

Habilitar o MariaDB e recarregar o Nginx:

```bash
systemctl enable mariadb.service
systemctl reload nginx.service
```

<br/>

Verifique o status:

```bash
systemctl status mariadb.service nginx.service
```

<br/>

***

## 6. Banco de dados dos alunos

Para cada conta de aluno, o script `gerenciar_usuarios_ftp` cria:

| Item | Valor |
|---|---|
| Banco de dados | `fulanodsilva` |
| Usuário do banco | `fulanodsilva`@`localhost` |
| Senha inicial | `123@mudar` |
| Permissões | todas, **somente** no banco `fulanodsilva` |
| Conexões simultâneas | até 5 |

- A senha do banco é **independente** da senha do FTP e do painel: quando o aluno troca uma, a outra não muda. O aluno troca a senha do banco no phpMyAdmin, na tela inicial, em **Alterar senha** (*Change password*).
- O botão **Redefinir senha** do painel web (docentes) volta **as duas** senhas para `123@mudar`: a do painel e do FTP e a do banco. Se o site do aluno usa outra senha do banco no PHP, ele precisa atualizá-la. Se o aluno ainda não tinha banco (conta criada antes do MariaDB), o painel o cria.
- Remover a conta do aluno com `gerenciar_usuarios_ftp --rm` apaga também o banco e o usuário do banco.
- Contas criadas **antes** da instalação do MariaDB não têm banco. Para criá-lo, execute o `--add` de novo (ou o `--add-csv`): o script não altera a conta nem a senha de quem já existe, apenas completa o banco que falta.

<br/>

Comandos úteis para o docente:

```bash
# Bancos de dados dos alunos
mariadb -e "SHOW DATABASES;"

# Permissões de um aluno
mariadb -e "SHOW GRANTS FOR 'fulanodsilva'@'localhost';"

# Voltar só a senha do banco de um aluno para a inicial (sem mexer na senha do painel e do FTP)
mariadb -e "ALTER USER 'fulanodsilva'@'localhost' IDENTIFIED BY '123@mudar';"
```

<br/>

**Obs**.: Os bancos ficam em `/var/lib/mysql`, no disco do sistema, e **não** no disco de `/projetos`. Para fazer cópia de segurança de todos os bancos:

```bash
mariadb-dump --all-databases > backup_bancos.sql
```

<br/>

***

## 7. Testes

Crie uma conta de aluno de teste. Como o MariaDB já está instalado, o banco é criado junto:

```bash
Cookbook/gerenciar_usuarios_ftp --add turma01 teste
```

Output:

```bash
turma01/teste: conta criada. Senha inicial: 123@mudar
turma01/teste: banco de dados criado.
```

<br/>

O aluno só tem permissão no próprio banco (o formato da saída pode variar um pouco conforme a versão do MariaDB):

```bash
mariadb -e "SHOW GRANTS FOR 'teste'@'localhost';"
```

Output:

```bash
Grants for teste@localhost
GRANT USAGE ON *.* TO `teste`@`localhost` IDENTIFIED BY PASSWORD '*C421959517F6C02981BF4B7A6CBCC1CE2ED5E539' WITH MAX_USER_CONNECTIONS 5
GRANT ALL PRIVILEGES ON `teste`.* TO `teste`@`localhost`
```

<br/>

O phpMyAdmin responde e o cookie vale só para `/_phpmyadmin/`:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8081/_phpmyadmin/
curl -s -D - -o /dev/null http://localhost:8081/_phpmyadmin/ | grep -i set-cookie
```

Output:

```bash
200
Set-Cookie: pma_lang=en; expires=...; Max-Age=2592000; path=/_phpmyadmin/; HttpOnly; SameSite=Strict
Set-Cookie: phpMyAdmin=...; path=/_phpmyadmin/; HttpOnly; SameSite=Strict
```
- Todos os cookies devem ter `path=/_phpmyadmin/`.

<br/>

Crie uma página PHP no site do aluno de teste, que usa o banco:

```bash
cat > /projetos/turma01/teste/teste_banco.php << 'PHP'
<?php
$pdo = new PDO(
    'mysql:host=localhost;dbname=teste;charset=utf8mb4',
    'teste',
    '123@mudar',
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);
echo 'Conexão OK. Banco: ', $pdo->query('SELECT DATABASE()')->fetchColumn(), "\n";
PHP
chown teste:www-data /projetos/turma01/teste/teste_banco.php
chmod 640 /projetos/turma01/teste/teste_banco.php
curl http://localhost/turma01/teste/teste_banco.php
```

Output:

```bash
Conexão OK. Banco: teste
```

<br/>

Teste o login pelo navegador. Acesse `http://[IP]:8081/` com o usuário `teste` e a senha `123@mudar`. Deve aparecer **somente** o banco `teste`, sem os bancos do sistema. O login do usuário `root` deve ser recusado.

<br/>

Ao terminar, remova a conta de teste (o banco e o usuário do banco são removidos junto):

```bash
Cookbook/gerenciar_usuarios_ftp --rm turma01 teste
```

Output:

```bash
turma01/teste: banco de dados removido.
turma01/teste: conta e arquivos removidos.
```

<br/>

***

## 8. Como o aluno usa o banco no site

Dados de conexão que o aluno usa no PHP:

| Dado | Valor |
|---|---|
| Servidor | `localhost` |
| Banco | o próprio login, por exemplo `fulanodsilva` |
| Usuário | o próprio login |
| Senha | a do banco (inicial `123@mudar`; troque no phpMyAdmin) |
| Gerenciamento | `http://[IP]:8081/` (o painel web também mostra o link, os dados de conexão e um exemplo de código na seção **Banco de dados**) |

<br/>

Exemplo de conexão com `PDO`:

```php
<?php
$pdo = new PDO(
    'mysql:host=localhost;dbname=fulanodsilva;charset=utf8mb4',
    'fulanodsilva',
    'SENHA_DO_BANCO',
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

// Sempre use consultas preparadas para valores vindos de formulários
$consulta = $pdo->prepare('INSERT INTO recados (texto) VALUES (?)');
$consulta->execute([$_POST['texto']]);
```

<br/>

Recomendações para os alunos:

- Guarde a senha do banco em um arquivo `.php` (por exemplo `conexao.php`). O Nginx **executa** o `.php` e nunca mostra o conteúdo. Um arquivo `.txt`, `.inc` ou `.sql` na pasta do site é **público** e pode ser baixado por qualquer pessoa.
- Para criar as tabelas, use a aba **SQL** ou **Importar** do phpMyAdmin. Depois de importar, apague o arquivo `.sql` da pasta do site.
- O MariaDB só aceita conexões da própria VM. Programas no computador do aluno (como o MySQL Workbench) não conseguem se conectar: o acesso externo é somente pelo phpMyAdmin.
