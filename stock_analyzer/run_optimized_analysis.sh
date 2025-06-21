#!/bin/bash

# Optimized Stock Analyzer Batch Script
# Dieses Skript verwendet den batch_stock_analyzer.py für optimierte API-Abfragen
# Reduziert die API-Aufrufe indem alle Daten in einem Batch abgerufen werden

BATCH_ANALYZER_PATH="/home/ganzfrisch/finance/stock_analyzer/batch_stock_analyzer.py"
SYMBOLS_FILE="/home/ganzfrisch/finance/stock_analyzer/stock_symbols.txt"
OUTPUT_DIR="/home/ganzfrisch/finance/stock_analyzer/reports"
MAX_WORKERS=1 # Anzahl paralleler Worker-Threads (anpassbar)

# Überprüfen, ob Python-Skript existiert
if [ ! -f "$BATCH_ANALYZER_PATH" ]; then
    echo "Fehler: Batch Stock Analyzer nicht gefunden unter $BATCH_ANALYZER_PATH"
    exit 1
fi

# Überprüfen, ob Symbole-Datei existiert
if [ ! -f "$SYMBOLS_FILE" ]; then
    echo "Fehler: Symbole-Datei nicht gefunden unter $SYMBOLS_FILE"
    exit 1
fi

# Ausgabeverzeichnis erstellen, falls nicht vorhanden
mkdir -p "$OUTPUT_DIR"

# Zeitstempel für Ausgabedateien
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_SUBDIR="$OUTPUT_DIR/analysis_${TIMESTAMP}"
mkdir -p "$OUTPUT_SUBDIR"

echo "===== Optimized Stock Analyzer Batch-Ausführung ====="
echo "Verwende Batch-Analyzer für optimierte API-Abfragen"
echo "Ausgabeverzeichnis: $OUTPUT_SUBDIR"
echo "Maximale Worker-Threads: $MAX_WORKERS"
echo "=================================================="

# Führe den Batch-Analyzer aus
echo "Starte Batch-Analyse..."

# Lese Symbole aus der Datei und übergebe sie als Positionsargumente
SYMBOLS=$(grep -v '^#' "$SYMBOLS_FILE" | grep -v '^$' | tr '\n' ' ')

# Prüfen, ob Symbole gefunden wurden
if [ -z "$SYMBOLS" ]; then
    echo "Fehler: Keine Symbole in der Datei gefunden."
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
echo "===== Analyse abgeschlossen ====="
echo "Alle Analysen wurden im Verzeichnis $OUTPUT_SUBDIR gespeichert."
echo ""

# Erstelle eine Zusammenfassung aller Analysen
summary_file="$OUTPUT_DIR/stock_analysis_summary_${TIMESTAMP}.txt"
buy_recommendations_file="$OUTPUT_DIR/buy_recommendations_${TIMESTAMP}.txt"
sell_recommendations_file="$OUTPUT_DIR/sell_recommendations_${TIMESTAMP}.txt"
echo "Erstelle Zusammenfassung in $summary_file..."

{
    echo "===== STOCK ANALYSIS ZUSAMMENFASSUNG (OPTIMIERT) ====="
    echo "Datum: $(date)"
    echo "Analysierte Symbole aus: $SYMBOLS_FILE"
    echo ""
    echo "EMPFEHLUNGEN:"
    
    # Durchsuche alle generierten Dateien nach Empfehlungen
    for output_file in "$OUTPUT_SUBDIR"/stock_analysis_*.txt; do
        echo "--- $(basename "$output_file") ---" 
        grep -A 5 "AKTIENSTRATEGIE & EMPFEHLUNG" "$output_file" | grep -E "Gesamtempfehlung|Stärken|Schwächen/Risiken" 
        echo ""
    done
} > "$summary_file"

# Erstelle eine separate Datei nur für Kaufempfehlungen
echo "Erstelle Liste mit Kaufempfehlungen in $buy_recommendations_file..."

