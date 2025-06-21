#!/bin/bash

# Stock Analyzer - Systemüberprüfung
# Dieses Skript überprüft die Systemumgebung und stellt sicher,
# dass alle Voraussetzungen für die ordnungsgemäße Ausführung erfüllt sind

echo "==== Stock Analyzer - Systemüberprüfung ===="

# Basispfade
INSTALL_DIR=$(dirname $(readlink -f "$0"))
PYTHON_VENV="$INSTALL_DIR/venv"
LOG_DIR="$INSTALL_DIR/logs"
BATCH_ANALYZER="$INSTALL_DIR/batch_stock_analyzer.py"
STOCK_ANALYZER="$INSTALL_DIR/stock_analyzer.py"
SYMBOLS_FILE="$INSTALL_DIR/stock_symbols.txt"

# Farben für eine bessere visuelle Darstellung
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funktion zur Überprüfung und Ausgabe des Status
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "[${GREEN}✓${NC}] $2"
    else
        echo -e "[${RED}✗${NC}] $2 - $3"
    fi
}

# Überprüfen, ob Python installiert ist
echo -e "\n${YELLOW}Prüfe Python-Installation:${NC}"
if command -v python3 &>/dev/null; then
    python_version=$(python3 --version 2>&1)
    check_status 0 "Python installiert: $python_version"
else
    check_status 1 "Python 3 ist nicht installiert" "Bitte installieren Sie Python 3.8 oder höher"
    python_installed=false
fi

# Überprüfen, ob die virtuelle Umgebung existiert
echo -e "\n${YELLOW}Prüfe virtuelle Python-Umgebung:${NC}"
if [ -d "$PYTHON_VENV" ] && [ -f "$PYTHON_VENV/bin/activate" ]; then
    check_status 0 "Virtuelle Umgebung gefunden unter $PYTHON_VENV"
    # Aktivierung der virtuellen Umgebung für weitere Checks
    source "$PYTHON_VENV/bin/activate"
else
    check_status 1 "Virtuelle Umgebung nicht gefunden" "Führen Sie 'install.sh' aus oder erstellen Sie eine virtuelle Umgebung manuell"
fi

# Überprüfen, ob die notwendigen Python-Pakete installiert sind
echo -e "\n${YELLOW}Prüfe Python-Pakete:${NC}"
required_packages=("yfinance" "pandas" "numpy" "matplotlib" "seaborn" "tabulate")
missing_packages=()

for package in "${required_packages[@]}"; do
    if python3 -c "import $package" &>/dev/null; then
        version=$(python3 -c "import $package; print($package.__version__)" 2>/dev/null || echo "installiert")
        check_status 0 "$package: $version"
    else
        check_status 1 "$package ist nicht installiert" "Führen Sie 'pip install $package' aus"
        missing_packages+=("$package")
    fi
done

# Überprüfen, ob die wichtigen Dateien vorhanden sind
echo -e "\n${YELLOW}Prüfe wichtige Dateien:${NC}"
files_to_check=(
    "$BATCH_ANALYZER:Batch Analyzer Python-Skript"
    "$STOCK_ANALYZER:Stock Analyzer Core-Skript"
    "$SYMBOLS_FILE:Symbol-Liste"
    "$INSTALL_DIR/run_optimized_analysis.sh:Optimiertes Analyse-Skript"
    "$INSTALL_DIR/config.py:Konfigurationsdatei"
)

