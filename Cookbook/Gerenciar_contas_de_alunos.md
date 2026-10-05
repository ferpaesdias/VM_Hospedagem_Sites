# Gerenciar contas de alunos

As contas de aluno podem ser criadas e removidas de duas formas:

- pelo **painel web** (veja [Instalar e configurar o Painel Web](Instalar_configurar_Painel_Web.md));
- pelo **script** `gerenciar_usuarios_ftp`, descrito neste guia.

O painel usa o mesmo script por baixo, então o resultado é idêntico.

Passos necessários:

- [Gerenciar contas de alunos](#gerenciar-contas-de-alunos)
  - [1. Instalar o script](#1-instalar-o-script)
  - [2. Criar contas](#2-criar-contas)
  - [3. Remover contas](#3-remover-contas)
  - [4. O que o script cria](#4-o-que-o-script-cria)
  - [5. Log e problemas comuns](#5-log-e-problemas-comuns)
  - [6. Teste completo](#6-teste-completo)

**Obs**.: Os comandos precisam de privilégios de root. Execute os comandos como `root` ou use o `sudo`.

**Obs**.: Para que cada conta receba também um banco de dados, instale o MariaDB **antes** de criar as contas, seguindo o guia [Instalar e configurar o MariaDB e o phpMyAdmin](Instalar_configurar_MariaDB_phpMyAdmin.md). Sem o MariaDB, o script cria apenas a conta e o site.

<br/>

***

## 1. Instalar o script

```bash
install -m 750 -o root -g root Cookbook/gerenciar_usuarios_ftp.sh /usr/local/sbin/gerenciar_usuarios_ftp
```

<br/>

Para ver a ajuda:

```bash
gerenciar_usuarios_ftp --help
```

<br/>

***

## 2. Criar contas

O login é a parte do e-mail antes do `@`, sem o ponto: `fulano.dsilva@escola.edu.br` vira `fulanodsilva`. Logins usam só letras minúsculas e números, começando por letra. Nomes de turma usam só letras e números.

<br/>

Um aluno:

```bash
gerenciar_usuarios_ftp --add turma01 fulanodsilva
```

<br/>

Vários alunos, a partir de um CSV no formato `turma,login` (veja o [exemplo_arquivo.csv](exemplo_arquivo.csv)):

```bash
gerenciar_usuarios_ftp --add-csv Cookbook/exemplo_arquivo.csv
```
- Aceita vírgula ou ponto e vírgula, como os CSV gerados pelo Excel.
- Ignora linhas vazias, comentários (`#`) e a linha de cabeçalho.
- Uma linha com erro não interrompe as outras: no final, o script mostra quantas linhas foram processadas e quantas falharam.

<br/>

Toda conta nova recebe a senha `123@mudar`. O painel obriga o aluno a trocá-la no primeiro acesso.

Criar de novo uma conta que já existe na mesma turma não altera a conta, os arquivos nem a senha do aluno. Se o MariaDB estiver instalado e a conta ainda não tiver banco de dados, o banco é criado.

<br/>

***

## 3. Remover contas

⚠️ Remover um aluno apaga a conta, **todos os arquivos do site** e **o banco de dados do aluno**, sem volta. Se for o último aluno da turma, a pasta da turma também é removida.

```bash
gerenciar_usuarios_ftp --rm turma01 fulanodsilva
gerenciar_usuarios_ftp --rm-csv Cookbook/exemplo_arquivo.csv
```

<br/>

No terminal, o script pede confirmação antes de remover. O script só remove contas de aluno da turma informada: contas de docentes e do sistema nunca são removidas. Se o aluno estiver conectado pelo FTP, a sessão é encerrada antes da remoção.

<br/>

***

## 4. O que o script cria

Para `--add turma01 fulanodsilva`:

| Item | Valor |
|---|---|
| Usuário Linux | `fulanodsilva`, com shell `/bin/shell_ftp` (sem acesso SSH) |
| Pasta da turma | `/projetos/turma01`, `root:www-data`, `751` |
| HOME e raiz do site | `/projetos/turma01/fulanodsilva`, `fulanodsilva:www-data`, `2750` |
| Pasta de gravação do PHP | `/projetos/turma01/fulanodsilva/uploads`, `fulanodsilva:www-data`, `2770` |
| Endereço do site | `http://[IP]/turma01/fulanodsilva/` |
| Banco de dados (se o MariaDB estiver instalado) | banco `fulanodsilva` e usuário `fulanodsilva`@`localhost`, com a senha `123@mudar` e permissão só nesse banco |

O shell `/bin/shell_ftp` é criado na primeira execução e registrado em `/etc/shells`, exigência do vsftpd para aceitar o login.

<br/>

***

## 5. Log e problemas comuns

Todas as ações ficam registradas em `/var/log/vm_hospedagem.log`:

```bash
tail -f /var/log/vm_hospedagem.log
```

<br/>

**"já existe um usuário fora deste padrão":** o login já pertence a um aluno de outra turma, a um docente ou a um usuário do sistema. Confira com `getent passwd login`.

**"a pasta já existe sem conta":** sobrou uma pasta de um aluno removido manualmente. Confira o conteúdo e apague com `rm -r /projetos/turma/login` antes de criar a conta.

**"o nome ... é reservado pelo MariaDB" ou "já existe um banco ... sem usuário de aluno":** a conta foi criada, mas o banco não. O login coincide com um banco do sistema (`mysql`, `sys`, `test`) ou com um banco de outra pessoa, que não pode ser entregue ao aluno. Confira com `mariadb -e "SHOW DATABASES;"` e, se o banco sobrar, remova-o à mão antes de executar o `--add` de novo.

**"não foi possível acessar o MariaDB":** o serviço está parado. Inicie com `systemctl start mariadb.service` e execute o `--add` de novo: o script cria só o banco que falta. Na remoção, o erro não impede a exclusão da conta; o log mostra o comando para apagar o banco à mão.

**O aluno apagou a pasta `uploads/`:** o painel não permite apagá-la, mas pelo FTP é possível. Recrie com:

```bash
mkdir /projetos/turma01/fulanodsilva/uploads
chown fulanodsilva:www-data /projetos/turma01/fulanodsilva/uploads
chmod 2770 /projetos/turma01/fulanodsilva/uploads
```

<br/>

***

## 6. Teste completo

Este teste confere, de uma vez, o Nginx, o PHP, o FTP e a conta de aluno.

Crie uma conta de teste:

```bash
gerenciar_usuarios_ftp --add turma01 teste
```

<br/>

Com o login `teste` e a senha `123@mudar`, envie pelo FTP (ou pelo painel, se já estiver instalado) **o conteúdo** da pasta [`exemplos/site-comemoracao/`](../exemplos/site-comemoracao) deste repositório: os arquivos `index.php`, `mural.php`, `sobre.php` e as pastas `inc` e `assets`. Não envie uma pasta `uploads`: ela já foi criada pelo script, com a permissão certa.

<br/>

Acesse `http://[IP]/turma01/teste/`. A página deve mostrar **"Deu certo!"** e 7 checagens aprovadas: Nginx, PHP-FPM, usuário do PHP, isolamento (`open_basedir`), pasta `uploads` gravável, sessões e data e hora em `America/Sao_Paulo`. Deixe um recado no mural para conferir a gravação em `uploads/`.

<br/>

Ao terminar, remova a conta de teste:

```bash
gerenciar_usuarios_ftp --rm turma01 teste
```