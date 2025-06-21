#!/bin/bash

# Stock Analyzer Batch Script
# Dieses Skript führt Stock Analyzer für eine Reihe von Aktien aus
# Es liest Symbole aus stock_symbols.txt und verarbeitet sie in Gruppen

ANALYZER_PATH="/home/ganzfrisch/finance/stock_analyzer/stock_analyzer.py"
SYMBOLS_FILE="/home/ganzfrisch/finance/stock_analyzer/stock_symbols.txt"
OUTPUT_DIR="/home/ganzfrisch/finance/stock_analyzer/reports"
BATCH_SIZE=3  # Anzahl der Aktien, die gleichzeitig analysiert werden
DELAY=2       # Sekunden Verzögerung zwischen den Batches, um API-Limits zu vermeiden

# Überprüfen, ob Python-Skript existiert
if [ ! -f "$ANALYZER_PATH" ]; then
    echo "Fehler: Stock Analyzer nicht gefunden unter $ANALYZER_PATH"
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

# Extrahiere Aktien-Symbole aus der Datei (ignoriere Zeilen mit # und leere Zeilen)
declare -a SYMBOLS
while read -r line; do
    # Entferne Kommentare und führende/nachfolgende Leerzeichen
    symbol=$(echo "$line" | sed 's/#.*//g' | awk '{$1=$1};1')
    
    # Überspringe leere Zeilen
    if [ -n "$symbol" ]; then
        SYMBOLS+=("$symbol")
    fi
done < "$SYMBOLS_FILE"

echo "===== Stock Analyzer Batch-Ausführung ====="
echo "Gefundene Symbole: ${#SYMBOLS[@]}"
echo "Batch-Größe: $BATCH_SIZE"
echo "Ausgabeverzeichnis: $OUTPUT_DIR"
echo "========================================"

# Batch-weise Verarbeitung
for ((i=0; i<${#SYMBOLS[@]}; i+=$BATCH_SIZE)); do
    # Bestimme die aktuelle Batch-Größe
    current_batch_size=$BATCH_SIZE
    if [ $((i + $BATCH_SIZE)) -gt ${#SYMBOLS[@]} ]; then
        current_batch_size=$((${#SYMBOLS[@]} - i))
    fi
    
    # Erstelle ein Array mit den Symbolen für diesen Batch
    declare -a batch_symbols
    for ((j=0; j<$current_batch_size; j++)); do
        batch_symbols+=("${SYMBOLS[$i+$j]}")
    done
    
    # Batch-Info ausgeben
    echo ""
    # Berechne die Gesamtzahl der Batches ohne Ternäroperator
    total_batches=$((${#SYMBOLS[@]} / $BATCH_SIZE))
    if [ $((${#SYMBOLS[@]} % $BATCH_SIZE)) -gt 0 ]; then
        total_batches=$((total_batches + 1))
    fi
    echo "Verarbeite Batch $((i/$BATCH_SIZE + 1)) von $total_batches: ${batch_symbols[*]}"
    
    # Ausgabedatei für diesen Batch
    batch_output="$OUTPUT_DIR/stock_analysis_${TIMESTAMP}_batch$((i/$BATCH_SIZE + 1)).txt"
    
    # Führe den Analyzer aus
    echo "Ausgabe wird gespeichert in: $batch_output"
    python "$ANALYZER_PATH" "${batch_symbols[@]}" | tee "$batch_output"
    
    # Warte zwischen den Batches, um API-Limits zu vermeiden
    if [ $((i + $BATCH_SIZE)) -lt ${#SYMBOLS[@]} ]; then
        echo "Warte $DELAY Sekunden vor dem nächsten Batch..."
        sleep $DELAY
    fi
done

echo ""
echo "===== Analyse abgeschlossen ====="
echo "Alle Analysen wurden im Verzeichnis $OUTPUT_DIR gespeichert."
echo ""

# Erstelle eine Zusammenfassung aller Analysen
summary_file="$OUTPUT_DIR/stock_analysis_summary_${TIMESTAMP}.txt"
buy_recommendations_file="$OUTPUT_DIR/buy_recommendations_${TIMESTAMP}.txt"
sell_recommendations_file="$OUTPUT_DIR/sell_recommendations_${TIMESTAMP}.txt"
echo "Erstelle Zusammenfassung in $summary_file..."

{
    echo "===== STOCK ANALYSIS ZUSAMMENFASSUNG ====="
    echo "Datum: $(date)"
    echo "Analysierte Symbole: ${SYMBOLS[*]}"
    echo ""
    echo "EMPFEHLUNGEN:"
    
    # Durchsuche alle generierten Dateien nach Empfehlungen
    for output_file in "$OUTPUT_DIR/stock_analysis_${TIMESTAMP}_"*.txt; do
        echo "--- $(basename "$output_file") ---" 
        grep -A 5 "AKTIENSTRATEGIE & EMPFEHLUNG" "$output_file" | grep -E "Gesamtempfehlung|Stärken|Schwächen/Risiken" 
        echo ""
    done
} > "$summary_file"

# Erstelle eine separate Datei nur für Kaufempfehlungen
echo "Erstelle Liste mit Kaufempfehlungen in $buy_recommendations_file..."

{
    echo "===== AKTIEN MIT KAUFEMPFEHLUNG ====="
    echo "Datum: $(date)"
    echo ""
    echo "KAUFEMPFEHLUNGEN:"
    echo ""

    # Finde alle Analysen mit Kaufempfehlungen und extrahiere relevante Informationen
    for output_file in "$OUTPUT_DIR/stock_analysis_${TIMESTAMP}_"*.txt; do
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
    echo "===== AKTIEN MIT VERKAUFSEMPFEHLUNG ====="
    echo "Datum: $(date)"
    echo ""
    echo "VERKAUFSEMPFEHLUNGEN:"
    echo ""

    # Finde alle Analysen mit Verkaufsempfehlungen und extrahiere relevante Informationen
    for output_file in "$OUTPUT_DIR/stock_analysis_${TIMESTAMP}_"*.txt; do
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
