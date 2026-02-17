# Plan: Add --insecure flag to download-ohmyposh-binaries.sh

## Context

При скачивании бинарников Oh My Posh через корпоративный прокси с TLS-инспекцией возникает ошибка:
`curl: (35) TLS connect error: error:0B09406F:x509 certificate routines:x509_pubkey_decode:unsupported algorithm`

Нужно добавить флаг `--insecure`, который передаёт `-k` в curl для отключения проверки TLS.

## File to Modify

`scripts/download-ohmyposh-binaries.sh`

## Changes

### 1. Обновить usage/help в начале скрипта (строки 1-5)
```
# Usage: ./scripts/download-ohmyposh-binaries.sh [--insecure] VERSION
# Example: ./scripts/download-ohmyposh-binaries.sh v24.19.2
# Example: ./scripts/download-ohmyposh-binaries.sh --insecure v24.19.2
```

### 2. Добавить парсинг флага `--insecure` перед проверкой VERSION
```bash
INSECURE=""
for arg in "$@"; do
    if [[ "$arg" == "--insecure" ]]; then
        INSECURE="-k"
    else
        VERSION="$arg"
    fi
done
```

### 3. Добавить предупреждение при использовании --insecure
```bash
if [[ -n "$INSECURE" ]]; then
    echo "Warning: TLS verification disabled (--insecure)"
    echo ""
fi
```

### 4. Добавить $INSECURE в вызов curl (строка 42)
```bash
if curl $INSECURE -fsSL "$url" -o "$target"; then
```

## Verification

```bash
# Проверить синтаксис
bash -n scripts/download-ohmyposh-binaries.sh

# Запустить с флагом
./scripts/download-ohmyposh-binaries.sh --insecure v24.19.2

# Установить после скачивания
./iclaude.sh --install-posh
```
