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
