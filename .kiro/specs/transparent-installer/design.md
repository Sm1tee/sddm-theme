# Design Document

## Overview

Интеграция установки SDDM тем в основной скрипт install-hyprland.sh путем замены функции install_sddm_config() на встроенную логику установки тем. Основная проблема - конфликт stdin при запуске скрипта внутри скрипта решается путем встраивания логики установки тем непосредственно в основной скрипт.

## Architecture

### Current Architecture
```
install-hyprland.sh
├── install_sddm_config() 
│   └── Вызывает внешний install.sh (ПРОБЛЕМА: конфликт stdin)
└── Остальные функции установки
```

### New Architecture
```
install-hyprland.sh
├── install_sddm_config()
│   ├── sddm_choose_installation_type()
│   ├── sddm_download_themes()
│   ├── sddm_install_dependencies()
│   ├── sddm_install_theme_files()
│   ├── sddm_configure_theme()
│   └── sddm_configure_sddm()
└── Остальные функции установки
```

## Components and Interfaces

### 1. Main Integration Function
```bash
install_sddm_config() {
    print_step_info "13" "НАСТРОЙКА МЕНЕДЖЕРА ДИСПЛЕЯ SDDM" \
        "Установка красивых тем для экрана входа"
    
    if ask_user "Установить SDDM темы?"; then
        sddm_install_process
    else
        print_info "Установка SDDM тем пропущена"
    fi
}
```

### 2. SDDM Installation Process
```bash
sddm_install_process() {
    local install_type
    local selected_theme
    
    # Выбор типа установки
    sddm_choose_installation_type install_type selected_theme
    
    # Установка зависимостей
    sddm_install_dependencies
    
    # Загрузка и установка тем
    sddm_download_and_install_themes "$install_type" "$selected_theme"
    
    # Настройка SDDM
    sddm_configure_system "$selected_theme"
}
```

### 3. Theme Selection Interface
```bash
sddm_choose_installation_type() {
    local -n type_ref=$1
    local -n theme_ref=$2
    
    echo "Выберите тип установки SDDM тем:"
    echo "1) Полная установка (все темы)"
    echo "2) Установка одной темы"
    
    read -p "Ваш выбор (1-2): " choice
    
    case $choice in
        1) type_ref="full" ;;
        2) 
            type_ref="single"
            sddm_select_single_theme theme_ref
            ;;
        *) 
            print_error "Неверный выбор, используется полная установка"
            type_ref="full"
            ;;
    esac
}
```

## Data Models

### Installation Configuration
```bash
# Глобальные переменные для конфигурации SDDM
SDDM_REPO_URL="https://github.com/Sm1tee/sddm-theme.git"
SDDM_INSTALL_DIR="/usr/share/sddm/themes/sm1tee"
SDDM_CONFIG_FILE="/etc/sddm.conf"
SDDM_TEMP_DIR="sddm-theme-temp"

# Доступные темы
SDDM_AVAILABLE_THEMES=(
    "apocalypse" "bones" "demon" "explosion" "gate" "gate2" "wizard"
    "samurai" "samurai2" "samurai3" "samurai4" "solder" "warrior"
    "house" "house2" "house3" "house4" "house5" "tree" "window" "window2"
    "calmness" "space" "space2" "witcher" "harry"
)
```

### Theme Configuration Structure
```bash
# Структура конфигурации темы
sddm_theme_config() {
    local theme_name=$1
    
    echo "[Theme]"
    echo "Current=sm1tee"
    echo "CursorTheme=Vimix-white-cursors"
    echo "CursorSize=30"
    echo ""
    echo "[General]"
    echo "DisplayServer=wayland"
    echo "GreeterEnvironment=wayland,QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard,XKB_DEFAULT_LAYOUT=us,ru"
    echo "Numlock=on"
    echo "InputMethod=qtvirtualkeyboard"
}
```

## Error Handling

### 1. Dependency Installation Errors
```bash
sddm_install_dependencies() {
    local packages
    local install_cmd
    
    case $DISTRO in
        "arch"|"manjaro"|"endeavouros")
            packages="sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg"
            install_cmd="sudo pacman -S --needed $packages"
            ;;
        # ... другие дистрибутивы
    esac
    
    if ! eval "$install_cmd"; then
        print_error "Ошибка установки зависимостей SDDM"
        return 1
    fi
}
```