for file_info in "${files_to_check[@]}"; do
    file_path=${file_info%%:*}
    file_desc=${file_info#*:}
    
    if [ -f "$file_path" ]; then
        # Überprüfen der Ausführungsberechtigungen für Skript-Dateien
        if [[ "$file_path" == *.py || "$file_path" == *.sh ]]; then
            if [ -x "$file_path" ]; then
                check_status 0 "$file_desc ist vorhanden und ausführbar"
            else
                check_status 1 "$file_desc ist vorhanden, aber nicht ausführbar" "Führen Sie 'chmod +x $file_path' aus"
            fi
        else
            check_status 0 "$file_desc ist vorhanden"
        fi
    else
        check_status 1 "$file_desc nicht gefunden" "Die Datei $file_path existiert nicht"
    fi
done

# Überprüfen der Verzeichnisstruktur
echo -e "\n${YELLOW}Prüfe Verzeichnisstruktur:${NC}"
dirs_to_check=(
    "$LOG_DIR:Protokollverzeichnis"
    "$INSTALL_DIR/reports:Berichtsverzeichnis"
    "$INSTALL_DIR/tests/results:Testverzeichnis"
)

for dir_info in "${dirs_to_check[@]}"; do
    dir_path=${dir_info%%:*}
    dir_desc=${dir_info#*:}
    
    if [ -d "$dir_path" ]; then
        # Überprüfen der Schreibberechtigungen
        if [ -w "$dir_path" ]; then
            check_status 0 "$dir_desc ist vorhanden und beschreibbar"
        else
            check_status 1 "$dir_desc ist vorhanden, aber nicht beschreibbar" "Ändern Sie die Berechtigungen mit 'chmod u+w $dir_path'"
        fi
    else
        check_status 1 "$dir_desc nicht gefunden" "Erstellen Sie das Verzeichnis mit 'mkdir -p $dir_path'"
    fi
done

# Internetverbindung prüfen (wichtig für API-Zugriff)
echo -e "\n${YELLOW}Prüfe Internetverbindung:${NC}"
if ping -c 1 api.finance.yahoo.com &>/dev/null; then
    check_status 0 "Internetverbindung zur Yahoo Finance API ist verfügbar"
else
    check_status 1 "Keine Verbindung zur Yahoo Finance API" "Überprüfen Sie Ihre Internetverbindung"
fi

# Testanfrage an Yahoo Finance API
echo -e "\n${YELLOW}Führe API-Testabfrage durch:${NC}"
if python3 -c "import yfinance as yf; ticker = yf.Ticker('AAPL'); print('Erfolg' if ticker.info else 'Fehlschlag')" 2>/dev/null | grep -q 'Erfolg'; then
    check_status 0 "Testabfrage an Yahoo Finance API erfolgreich"
else
    check_status 1 "Testabfrage an Yahoo Finance API fehlgeschlagen" "Möglicherweise Probleme mit der API oder Rate-Limits"
fi

# Überprüfen, ob die Testsymbole vorhanden sind
echo -e "\n${YELLOW}Prüfe Testsymbole:${NC}"
test_symbols=("NOVN.SW" "NOV.DE" "BAYN.DE" "RIVN" "XPEV" "MDT")
test_symbols_file="$INSTALL_DIR/test_symbols.txt"

if [ -f "$test_symbols_file" ]; then
    check_status 0 "Testsymbole-Datei gefunden: $test_symbols_file"
    
    # Überprüfen, ob alle erforderlichen Testsymbole enthalten sind
    missing_symbols=()
    for symbol in "${test_symbols[@]}"; do
        if ! grep -q "^$symbol" "$test_symbols_file"; then
            missing_symbols+=("$symbol")
        fi
    done
    
    if [ ${#missing_symbols[@]} -eq 0 ]; then
        check_status 0 "Alle erforderlichen Testsymbole sind in der Datei enthalten"
    else
        check_status 1 "Einige Testsymbole fehlen in der Datei" "Fehlende Symbole: ${missing_symbols[*]}"
    fi
else
    check_status 1 "Testsymbole-Datei nicht gefunden" "Erstellen Sie die Datei $test_symbols_file mit den erforderlichen Testsymbolen"
fi

# Zusammenfassung
echo -e "\n${YELLOW}===== Zusammenfassung =====:${NC}"
if [ ${#missing_packages[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ Alle erforderlichen Python-Pakete sind installiert${NC}"
else
    echo -e "${RED}✗ Fehlende Python-Pakete: ${missing_packages[*]}${NC}"
fi

# Prüfen, ob das System bereit für die Ausführung ist
if [ -x "$BATCH_ANALYZER" ] && [ -x "$INSTALL_DIR/run_optimized_analysis.sh" ] && [ ${#missing_packages[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ Das System ist bereit für die Ausführung${NC}"
    echo -e "\nSie können nun die folgenden Befehle ausführen:"
    echo -e "  ${YELLOW}./batch_stock_analyzer.py AAPL MSFT -o reports${NC} - Für eine Batch-Analyse"
    echo -e "  ${YELLOW}./run_optimized_analysis.sh${NC} - Für eine optimierte Analyse aller Symbole"
    echo -e "  ${YELLOW}./test_batch_analyzer.sh${NC} - Für Tests mit den vordefinierten Testsymbolen"
else
    echo -e "${RED}✗ Das System ist NICHT bereit für die Ausführung${NC}"
    echo -e "Bitte beheben Sie die oben aufgeführten Probleme, bevor Sie fortfahren."
fi

echo -e "\nDie Systemüberprüfung ist abgeschlossen."

# Zurücksetzen der virtuellen Umgebung
deactivate 2>/dev/null || true

exit 0
