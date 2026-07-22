# Configurar o Sistema Operacional


Passos necessários:

1. Atualizar sistema e instalar softwares necessários
2. Particionar disco
3. Formatar disco
4. Montar disco

**Obs**.: Considere que a VM já tenha um disco adicional configurado.

<br/>

*** 

## 1. Atualizar sistema e instalar softwares necessários

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y parted
```
- `parted`: Particionador de discos.

<br/>

*** 

## 2. Particionar disco

Verifique se o disco adicional foi reconhecido

```bash
$ sudo lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   20G  0 disk 
├─sda1   8:1    0  966M  0 part /boot/efi
├─sda2   8:2    0   18G  0 part /
└─sda3   8:3    0    1G  0 part [SWAP]
sdb      8:16   0   10G  0 disk 
```
O `sdb` é o nosso disco adicional.

<br/>

O comando abaixo irá particionar o disco `/dev/sdb`. 

```bash
sudo parted -s /dev/sdb mklabel msdos mkpart primary ext4 0% 100%
```
- `parted`: Comando que particiona o disco
- `-s`: Executa em modo silencioso (script), sem pedir confirmação e apagando os dados anteriores.
- `mklabel msdos`: Cria a tabela de partições no formato MS-DOS (MBR).
- `mkpart primary ext4 0% 100%`: Cria uma única partição primária ocupando 100% do disco e a identifica para o sistema de arquivos `ext4`.

<br/>

Execute o comando `lsblk` novamente

```bash
$ sudo lsblk 
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   20G  0 disk 
├─sda1   8:1    0  966M  0 part /boot/efi
├─sda2   8:2    0   18G  0 part /
└─sda3   8:3    0    1G  0 part [SWAP]
sdb      8:16   0   10G  0 disk 
└─sdb1   8:17   0   10G  0 part
```
A partição `sdb1` foi criada.

<br/>

*** 

## 3. Formatar disco

Formate o disco com o sistema de arquivos `ext4`.

```bash
$ sudo mkfs.ext4 /dev/sdb1
mke2fs 1.47.2 (1-Jan-2025)
Creating filesystem with 2621184 4k blocks and 655360 inodes
Filesystem UUID: efd587fd-f003-4568-b230-0a21b9c45076
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done 
```

<br/>

*** 

## 4. Montar disco

Crie o diretório `/sites`

```bash
sudo mkdir /sites
```

<br/>

Monte o disco no diretório `/sites` de forma provisória para teste:

```bash
sudo mount /dev/sdb1 /sites
```

<br/>

Verifique se o disco foi montado:

```bash
$ sudo df -h
Sist. Arq.      Tam. Usado Disp. Uso% Montado em
udev            937M     0  937M   0% /dev
tmpfs           196M  592K  195M   1% /run
/dev/sda2        18G  1,3G   16G   8% /
...
/dev/sdb1       9,8G  2,1M  9,3G   1% /sites
```
Tem que aparecer um linha semelhante a `/dev/sdb1       9,8G  2,1M  9,3G   1% /sites`.

<br/>

Desmonte o disco para o montarmos de forma permanente:
```bash
sudo umount /dev/sdb1 
```

<br/>

### Montar o disco de forma permanente

Execute o comando `blkid` para descobrir o **UUID** da partição

```bash
$ sudo blkid
/dev/sdb1: UUID="efd587fd-f003-4568-b230-0a21b9c45076" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="f8291f20-01"
/dev/sda2: UUID="d6b90fad-ab92-4a64-bfba-5ab228a6510d" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="66ec5a7f-0b37-4809-8eae-9f3e09ea8d87"
/dev/sda3: UUID="0e670e65-5581-4b3f-8ddc-1495075400d8" TYPE="swap" PARTUUID="30e05d6e-3aa0-497b-8e66-e39ac14f2126"
/dev/sda1: UUID="B65D-E353" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="5b1a3ab4-2b20-4a23-be23-cadb80345b28"
```

A saída do comando mostra que o **UUID** da partição `/dev/sdb1` é: `efd587fd-f003-4568-b230-0a21b9c45076`. 

<br/>

Abra o arquivo `/etc/fstab` e adicione a linha `UUID=efd587fd-f003-4568-b230-0a21b9c45076  /sites  ext4  errors=remount-ro  0  1` no final do arquivo.

```bash
# /etc/fstab: static file system information.
...
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/sda2 during installation
UUID=d6b90fad-ab92-4a64-bfba-5ab228a6510d  /  ext4  errors=remount-ro  0  1
# /boot/efi was on /dev/sda1 during installation
UUID=B65D-E353   /boot/efi  vfat  umask=0077  0  1
# swap was on /dev/sda3 during installation
UUID=0e670e65-5581-4b3f-8ddc-1495075400d8 none  swap  sw  0  0

# Partição do diretório /sites
UUID=efd587fd-f003-4568-b230-0a21b9c45076  /sites  ext4  defaults,nofail  0  1
```
- `UUID=efd587fd-f003-4568-b230-0a21b9c45076`: UUID da partição `/dev/sdb1`.
- `/sites`: O diretório onde a partição será montada.
- `ext4`: Sistema de arquivos da partição.
- `defaults,nofail 0 1`: Opções da partição. [Manual do fstab](https://man7.org/linux/man-pages/man5/fstab.5.html).

<br/>

Monte a partição:

```bash
sudo systemctl daemon-reload
sudo mount -a
```

<br/>

Execute o  comando `df -h`:
```bash
$ df -h
Sist. Arq.      Tam. Usado Disp. Uso% Montado em
udev            937M     0  937M   0% /dev
tmpfs           196M  600K  195M   1% /run
/dev/sda2        18G  1,3G   16G   8% /
...
/dev/sdb1       9,8G  2,1M  9,3G   1% /sites
```
Novamente, tem que aparecer um linha semelhante a `/dev/sdb1       9,8G  2,1M  9,3G   1% /sites`.

