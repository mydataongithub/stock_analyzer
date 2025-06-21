#!/bin/bash

# Skript zum Testen des Batch-Analysierers mit ausgewählten Test-Symbolen
# Test mit: NOVN.SW, NOV.DE, BAYN.DE, RIVN, XPEV, MDT

BATCH_ANALYZER_PATH="/home/ganzfrisch/finance/stock_analyzer/batch_stock_analyzer.py"
TEST_SYMBOLS_FILE="/home/ganzfrisch/finance/stock_analyzer/test_symbols.txt"
OUTPUT_DIR="/home/ganzfrisch/finance/stock_analyzer/tests/results"

# Überprüfen, ob Python-Skript existiert
if [ ! -f "$BATCH_ANALYZER_PATH" ]; then
    echo "Fehler: Batch Stock Analyzer nicht gefunden unter $BATCH_ANALYZER_PATH"
    exit 1
fi

# Überprüfen, ob Test-Symbole-Datei existiert
if [ ! -f "$TEST_SYMBOLS_FILE" ]; then
    echo "Fehler: Test-Symbole-Datei nicht gefunden unter $TEST_SYMBOLS_FILE"
    exit 1
fi

# Ausgabeverzeichnis erstellen
mkdir -p "$OUTPUT_DIR"

# Zeitstempel für Ausgabedateien
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_SUBDIR="$OUTPUT_DIR/test_${TIMESTAMP}"
mkdir -p "$OUTPUT_SUBDIR"

echo "===== Batch Stock Analyzer Test ====="
echo "Teste mit vordefinierten Test-Symbolen: NOVN.SW, NOV.DE, BAYN.DE, RIVN, XPEV, MDT"
echo "Ausgabeverzeichnis: $OUTPUT_SUBDIR"
echo "======================================"

# Lese Symbole aus der Datei und übergebe sie als Positionsargumente
TEST_SYMBOLS=$(grep -v '^#' "$TEST_SYMBOLS_FILE" | grep -v '^$' | tr '\n' ' ')

# Prüfen, ob Symbole gefunden wurden
if [ -z "$TEST_SYMBOLS" ]; then
    echo "Fehler: Keine Test-Symbole in der Datei gefunden."
    exit 1
fi

echo "Analysiere folgende Test-Symbole: $TEST_SYMBOLS"
python "$BATCH_ANALYZER_PATH" $TEST_SYMBOLS -o "$OUTPUT_SUBDIR"

# Prüfen, ob die Analyse erfolgreich war
if [ $? -ne 0 ]; then
    echo "Fehler: Test-Analyse fehlgeschlagen."
    exit 1
fi

echo ""
echo "===== Test abgeschlossen ====="
echo "Alle Test-Analysen wurden im Verzeichnis $OUTPUT_SUBDIR gespeichert."
echo "Überprüfen Sie die Ergebnisse auf Korrektheit."
