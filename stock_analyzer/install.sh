#!/bin/bash

# Stock Analyzer Installation Script
# Dieses Skript installiert alle Abhängigkeiten und richtet das System ein

echo "===== Stock Analyzer Installation ====="
echo "Installiere Abhängigkeiten und richte das System ein..."

# Verzeichnis erstellen
INSTALL_DIR=$(dirname $(readlink -f "$0"))
echo "Installationsverzeichnis: $INSTALL_DIR"

# Überprüfen, ob Python installiert ist
if command -v python3 &>/dev/null; then
    PYTHON_CMD="python3"
    echo "Python3 gefunden: $(python3 --version)"
else
    echo "Fehler: Python 3 ist nicht installiert. Bitte installieren Sie Python 3.8 oder höher."
    exit 1
fi

# Virtuelle Umgebung erstellen
echo "Erstelle virtuelle Python-Umgebung..."
$PYTHON_CMD -m venv "$INSTALL_DIR/venv"
source "$INSTALL_DIR/venv/bin/activate"

# Abhängigkeiten installieren
echo "Installiere erforderliche Python-Pakete..."
pip install --upgrade pip
pip install yfinance pandas numpy matplotlib seaborn tabulate

# Erstellen der notwendigen Verzeichnisse
echo "Erstelle Verzeichnisstruktur..."
mkdir -p "$INSTALL_DIR/reports"
mkdir -p "$INSTALL_DIR/logs"
mkdir -p "$INSTALL_DIR/data"
mkdir -p "$INSTALL_DIR/tests/results"

# Skripte ausführbar machen
echo "Mache Skripte ausführbar..."
find "$INSTALL_DIR" -name "*.py" -exec chmod +x {} \;
find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;

# Test-Symbole-Datei erstellen, falls nicht vorhanden
if [ ! -f "$INSTALL_DIR/test_symbols.txt" ]; then
    echo "Erstelle Test-Symbole-Datei..."
    cat > "$INSTALL_DIR/test_symbols.txt" << EOF
NOV.DE
NOVN.SW
BAYN.DE
RIVN
XPEV
MDT
EOF
fi

# Basiskonfiguration erstellen, wenn sie nicht existiert
if [ ! -f "$INSTALL_DIR/config.py" ]; then
    echo "Erstelle Basiskonfiguration..."
    cat > "$INSTALL_DIR/config.py" << EOF
# Stock Analyzer Konfiguration

# Technische Analyse Parameter
RSI_PERIOD = 14
HISTORICAL_DATA_PERIOD = "1y"

# DCF-Modell Parameter
RISK_FREE_RATE = 0.04  # 4% Staatsanleihen
MARKET_RISK_PREMIUM = 0.055  # 5.5% Marktrisiko
GROWTH_SCENARIOS = [0.00, 0.005, 0.01]
DISCOUNT_SCENARIOS = [0.08, 0.10, 0.12]

# API Settings
API_TIMEOUT = 30  # Sekunden
RETRY_COUNT = 3
EOF
fi

# Installationstest
echo "Führe Installationstest durch..."
$PYTHON_CMD -c "import yfinance; import pandas; import numpy; print('Alle Pakete erfolgreich geladen!')"
if [ $? -ne 0 ]; then
    echo "Fehler: Installationstest fehlgeschlagen. Bitte überprüfen Sie die Fehlermeldungen."
    exit 1
fi

echo ""
echo "===== Installation abgeschlossen! ====="
echo "Um das System zu verwenden, aktivieren Sie die virtuelle Umgebung:"
echo "source $INSTALL_DIR/venv/bin/activate"
echo ""
echo "Führen Sie dann den folgenden Befehl aus, um eine Analyse zu starten:"
echo "./batch_stock_analyzer.py AAPL MSFT -o reports"
echo ""
echo "Oder für eine optimierte Analyse aller Symbole:"
echo "./run_optimized_analysis.sh"
echo ""
echo "Ausführliche Dokumentation finden Sie in:"
echo "README_USER.md - Benutzerhandbuch"
echo "README_TECHNICAL.md - Technische Dokumentation"
echo ""
echo "Viel Erfolg bei Ihren Aktienanalysen!"
