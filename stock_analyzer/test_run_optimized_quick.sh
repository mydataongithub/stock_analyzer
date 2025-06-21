#!/bin/bash

# Test-Skript für run_optimized_analysis.sh mit kleinerer Symbolauswahl
# Kopiere run_optimized_analysis.sh mit Änderungen für den Test

# Pfade und Einstellungen
BATCH_ANALYZER_PATH="/home/ganzfrisch/finance/stock_analyzer/batch_stock_analyzer.py"
TEST_SYMBOLS_FILE="/home/ganzfrisch/finance/stock_analyzer/test_symbols.txt" # Kleine Testabliste
OUTPUT_DIR="/home/ganzfrisch/finance/stock_analyzer/test_reports"
MAX_WORKERS=4

# Überprüfen, ob Python-Skript existiert
if [ ! -f "$BATCH_ANALYZER_PATH" ]; then
    echo "Fehler: Batch Stock Analyzer nicht gefunden unter $BATCH_ANALYZER_PATH"
    exit 1
fi

# Überprüfen, ob Symbole-Datei existiert
if [ ! -f "$TEST_SYMBOLS_FILE" ]; then
    echo "Fehler: Test-Symbole-Datei nicht gefunden unter $TEST_SYMBOLS_FILE"
    exit 1
fi

# Ausgabeverzeichnis erstellen, falls nicht vorhanden
mkdir -p "$OUTPUT_DIR"

# Zeitstempel für Ausgabedateien
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_SUBDIR="$OUTPUT_DIR/analysis_${TIMESTAMP}"
mkdir -p "$OUTPUT_SUBDIR"

echo "===== TEST: Optimized Stock Analyzer Batch-Ausführung ====="
echo "Verwende Test-Symboldatei: $TEST_SYMBOLS_FILE"
echo "Ausgabeverzeichnis: $OUTPUT_SUBDIR"
echo "Maximale Worker-Threads: $MAX_WORKERS"
echo "=========================================================="

# Führe den Batch-Analyzer aus
echo "Starte Batch-Analyse mit Test-Symbolen..."

# Lese Symbole aus der Test-Datei und übergebe sie als Positionsargumente
SYMBOLS=$(grep -v '^#' "$TEST_SYMBOLS_FILE" | grep -v '^$' | tr '\n' ' ')

# Prüfen, ob Symbole gefunden wurden
if [ -z "$SYMBOLS" ]; then
    echo "Fehler: Keine Symbole in der Test-Datei gefunden."
    exit 1
fi

echo "Analysiere folgende Symbole: $SYMBOLS"
python "$BATCH_ANALYZER_PATH" $SYMBOLS -o "$OUTPUT_SUBDIR" -w "$MAX_WORKERS"

# Prüfen, ob die Analyse erfolgreich war
if [ $? -ne 0 ]; then
    echo "Fehler: Batch-Analyse fehlgeschlagen."
    exit 1
fi

echo ""
echo "===== Test-Analyse abgeschlossen ====="
echo "Alle Analysen wurden im Verzeichnis $OUTPUT_SUBDIR gespeichert."
echo ""

# Erfolgsmeldung
echo "Der run_optimized_analysis.sh Test war erfolgreich!"
echo "Das Problem mit der Symbolübergabe wurde behoben."
