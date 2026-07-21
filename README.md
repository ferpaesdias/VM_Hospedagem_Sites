# VM para hospedagem de Sites

Configuração de uma VM para a hospedagem de sites pelos alunos. O envio os arquivos será via FTP.

<br/>

## Infraestrutura

- **Hostname**: vm-webserver
- **Hypervisor**: Hyper-V
- **Serviço WEB**: Nginx
- **Serviço FTP**: ProFTP

***
<br/>

## Características

- O acesso do site do aluno deverá ser:  `http://Endereço_IP_VM/Turma/Nome_Aluno`.

- Os arquivos dos sites deverão ser salvos em um disco montado no diretório `/sites`.
- Os arquivos dos sites deverão ser salvos no seguinte padrão: `/sites/turma/nome_aluno`.
- Os docentes terão acesso via SSH e acesso administrativo usando o `sudo`.
- Os alunos terão acesso somente ao seu diretório via FTP.
- Os alunos não terão acesso via SSH.
- Os usuários dos docentes (SSH e FTP) e dos alunos (FTP) serão o mesmo da primeira parte do e-mail educacional (sem o domínio), porém, sem o ponto separando o nome e sobrenome.

***
<br/>

## Passo-a-passo

- [ ] Subir uma VM Debian
- [ ] Instalar o Nginx
- [ ] Configurar o Nginx
- [ ] Configurar o FTP
  
***
<br/>

## Segurança 

- [ ] Sem acesso `root`, usar `sudo`.
- [ ] Desativar acesso SSH via `root`.
- [ ] Desativar acesso SSH via senha, usar chave criptográfica.  

