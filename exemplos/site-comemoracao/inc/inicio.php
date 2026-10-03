<?php
/*
 * Inicialização comum a todas as páginas: sessão, funções e checagens.
 * Este arquivo é incluído pelas páginas; sozinho ele não mostra nada.
 */
declare(strict_types=1);

define('APP', true);
date_default_timezone_set('America/Sao_Paulo');

const MAX_RECADOS = 200;
const PASTA_DADOS = __DIR__ . '/../uploads';

/** Escapa texto para exibir com segurança no HTML. */
function h(mixed $v): string
{
    return htmlspecialchars((string) $v, ENT_QUOTES, 'UTF-8');
}

/** Caminho público do site: /turma/aluno/ */
function caminho_site(): string
{
    $partes = explode('/', trim(dirname($_SERVER['SCRIPT_NAME'] ?? '/'), '/'));
    $partes = array_slice(array_filter($partes, 'strlen'), 0, 2);
    return '/' . implode('/', $partes) . (count($partes) ? '/' : '');
}

/** [turma, aluno] a partir do caminho do site. */
function turma_aluno(): array
{
    $partes = array_values(array_filter(explode('/', caminho_site()), 'strlen'));
    return [$partes[0] ?? '?', $partes[1] ?? '?'];
}

/**
 * Conta caracteres de um texto UTF-8 sem depender da extensão mbstring.
 * Devolve -1 se o texto não for UTF-8 válido.
 */
function comprimento(string $texto): int
{
    $n = preg_match_all('/./us', $texto);
    return $n === false ? -1 : $n;
}

function pasta_dados_ok(): bool
{
    return is_dir(PASTA_DADOS) && is_writable(PASTA_DADOS);
}

/**
 * Lê e altera um arquivo JSON de uploads/ com trava (flock),
 * para dois visitantes ao mesmo tempo não corromperem o arquivo.
 */
function alterar_json(string $nome, mixed $padrao, callable $alterar): mixed
{
    $arquivo = PASTA_DADOS . '/' . $nome;
    $fp = @fopen($arquivo, 'c+');
    if ($fp === false) {
        return null;
    }
    try {
        flock($fp, LOCK_EX);
        $conteudo = stream_get_contents($fp);
        $dados = $conteudo ? json_decode($conteudo, true) : null;
        $dados ??= $padrao;
        $novo = $alterar($dados);
        if ($novo !== $dados) {
            ftruncate($fp, 0);
            rewind($fp);
            fwrite($fp, json_encode($novo, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
            fflush($fp);
        }
        return $novo;
    } finally {
        flock($fp, LOCK_UN);
        fclose($fp);
    }
}

function ler_json(string $nome, mixed $padrao): mixed
{
    $arquivo = PASTA_DADOS . '/' . $nome;
    if (!is_file($arquivo)) {
        return $padrao;
    }
    $dados = json_decode((string) @file_get_contents($arquivo), true);
    return $dados ?? $padrao;
}

/** Token contra envio de formulários a partir de outros sites. */
function token_csrf(): string
{
    $_SESSION['csrf'] ??= bin2hex(random_bytes(16));
    return $_SESSION['csrf'];
}

function csrf_valido(?string $token): bool
{
    return is_string($token) && isset($_SESSION['csrf']) && hash_equals($_SESSION['csrf'], $token);
}

/**
 * Soma uma visita ao contador (uploads/contador.json) e devolve o total.
 * Devolve null se a pasta uploads não aceitar gravação.
 */
function registrar_visita(): ?int
{
    if (!pasta_dados_ok()) {
        return null;
    }
    $dados = alterar_json('contador.json', ['visitas' => 0], function (array $d) {
        $d['visitas'] = (int) ($d['visitas'] ?? 0) + 1;
        return $d;
    });
    return $dados === null ? null : (int) $dados['visitas'];
}

/** Total de visitas, só para exibir (não soma). */
function total_visitas(): ?int
{
    $dados = ler_json('contador.json', null);
    return is_array($dados) ? (int) ($dados['visitas'] ?? 0) : null;
}

/**
 * Checagens ao vivo da configuração do servidor.
 * Cada item: [ok (bool|null), título, detalhe]. null = não deu para conferir.
 */
function checagens(): array
{
    $itens = [];

    $software = $_SERVER['SERVER_SOFTWARE'] ?? '';
    $itens[] = [
        stripos($software, 'nginx') !== false ? true : null,
        'Nginx entregou esta página',
        $software !== '' ? $software : 'O servidor não informou o nome.',
    ];

    $sapi = php_sapi_name();
    $itens[] = [
        $sapi === 'fpm-fcgi',
        'PHP rodando pelo PHP-FPM',
        'PHP ' . PHP_VERSION . ' — interface ' . $sapi,
    ];

    if (function_exists('posix_geteuid') && function_exists('posix_getpwuid')) {
        $usuario = posix_getpwuid(posix_geteuid())['name'] ?? (string) posix_geteuid();
        $itens[] = [true, 'Processo do PHP', "Usuário {$usuario}"];
    }

    $basedir = (string) ini_get('open_basedir');
    $isolado = $basedir !== '' && @is_readable('/etc/passwd') === false;
    $itens[] = [
        $isolado,
        'Isolamento entre alunos (open_basedir)',
        $isolado ? 'O PHP deste site só enxerga a própria pasta.' : 'Sem open_basedir: o PHP enxerga pastas de outros alunos.',
    ];

    $gravavel = pasta_dados_ok();
    $itens[] = [
        $gravavel,
        'Pasta uploads gravável',
        $gravavel ? 'O PHP consegue salvar arquivos em uploads/.' : 'Crie a pasta uploads/ com permissão de escrita para o grupo.',
    ];

    $sessao = session_status() === PHP_SESSION_ACTIVE;
    $itens[] = [
        $sessao,
        'Sessões funcionando',
        $sessao ? 'Você abriu ' . $_SESSION['paginas'] . ' página(s) nesta sessão.' : 'A sessão não iniciou.',
    ];

    $itens[] = [true, 'Data e hora do servidor', date('d/m/Y \à\s H:i') . ' (' . date_default_timezone_get() . ')'];

    return $itens;
}

/*
 * Sessão exclusiva deste site.
 * Por padrão o PHP usa o cookie PHPSESSID com caminho "/", e o navegador
 * envia o MESMO cookie para os sites de todos os alunos. Aqui o cookie
 * tem nome próprio e vale só para /turma/aluno/.
 */
if (ini_get('session.cookie_path') !== caminho_site()) {   // o servidor ainda não isola
    session_name('sessao_' . hash('crc32b', caminho_site()));
    session_set_cookie_params([
        'path'     => caminho_site(),
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
}
session_start();
$_SESSION['paginas'] = ($_SESSION['paginas'] ?? 0) + 1;
