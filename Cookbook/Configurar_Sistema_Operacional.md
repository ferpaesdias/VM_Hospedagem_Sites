# Configurar o Sistema Operacional


## Atualizar Sistema Operacional

```bash
sudo apt update
sudo apt upgrade -y
```

<br/>

*** 

## Montar disco adicional

Considero que a VM já tenha um disco adicional configurado.

Criar o diretório `/sites`

```bash
sudo mkdir /sites
```

<br/>

Verificar se o disco foi reconhecido

```bash
sudo lsblk
```

<br/>

Output:
```bash
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   20G  0 disk 
├─sda1   8:1    0  966M  0 part /boot/efi
├─sda2   8:2    0   18G  0 part /
└─sda3   8:3    0    1G  0 part [SWAP]
sdb      8:16   0   10G  0 disk
```
O `sdb` é o nosso disco adicional.

<br/>

Para particionar o disco usaremos o `parted`:

```bash
sudo apt install parted -y
```

<br/>

O comando abaixo irá particionar o disco `/dev/sdb`. Altere para o seu disco.

```bash
sudo parted -s /dev/sdb mklabel msdos mkpart primary ext4 0% 100%
```
- `parted`: Comando que particiona o disco
- `-s`: Executa em modo silencioso (script), sem pedir confirmação e apagando os dados anteriores.
- `mklabel msdos`: Cria a tabela de partições no formato MS-DOS (MBR).
- `mkpart primary ext4 0% 100%`: Cria uma única partição primária ocupando 100% do disco e a identifica para o sistema de arquivos `ext4`.

