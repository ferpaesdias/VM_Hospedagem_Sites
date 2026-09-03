# VM para hospedagem de Sites

![Static Badge](https://img.shields.io/badge/No_AI-Made_By_Humans-blue?style=for-the-badge)
![Static Badge](https://img.shields.io/badge/Testes-Confia%20no%20pai-Green?style=for-the-badge)
![Static Badge](https://img.shields.io/badge/Trabalho_em_Progresso-Homem_trabalhando-red?style=for-the-badge)




Configuração de uma VM para a hospedagem de sites pelos alunos. O envio os arquivos será via FTP.

<br/>

## Infraestrutura

- **Sistema Operacional**: Debian 13 (Trixie)
- **Hostname**: vm-webserver
- **Hypervisor**: Hyper-V
- **Serviço WEB**: Nginx
- **Serviço FTP**: vsftpd


<br/>

***

## Características

- O acesso do site do aluno deverá ser:  `http://[IP]/Turma[XX]/Nome_Aluno`.
- Os arquivos dos sites deverão ser salvos em um disco montado no diretório `/projetos`.
- Os arquivos dos sites deverão ser salvos no seguinte padrão: `/projetos/turma[XX]/nome_aluno`.
- Cada aluno terá o seu usuário no Linux. Este usuário não terá shell e o diretório HOME será `/projetos/turma[XX]/nome_aluno`. 
- Os docentes terão acesso via SSH e acesso administrativo usando o `sudo`.
- Os alunos terão acesso somente ao seu diretório via FTP.
- Os alunos não terão acesso via SSH.
- Os usuários dos docentes (SSH e FTP) e dos alunos (FTP) serão o mesmo da primeira parte do e-mail educacional (sem o domínio), porém, sem o ponto separando o nome e sobrenome.

<br/>

***

## Cookbook

- [Configurar o Sistema Operacional](Cookbook/Configurar_Sistema_Operacional.md).
- [Instalar e configurar o Nginx](Cookbook/Instalar_configurar_Nginx.md).
- [Instalar e configurar o FTP](Cookbook/Instalar_configurar_FTP.md).
- Criar, modificar e remover usuários do Linux (somente docentes).
- Criar, modificar e remover usuários do FTP (docentes e alunos).
  
<br/>

***