### 2. Download and Installation Errors
```bash
sddm_download_themes() {
    local install_type=$1
    local theme_name=$2
    
    # Очистка предыдущих загрузок
    [[ -d "$SDDM_TEMP_DIR" ]] && rm -rf "$SDDM_TEMP_DIR"
    
    if ! git clone "$SDDM_REPO_URL" "$SDDM_TEMP_DIR"; then
        print_error "Ошибка загрузки репозитория SDDM тем"
        return 1
    fi
    
    # Проверка существования темы для single установки
    if [[ "$install_type" == "single" ]] && [[ ! -f "$SDDM_TEMP_DIR/themes/sm1tee/configs/${theme_name}.conf" ]]; then
        print_error "Тема '$theme_name' не найдена"
        return 1
    fi
}
```

### 3. Permission and System Errors
```bash
sddm_install_theme_files() {
    local source_dir="$SDDM_TEMP_DIR/themes/sm1tee"
    
    if [[ ! -d "$source_dir" ]]; then
        print_error "Исходная папка темы не найдена"
        return 1
    fi
    
    # Создание резервной копии существующей темы
    if [[ -d "$SDDM_INSTALL_DIR" ]]; then
        sudo mv "$SDDM_INSTALL_DIR" "${SDDM_INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    if ! sudo cp -r "$source_dir" "$SDDM_INSTALL_DIR"; then
        print_error "Ошибка копирования файлов темы"
        # Восстановление резервной копии если есть
        return 1
    fi
}
```

## Testing Strategy

### 1. Unit Testing Functions
```bash
# Тестирование выбора темы
test_sddm_theme_selection() {
    local test_input="2\nwitcher\n"
    local install_type theme_name
    
    echo -e "$test_input" | sddm_choose_installation_type install_type theme_name
    
    [[ "$install_type" == "single" ]] || return 1
    [[ "$theme_name" == "witcher" ]] || return 1
}

# Тестирование конфигурации
test_sddm_config_generation() {
    local config_output
    config_output=$(sddm_theme_config "witcher")
    
    echo "$config_output" | grep -q "Current=sm1tee" || return 1
    echo "$config_output" | grep -q "DisplayServer=wayland" || return 1
}
```

### 2. Integration Testing
```bash
# Тестирование полного процесса установки в тестовой среде
test_sddm_full_installation() {
    # Создание временной тестовой среды
    local test_dir="/tmp/sddm_test_$$"
    mkdir -p "$test_dir"
    
    # Переопределение путей для тестирования
    SDDM_INSTALL_DIR="$test_dir/themes"
    SDDM_CONFIG_FILE="$test_dir/sddm.conf"
    
    # Запуск установки
    sddm_install_process
    
    # Проверка результатов
    [[ -d "$SDDM_INSTALL_DIR" ]] || return 1
    [[ -f "$SDDM_CONFIG_FILE" ]] || return 1
    
    # Очистка
    rm -rf "$test_dir"
}
```

### 3. Error Handling Testing
```bash
# Тестирование обработки ошибок
test_sddm_error_handling() {
    # Тест с недоступным репозиторием
    SDDM_REPO_URL="https://invalid-url.com/repo.git"
    
    if sddm_download_themes "full" ""; then
        return 1  # Должна быть ошибка
    fi
    
    # Тест с недоступной темой
    if sddm_download_themes "single" "nonexistent_theme"; then
        return 1  # Должна быть ошибка
    fi
}
```

## Implementation Notes

### 1. Стилистическая Интеграция
- Использовать существующие функции print_step_info, print_error, print_success из основного скрипта
- Сохранить цветовую схему и форматирование основного скрипта
- Использовать существующие функции ask_user для пользовательского ввода

### 2. Совместимость с Дистрибутивами
- Определение дистрибутива должно использовать существующую логику из основного скрипта
- Команды установки пакетов должны соответствовать стилю основного скрипта
- Обработка ошибок должна быть консистентной

### 3. Cleanup и Безопасность
- Автоматическая очистка временных файлов
- Создание резервных копий перед перезаписью
- Проверка прав доступа перед выполнением sudo команд

### 4. Логирование и Отчетность
- Интеграция с системой логирования основного скрипта
- Добавление информации об установке SDDM в итоговый отчет
- Сохранение информации о выбранной теме для будущих обновлений