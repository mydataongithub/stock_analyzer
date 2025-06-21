#!/bin/bash

# Filter Tool für Stock Analyzer
# Filtert Aktienanalysen basierend auf verschiedenen Kriterien

OUTPUT_DIR="/home/ganzfrisch/finance/stock_analyzer/reports"
FILTERS_DIR="$OUTPUT_DIR/filters"

# Überprüfen ob Argument übergeben wurde (Zeitstempel)
if [ $# -lt 2 ]; then
    echo "Verwendung: $0 <Zeitstempel> <Filteroption> [Wert]"
    echo ""
    echo "Zeitstempel: Timestamp der Analyse oder 'latest'"
    echo "Filteroptionen:"
    echo "  --pe-max <max>          : Filtern nach maximalem KGV (Forward P/E)"
    echo "  --pe-min <min>          : Filtern nach minimalem KGV (Forward P/E)"
    echo "  --div-min <min>         : Filtern nach Mindest-Dividendenrendite (%)"
    echo "  --upside-min <min>      : Filtern nach Minimum Upside-Potenzial (%)"
    echo "  --sector <sector>       : Filtern nach Sektor"
    echo "  --country <country>     : Filtern nach Land"
    echo "  --analyst-rating <min>  : Filtern nach Mindest-Analystenbewertung (1-5)"
    echo "  --dcf-discount <min>    : Filtern nach DCF-Discount (%, min)"
    echo ""
    echo "Beispiel: $0 20250621_120000 --pe-max 15"
    echo "Beispiel: $0 latest --div-min 3.5"
    exit 1
fi

TIMESTAMP="$1"
FILTER_OPTION="$2"
FILTER_VALUE="$3"

# Bei "latest" den neuesten Zeitstempel finden
if [ "$TIMESTAMP" == "latest" ]; then
    TIMESTAMP=$(ls -1 "$OUTPUT_DIR"/stock_analysis_*_batch1.txt 2>/dev/null | sort -r | head -1 | sed -E 's/.*stock_analysis_([0-9]+_[0-9]+)_batch1\.txt/\1/')
    
    if [ -z "$TIMESTAMP" ]; then
        echo "Keine Analysedateien gefunden"
        exit 1
    fi
    
    echo "Neuester Zeitstempel gefunden: $TIMESTAMP"
fi

# Verzeichnisse erstellen
mkdir -p "$FILTERS_DIR"

# Ermittle die Batch-Dateien 
BATCH_FILES=("$OUTPUT_DIR/stock_analysis_${TIMESTAMP}_"*.txt)

if [ ${#BATCH_FILES[@]} -eq 0 ]; then
    echo "Fehler: Keine Analysedateien für Zeitstempel $TIMESTAMP gefunden"
    exit 1
fi

# Temporäre Datei für die Ergebnisse
TEMP_FILE="/tmp/filter_results_$$.txt"
> "$TEMP_FILE"  # Leere Datei erstellen

# Aktuelle Zeit und Datum für Ausgabedatei
CURRENT_DATE=$(date +"%Y%m%d_%H%M%S")

# Funktion zur Extraktion numerischer Werte
extract_number() {
    local value="$1"
    # Entferne alles außer Ziffern, Punkt und Komma
    value=$(echo "$value" | sed 's/[^0-9,.]*//g')
    # Ersetze Komma durch Punkt für numerische Verarbeitung
    value=$(echo "$value" | sed 's/,/./g')
    echo "$value"
}

# Durchsuchen der Batch-Dateien nach dem Filter
for file in "${BATCH_FILES[@]}"; do
    # Trenne die Datei in einzelne Aktienanalysen
    csplit -s -z "$file" "/AKTIENANALYSE:/" '{*}' -f "/tmp/analysis_" -b "%03d.txt"
    
    # Verarbeite jede einzelne Analyse
    for analysis in /tmp/analysis_*.txt; do
        symbol=$(grep "AKTIENANALYSE:" "$analysis" | cut -d ':' -f 2 | tr -d ' ' || echo "Unknown")
        company=$(grep -A 3 "Unternehmen" "$analysis" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//' || echo "Unknown")
        
        # Werte für die verschiedenen Filter extrahieren
        case "$FILTER_OPTION" in
            --pe-max|--pe-min)
                # Extrahiere Forward P/E
                pe_value=$(grep -A 3 "Forward P/E" "$analysis" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
                pe_number=$(extract_number "$pe_value")
                
                # Prüfe ob Wert numerisch ist oder nicht vorhanden
                if [[ -z "$pe_number" || "$pe_number" == "N/A" ]]; then
                    continue
                fi
                
                # Vergleiche mit Filter
                if [ "$FILTER_OPTION" == "--pe-max" ] && (( $(echo "$pe_number <= $FILTER_VALUE" | bc -l) )); then
                    cat "$analysis" >> "$TEMP_FILE"
                    echo -e "\n--------------------------------------------------\n" >> "$TEMP_FILE"
                elif [ "$FILTER_OPTION" == "--pe-min" ] && (( $(echo "$pe_number >= $FILTER_VALUE" | bc -l) )); then
                    cat "$analysis" >> "$TEMP_FILE"
                    echo -e "\n--------------------------------------------------\n" >> "$TEMP_FILE"
                fi
                ;;
                
            --div-min)
                # Extrahiere Dividendenrendite
                div_value=$(grep -A 3 "Dividendenrendite" "$analysis" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
                div_number=$(extract_number "$div_value")
                
                # Prüfe ob Wert numerisch ist oder nicht vorhanden
                if [[ -z "$div_number" || "$div_number" == "N/A" ]]; then
                    continue
                fi
                
                # Vergleiche mit Filter
                if (( $(echo "$div_number >= $FILTER_VALUE" | bc -l) )); then
                    cat "$analysis" >> "$TEMP_FILE"
                    echo -e "\n--------------------------------------------------\n" >> "$TEMP_FILE"
                fi
                ;;
                
            --upside-min)
                # Extrahiere Upside-Potenzial
                upside_value=$(grep -A 3 "Upside-Potenzial" "$analysis" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
                upside_number=$(extract_number "$upside_value")
                
                # Prüfe ob Wert numerisch ist oder nicht vorhanden
                if [[ -z "$upside_number" || "$upside_number" == "N/A" ]]; then
                    continue
                fi
                
                # Vergleiche mit Filter
                if (( $(echo "$upside_number >= $FILTER_VALUE" | bc -l) )); then
                    cat "$analysis" >> "$TEMP_FILE"
                    echo -e "\n--------------------------------------------------\n" >> "$TEMP_FILE"
                fi
                ;;
                
            --sector)
                # Extrahiere Sektor
                sector=$(grep -A 3 "Sektor" "$analysis" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
                
                # Prüfe ob Wert vorhanden und passt zum Filter
                if [[ -n "$sector" && "${sector,,}" == *"${FILTER_VALUE,,}"* ]]; then
                    cat "$analysis" >> "$TEMP_FILE"
                    echo -e "\n--------------------------------------------------\n" >> "$TEMP_FILE"
                fi
                ;;
                
            --country)
                # Extrahiere Land
                country=$(grep -A 3 "Land" "$analysis" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
                
                # Prüfe ob Wert vorhanden und passt zum Filter
                if [[ -n "$country" && "${country,,}" == *"${FILTER_VALUE,,}"* ]]; then
                    cat "$analysis" >> "$TEMP_FILE"
                    echo -e "\n--------------------------------------------------\n" >> "$TEMP_FILE"
                fi
                ;;
                
            --analyst-rating)
                # Extrahiere Analystenbewertung
                rating=$(grep -A 3 "Analystenbewertung" "$analysis" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
                rating_number=$(extract_number "$rating")
                
                # Prüfe ob Wert numerisch ist oder nicht vorhanden
                if [[ -z "$rating_number" || "$rating_number" == "N/A" ]]; then
                    continue
                fi
                
                # Vergleiche mit Filter
                if (( $(echo "$rating_number >= $FILTER_VALUE" | bc -l) )); then
                    cat "$analysis" >> "$TEMP_FILE"
                    echo -e "\n--------------------------------------------------\n" >> "$TEMP_FILE"
                fi
                ;;
                
            --dcf-discount)
                # Extrahiere DCF-Discount
                dcf_value=$(grep -A 3 "DCF-Wert" "$analysis" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
                current_price_value=$(grep -A 3 "Aktueller Kurs" "$analysis" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
                
                dcf_number=$(extract_number "$dcf_value")
                current_price_number=$(extract_number "$current_price_value")
                
                # Prüfe ob Werte numerisch sind oder nicht vorhanden
                if [[ -z "$dcf_number" || "$dcf_number" == "N/A" || -z "$current_price_number" || "$current_price_number" == "N/A" ]]; then
                    continue
                fi
                
                # Berechne DCF-Discount in Prozent
                dcf_discount=$(echo "($dcf_number - $current_price_number) / $current_price_number * 100" | bc -l)
                
                # Vergleiche mit Filter
                if (( $(echo "$dcf_discount >= $FILTER_VALUE" | bc -l) )); then
                    cat "$analysis" >> "$TEMP_FILE"
                    echo -e "\n--------------------------------------------------\n" >> "$TEMP_FILE"
                fi
                ;;
                
            *)
                echo "Unbekannte Filteroption: $FILTER_OPTION"
                rm -f /tmp/analysis_*.txt "$TEMP_FILE"
                exit 1
                ;;
        esac
    done
    
    # Temporäre Dateien löschen
    rm -f /tmp/analysis_*.txt
done

# Filtertyp für Dateiname extrahieren
FILTER_TYPE=$(echo "$FILTER_OPTION" | sed 's/--//')

# Ergebnisse in Datei speichern
RESULTS_FILE="$FILTERS_DIR/filter_${FILTER_TYPE}_${FILTER_VALUE}_${CURRENT_DATE}.txt"
COUNT=$(grep -c "AKTIENANALYSE:" "$TEMP_FILE" || echo 0)

# Header zur Ergebnisdatei hinzufügen
{
    echo "=========================================================="
    echo "FILTER-ERGEBNISSE: $FILTER_OPTION $FILTER_VALUE"
    echo "Zeitstempel der Analyse: $TIMESTAMP"
    echo "Datum der Filterung: $(date +'%d.%m.%Y %H:%M:%S')"
    echo "Anzahl gefundener Aktien: $COUNT"
    echo "=========================================================="
    echo ""
    cat "$TEMP_FILE"
} > "$RESULTS_FILE"

# Temporäre Datei löschen
rm -f "$TEMP_FILE"

echo "Filter angewendet: $FILTER_OPTION $FILTER_VALUE"
echo "$COUNT Aktien gefunden, die dem Filter entsprechen"
echo "Ergebnisse gespeichert in: $RESULTS_FILE"

# Zusammenfassung der Ergebnisse
if [ $COUNT -gt 0 ]; then
    echo ""
    echo "Zusammenfassung der Ergebnisse:"
    echo "------------------------------"
    grep -A 1 "AKTIENANALYSE:" "$RESULTS_FILE" | grep -v "\-\-" | sort
fi

# Bei Bedarf HTML-Report erzeugen
if [ $COUNT -gt 0 ] && [ -f "/home/ganzfrisch/finance/stock_analyzer/generate_html_report.sh" ]; then
    read -p "Möchten Sie einen HTML-Report für diese Filterergebnisse erstellen? (j/n): " create_html
    if [[ "$create_html" == "j" || "$create_html" == "J" ]]; then
        filter_timestamp="${CURRENT_DATE}_filter_${FILTER_TYPE}"
        
        # Kopiere die gefilterten Ergebnisse in ein Format, das vom HTML-Generator verstanden wird
        cp "$RESULTS_FILE" "$OUTPUT_DIR/stock_analysis_${filter_timestamp}_batch1.txt"
        
        # Erstelle auch leere Buy- und Sell-Empfehlungsdateien
        touch "$OUTPUT_DIR/buy_recommendations_${filter_timestamp}.txt"
        touch "$OUTPUT_DIR/sell_recommendations_${filter_timestamp}.txt"
        
        # Generiere HTML-Report
        /home/ganzfrisch/finance/stock_analyzer/generate_html_report.sh "${filter_timestamp}"
    fi
fi
