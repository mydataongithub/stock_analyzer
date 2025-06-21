#!/bin/bash

# Performance-Tracking für Stock Analyzer
# Dieses Skript vergleicht alte Empfehlungen mit aktuellen Kursen, um die Genauigkeit zu bewerten

# Pfade
ANALYZER_PATH="/home/ganzfrisch/finance/stock_analyzer/stock_analyzer.py"
REPORTS_DIR="/home/ganzfrisch/finance/stock_analyzer/reports"
TRACK_DIR="/home/ganzfrisch/finance/stock_analyzer/performance_tracking"
TRACK_FILE="$TRACK_DIR/performance_tracking_$(date +"%Y%m%d").txt"
TRACK_HTML="$TRACK_DIR/performance_tracking_$(date +"%Y%m%d").html"

# Überprüfen, ob Python-Skript existiert
if [ ! -f "$ANALYZER_PATH" ]; then
    echo "Fehler: Stock Analyzer nicht gefunden unter $ANALYZER_PATH"
    exit 1
fi

# Erstelle Tracking-Verzeichnis, falls es nicht existiert
mkdir -p "$TRACK_DIR"

# Funktion, um den aktuellen Kurs über den Stock Analyzer abzurufen
get_current_price() {
    local symbol=$1
    # Rufe den aktuellen Kurs ab, ohne die vollständige Analyse auszuführen
    python3 -c "
import yfinance as yf
try:
    ticker = yf.Ticker('$symbol')
    price = ticker.history(period='1d')['Close'].iloc[-1]
    print(f'{price:.2f}')
except Exception as e:
    print('N/A')
"
}

