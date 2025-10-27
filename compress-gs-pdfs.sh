#!/bin/bash
# (c) Alexander Kostritsky 2024
# Жулик, не воруй мои скрептосы
# Ну ладно, немножко можешь
# Я их тоже свiрiвiв

usage() {
    echo "Использование: $0 [--check] <путь_к_папке>"
    exit 1
}

# Разбор аргументов
CHECK_MODE=false
SOURCE_DIR=""

if [ "$1" = "--check" ]; then
    CHECK_MODE=true
    if [ $# -ne 2 ]; then
        usage
    fi
    SOURCE_DIR="$2"
else
    if [ $# -ne 1 ]; then
        usage
    fi
    SOURCE_DIR="$1"
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Ошибка: директория '$SOURCE_DIR' не существует."
    exit 1
fi

errors_found=false

while IFS= read -r -d '' pdf_file; do
    echo "Обработка: $pdf_file"

    # Определяем размер оригинала
    if stat -f%z "$pdf_file" &>/dev/null; then
        original_size=$(stat -f%z "$pdf_file")
    elif stat -c%s "$pdf_file" &>/dev/null; then
        original_size=$(stat -c%s "$pdf_file")
    else
        echo "  Пропуск: не удалось определить размер."
        continue
    fi

    if [ -z "$original_size" ] || [ "$original_size" -eq 0 ]; then
        echo "  Пропуск: размер файла нулевой или не определён."
        continue
    fi

    # Временный файл для сжатой версии
    tmp_file=$(mktemp --suffix=.pdf)

    # Сжатие через Ghostscript
    gs -sDEVICE=pdfwrite \
        -dCompatibilityLevel=1.4 \
        -dNOPAUSE \
        -dOptimize=true \
        -dQUIET \
        -dBATCH \
        -dRemoveUnusedFonts=true \
        -dRemoveUnusedImages=true \
        -dOptimizeResources=true \
        -dDetectDuplicateImages \
        -dCompressFonts=true \
        -dEmbedAllFonts=true \
        -dSubsetFonts=true \
        -dPreserveAnnots=true \
        -dPreserveMarkedContent=true \
        -dPreserveOverprintSettings=true \
        -dPreserveHalftoneInfo=true \
        -dPreserveOPIComments=true \
        -dPreserveDeviceN=true \
        -dMaxInlineImageSize=0 \
        -sOutputFile="$tmp_file" \
        "$pdf_file"

    if [ ! -f "$tmp_file" ] || [ ! -s "$tmp_file" ]; then
        echo "  Ошибка: не удалось сжать файл."
        if $CHECK_MODE; then
            errors_found=true
        fi
        rm -f "$tmp_file"
        continue
    fi

    # Размер сжатого файла
    if stat -f%z "$tmp_file" &>/dev/null; then
        compressed_size=$(stat -f%z "$tmp_file")
    else
        compressed_size=$(stat -c%s "$tmp_file")
    fi

    min_allowed_size=$((original_size * 90 / 100)) # 80% от оригинала

    # 🔥 КЛЮЧЕВОЕ УСЛОВИЕ:
    # Если сжатый файл МЕНЬШЕ 80% → сжатие >20% → нужно сжать!
    if [ "$compressed_size" -lt "$min_allowed_size" ]; then
        if $CHECK_MODE; then
            echo "  ❌ ТРЕБУЕТСЯ СЖАТИЕ: сжатый файл будет составлять $((compressed_size * 100 / original_size))% от исходного по размеру!"
            errors_found=true
        else
            # Сохраняем оригинал как .backup и заменяем на сжатую версию
            cp "$pdf_file" "${pdf_file}.backup"
            mv "$tmp_file" "$pdf_file"
            echo "  ✅ Сжато: ${original_size} → ${compressed_size} байт (сохранён ${pdf_file}.backup)"
        fi
    else
        # Сжатие ≤20% → файл уже достаточно оптимизирован
        if $CHECK_MODE; then
            echo "  ✅ OK: сжатие ≤10% — файл уже оптимизирован"
        else
            echo "  Пропуск: сжатие ≤10% — файл уже оптимизирован"
        fi
        rm -f "$tmp_file" # удаляем временный файл
    fi

done < <(find "$SOURCE_DIR" -type f -iname "*.pdf" -print0)

# Завершение
if $CHECK_MODE; then
    if $errors_found; then
        echo "❌ Проверка не пройдена: найдены файлы, требующие сжатия (>10% потенциального уменьшения)."
        exit 1
    else
        echo "✅ Все PDF-файлы уже оптимизированы (сжатие ≤10%)."
        exit 0
    fi
else
    echo "✅ Обработка завершена. Тяжёлые PDF сжаты, оригиналы сохранены с расширением .backup."
fi
