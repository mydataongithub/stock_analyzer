#!/bin/bash

# Optimized Stock Analyzer Batch Script - Test für die korrigierte Version
# Verwendet batch_stock_analyzer.py mit korrigierter I/O-Behandlung

BATCH_ANALYZER_PATH="/home/ganzfrisch/finance/stock_analyzer/batch_stock_analyzer.py"
TEST_SYMBOLS="NOVN.SW NOV.DE BAYN.DE RIVN XPEV MDT"
OUTPUT_DIR="/home/ganzfrisch/finance/stock_analyzer/tests/optimized_results"
MAX_WORKERS=4

# Überprüfen, ob Python-Skript existiert
if [ ! -f "$BATCH_ANALYZER_PATH" ]; then
    echo "Fehler: Batch Stock Analyzer nicht gefunden unter $BATCH_ANALYZER_PATH"
    exit 1
fi

# Ausgabeverzeichnis erstellen, falls nicht vorhanden
mkdir -p "$OUTPUT_DIR"

# Zeitstempel für Ausgabedateien
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_SUBDIR="$OUTPUT_DIR/analysis_${TIMESTAMP}"
mkdir -p "$OUTPUT_SUBDIR"

echo "===== Optimized Stock Analyzer Test ====="
echo "Verwende korrigierte Version des Batch-Analyzers"
echo "Test-Symbole: $TEST_SYMBOLS"
echo "Ausgabeverzeichnis: $OUTPUT_SUBDIR"
echo "Maximale Worker-Threads: $MAX_WORKERS"
echo "========================================="

# Führe den Batch-Analyzer aus
echo "Starte Batch-Analyse..."
python "$BATCH_ANALYZER_PATH" $TEST_SYMBOLS -o "$OUTPUT_SUBDIR" -w "$MAX_WORKERS"

# Prüfen, ob die Analyse erfolgreich war
if [ $? -ne 0 ]; then
    echo "Fehler: Batch-Analyse fehlgeschlagen."
    exit 1
fi

echo ""
echo "===== Analyse abgeschlossen ====="
echo "Alle Analysen wurden im Verzeichnis $OUTPUT_SUBDIR gespeichert."
echo "Der korrigierte Batch-Analyzer funktioniert korrekt mit den Test-Symbolen."