# Sammle alle verfügbaren Kauf- und Verkaufsempfehlungen
{
    echo "===== PERFORMANCE TRACKING ====="
    echo "Datum: $(date)"
    echo "Vergleicht frühere Empfehlungen mit aktuellen Kursen"
    echo ""
    
    echo "KAUFEMPFEHLUNGEN PERFORMANCE:"
    echo "----------------------------"
    
    # Finde alle Kaufempfehlungsdateien
    buy_files=$(find "$REPORTS_DIR" -name "buy_recommendations_*.txt" -type f | sort)
    
    for buy_file in $buy_files; do
        file_date=$(echo "$buy_file" | grep -o "[0-9]\{8\}_[0-9]\{6\}")
        echo "Empfehlungen vom $(date -d "${file_date:0:8}" "+%d.%m.%Y"):"
        echo ""
        
        # Extrahiere alle Kaufempfehlungen mit Symbol, Unternehmen und Kursen
        while IFS= read -r line; do
            if [[ "$line" =~ ^Symbol:\ (.*)$ ]]; then
                symbol=${BASH_REMATCH[1]}
                company=""
                old_price=""
                target_price=""
            elif [[ "$line" =~ ^Unternehmen:\ (.*)$ ]]; then
                company=${BASH_REMATCH[1]}
            elif [[ "$line" =~ ^Aktueller\ Kurs:\ (.*)$ ]]; then
                old_price=${BASH_REMATCH[1]}
                # Entferne $ und andere Währungszeichen
                old_price=$(echo "$old_price" | sed 's/[$€£¥]//g')
            elif [[ "$line" =~ ^Kursziel:\ (.*)$ ]]; then
                target_price=${BASH_REMATCH[1]}
                # Entferne $ und andere Währungszeichen
                target_price=$(echo "$target_price" | sed 's/[$€£¥]//g')
            elif [[ "$line" =~ ^-{10,}$ ]] && [[ -n "$symbol" ]]; then
                # Erreicht das Ende eines Eintrags - hole den aktuellen Kurs
                current_price=$(get_current_price "$symbol")
                
                # Berechne Performance
                if [[ "$current_price" != "N/A" ]] && [[ -n "$old_price" ]]; then
                    performance=$(echo "scale=2; 100 * ($current_price - $old_price) / $old_price" | bc)
                    
                    # Hinzufügen eines + für positive Performance
                    if (( $(echo "$performance > 0" | bc -l) )); then
                        performance="+$performance"
                    fi
                    
                    echo "Symbol: $symbol"
                    echo "Unternehmen: $company"
                    echo "Kurs bei Empfehlung: $old_price"
                    echo "Kursziel: $target_price"
                    echo "Aktueller Kurs: $current_price"
                    echo "Performance seit Empfehlung: ${performance}%"
                    
                    # Prüfe, ob das Kursziel erreicht wurde
                    if [[ -n "$target_price" ]]; then
                        if (( $(echo "$current_price >= $target_price" | bc -l) )); then
                            echo "Kursziel ERREICHT ✓"
                        else
                            # Berechne Upside zum Kursziel
                            target_upside=$(echo "scale=2; 100 * ($target_price - $current_price) / $current_price" | bc)
                            echo "Verbleibendes Upside: ${target_upside}%"
                        fi
                    fi
                    
                    echo "----------------------------------------"
                    echo ""
                fi
                
                # Reset für nächsten Eintrag
                symbol=""
                company=""
                old_price=""
                target_price=""
            fi
        done < "$buy_file"
    done
    
    echo ""
    echo "VERKAUFSEMPFEHLUNGEN PERFORMANCE:"
    echo "--------------------------------"
    
    # Finde alle Verkaufsempfehlungsdateien
    sell_files=$(find "$REPORTS_DIR" -name "sell_recommendations_*.txt" -type f | sort)
    
    for sell_file in $sell_files; do
        file_date=$(echo "$sell_file" | grep -o "[0-9]\{8\}_[0-9]\{6\}")
        echo "Empfehlungen vom $(date -d "${file_date:0:8}" "+%d.%m.%Y"):"
        echo ""
        
        # Extrahiere alle Verkaufsempfehlungen mit Symbol, Unternehmen und Kursen
        while IFS= read -r line; do
            if [[ "$line" =~ ^Symbol:\ (.*)$ ]]; then
                symbol=${BASH_REMATCH[1]}
                company=""
                old_price=""
                target_price=""
            elif [[ "$line" =~ ^Unternehmen:\ (.*)$ ]]; then
                company=${BASH_REMATCH[1]}
            elif [[ "$line" =~ ^Aktueller\ Kurs:\ (.*)$ ]]; then
                old_price=${BASH_REMATCH[1]}
                # Entferne $ und andere Währungszeichen
                old_price=$(echo "$old_price" | sed 's/[$€£¥]//g')
            elif [[ "$line" =~ ^Kursziel:\ (.*)$ ]]; then
                target_price=${BASH_REMATCH[1]}
                # Entferne $ und andere Währungszeichen
                target_price=$(echo "$target_price" | sed 's/[$€£¥]//g')
            elif [[ "$line" =~ ^-{10,}$ ]] && [[ -n "$symbol" ]]; then
                # Erreicht das Ende eines Eintrags - hole den aktuellen Kurs
                current_price=$(get_current_price "$symbol")
                
                # Berechne Performance (bei Verkaufsempfehlung ist negativ gut)
                if [[ "$current_price" != "N/A" ]] && [[ -n "$old_price" ]]; then
                    performance=$(echo "scale=2; 100 * ($current_price - $old_price) / $old_price" | bc)
                    
                    # Hinzufügen eines + für positive Performance (schlecht für Verkaufsempfehlung)
                    if (( $(echo "$performance > 0" | bc -l) )); then
                        performance="+$performance"
                        performance_comment="SCHLECHT (Kurs gestiegen)"
                    else
                        performance_comment="GUT (Kurs gefallen)"
                    fi
                    
                    echo "Symbol: $symbol"
                    echo "Unternehmen: $company"
                    echo "Kurs bei Empfehlung: $old_price"
                    echo "Kursziel: $target_price"
                    echo "Aktueller Kurs: $current_price"
                    echo "Performance seit Empfehlung: ${performance}% ($performance_comment)"
                    echo "----------------------------------------"
                    echo ""
                fi
                
                # Reset für nächsten Eintrag
                symbol=""
                company=""
                old_price=""
                target_price=""
            fi
        done < "$sell_file"
    done

} > "$TRACK_FILE"

echo "Performance-Tracking abgeschlossen und in $TRACK_FILE gespeichert."

# Optionale HTML-Konvertierung hier für eine bessere visuelle Darstellung
# (Ähnlich zur generate_html_report Funktion)