{
    echo "===== AKTIEN MIT KAUFEMPFEHLUNG (OPTIMIERT) ====="
    echo "Datum: $(date)"
    echo ""
    echo "KAUFEMPFEHLUNGEN:"
    echo ""

    # Finde alle Analysen mit Kaufempfehlungen und extrahiere relevante Informationen
    for output_file in "$OUTPUT_SUBDIR"/stock_analysis_*.txt; do
        # Extrahiere das Symbol aus der Datei
        symbol=$(grep -m 1 "AKTIENANALYSE:" "$output_file" | cut -d ":" -f 2 | tr -d ' ')
        
        # Prüfe, ob eine Kaufempfehlung vorliegt
        if grep -q "Gesamtempfehlung.*Kaufen" "$output_file"; then
            echo "Symbol: $symbol"
            
            # Extrahiere Firmenname
            company=$(grep -A 3 "Unternehmen" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
            echo "Unternehmen: $company"
            
            # Extrahiere aktuellen Kurs und Target-Preis
            current_price=$(grep -A 2 "Aktueller Kurs" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
            echo "Aktueller Kurs: $current_price"
            
            # Versuche, das Analysten-Kursziel zu extrahieren
            target_price=$(grep -A 2 "Analysten-Kursziel" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
            if [ -n "$target_price" ]; then
                echo "Kursziel: $target_price"
                
                # Extrahiere Upside-Potenzial
                upside=$(grep -A 2 "Upside-Potenzial" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
                echo "Upside: $upside"
            fi
            
            # Extrahiere DCF-Wert
            dcf_value=$(grep -A 5 "Begründung" "$output_file" | grep "DCF:" | sed 's/.*DCF: \([0-9.-]*\).*/\1/')
            if [ -n "$dcf_value" ]; then
                echo "DCF-Wert: $dcf_value"
            fi
            
            # Extrahiere Stärken
            strengths=$(grep -A 2 "Stärken" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
            echo "Stärken: $strengths"
            
            # Extrahiere Schwächen
            weaknesses=$(grep -A 2 "Schwächen/Risiken" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
            echo "Schwächen: $weaknesses"
            
            echo "----------------------------------------"
            echo ""
        fi
    done
} > "$buy_recommendations_file"

# Erstelle eine separate Datei für Verkaufsempfehlungen
echo "Erstelle Liste mit Verkaufsempfehlungen in $sell_recommendations_file..."

{
    echo "===== AKTIEN MIT VERKAUFSEMPFEHLUNG (OPTIMIERT) ====="
    echo "Datum: $(date)"
    echo ""
    echo "VERKAUFSEMPFEHLUNGEN:"
    echo ""

    # Finde alle Analysen mit Verkaufsempfehlungen und extrahiere relevante Informationen
    for output_file in "$OUTPUT_SUBDIR"/stock_analysis_*.txt; do
        # Extrahiere das Symbol aus der Datei
        symbol=$(grep -m 1 "AKTIENANALYSE:" "$output_file" | cut -d ":" -f 2 | tr -d ' ')
        
        # Prüfe, ob eine Verkaufsempfehlung vorliegt
        if grep -q "Gesamtempfehlung.*Verkaufen" "$output_file"; then
            echo "Symbol: $symbol"
            
            # Extrahiere Firmenname
            company=$(grep -A 3 "Unternehmen" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
            echo "Unternehmen: $company"
            
            # Extrahiere aktuellen Kurs
            current_price=$(grep -A 2 "Aktueller Kurs" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
            echo "Aktueller Kurs: $current_price"
            
            # Versuche, das Analysten-Kursziel zu extrahieren
            target_price=$(grep -A 2 "Analysten-Kursziel" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
            if [ -n "$target_price" ]; then
                echo "Kursziel: $target_price"
                
                # Extrahiere Upside-Potenzial (hier eher Downside)
                upside=$(grep -A 2 "Upside-Potenzial" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
                echo "Upside/Downside: $upside"
            fi
            
            # Extrahiere DCF-Wert (bei Verkaufsempfehlung typischerweise negativ)
            dcf_value=$(grep -A 5 "Begründung" "$output_file" | grep "DCF:" | sed 's/.*DCF: \([0-9.-]*\).*/\1/')
            if [ -n "$dcf_value" ]; then
                echo "DCF-Wert: $dcf_value"
            fi
            
            # Extrahiere Stärken
            strengths=$(grep -A 2 "Stärken" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
            echo "Stärken: $strengths"
            
            # Extrahiere Schwächen
            weaknesses=$(grep -A 2 "Schwächen/Risiken" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
            echo "Risiken: $weaknesses"
            
            echo "----------------------------------------"
            echo ""
        fi
    done
} > "$sell_recommendations_file"

echo "Zusammenfassung erstellt. Du kannst sie anzeigen mit: cat $summary_file"
echo "Kaufempfehlungen erstellt. Du kannst sie anzeigen mit: cat $buy_recommendations_file"
echo "Verkaufsempfehlungen erstellt. Du kannst sie anzeigen mit: cat $sell_recommendations_file"

# Optional: HTML-Report erstellen
if [ -f "/home/ganzfrisch/finance/stock_analyzer/generate_html_report.sh" ]; then
    echo "Erstelle HTML-Report..."
    bash "/home/ganzfrisch/finance/stock_analyzer/generate_html_report.sh" "$TIMESTAMP"
fi
