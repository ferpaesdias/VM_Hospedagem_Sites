## Configuração do Sistema Operacional

Neste diretório estão os scripts necessários para preparar o sistema operacional antes dos demais passos.


## 1. Configurar um disco adicional

script: `particionar_disco.sh`

Este script é **idempotente**. Ou seja, ele pode ser executado várias vezes seguidas produzindo o mesmo resultado final.

O script particiona um disco para ser usado nos projetos dos alunos. Facilita o backup dos projetos e caso precise reinstalar o servidor. 
Está etapa é opcional, porém, altamente recomendada. 

Leia o cabeçalho do script antes de executá-lo. Esteja ciente que o script pode particionar o disco errado e perder arquivos importantes.