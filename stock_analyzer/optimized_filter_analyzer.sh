#!/bin/bash

# Optimierter Filter-Analyzer für Stock Analyzer
# Dieses Skript führt eine optimierte, gefilterte Analyse basierend auf verschiedenen Kriterien durch

BATCH_ANALYZER="/home/ganzfrisch/finance/stock_analyzer/batch_stock_analyzer.py"
SYMBOLS_FILE="/home/ganzfrisch/finance/stock_analyzer/stock_symbols.txt"
OUTPUT_DIR="/home/ganzfrisch/finance/stock_analyzer/reports/filtered"
TEMP_DIR="/tmp/stock_analyzer_filtered"

# Überprüfen, ob Python-Skript existiert
if [ ! -f "$BATCH_ANALYZER" ]; then
    echo "Fehler: Batch Stock Analyzer nicht gefunden unter $BATCH_ANALYZER"
    exit 1
fi

# Ausgabe- und temporäre Verzeichnisse erstellen
mkdir -p "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

# Zeitstempel für Ausgabedateien
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Helfer-Funktion für Hilfstext
show_help() {
    echo "Optimierter Filter-Analyzer: Analysiert Aktien basierend auf Filterkriterien"
    echo ""
    echo "Verwendung: $0 [OPTION]"
    echo ""
    echo "Optionen:"
    echo "  -p, --pe WERT         Filtert nach Forward P/E kleiner als WERT"
    echo "  -d, --div WERT        Filtert nach Dividendenrendite größer als WERT (in Prozent)"
    echo "  -s, --sector SEKTOR   Filtert nach Sektor (z.B. Technology, Healthcare)"
    echo "  -c, --country LAND    Filtert nach Land (z.B. Germany, United States)"
    echo "  -m, --market-cap WERT Filtert nach Marktkapitalisierung größer als WERT (in Mrd. €)"
    echo "  -r, --recent TAGE     Analysiert nur Aktien mit Daten-Updates in den letzten X Tagen"
    echo "  --all                 Analysiert alle Aktien ohne Filter"
    echo "  -h, --help            Zeigt diese Hilfe an"
    echo ""
    echo "Beispiele:"
    echo "  $0 -p 15 -d 2         # Aktien mit Forward P/E < 15 und Dividendenrendite > 2%"
    echo "  $0 -s Technology      # Alle Technologie-Aktien"
    echo "  $0 -c Germany -d 3    # Deutsche Aktien mit Dividendenrendite > 3%"
    echo ""
}

# Parameter prüfen
if [ "$#" -eq 0 ]; then
    show_help
    exit 1
fi

# Standardwerte
FILTER_PE=""
FILTER_DIV=""
FILTER_SECTOR=""
FILTER_COUNTRY=""
FILTER_MARKET_CAP=""
FILTER_RECENT=""
ANALYZE_ALL=false

# Parameter verarbeiten
while [ "$#" -gt 0 ]; do
    case "$1" in
        -p|--pe)
            FILTER_PE="$2"
            shift 2
            ;;
        -d|--div)
            FILTER_DIV="$2"
            shift 2
            ;;
        -s|--sector)
            FILTER_SECTOR="$2"
            shift 2
            ;;
        -c|--country)
            FILTER_COUNTRY="$2"
            shift 2
            ;;
        -m|--market-cap)
            FILTER_MARKET_CAP="$2"
            shift 2
            ;;
        -r|--recent)
            FILTER_RECENT="$2"
            shift 2
            ;;
        --all)
            ANALYZE_ALL=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Fehler: Unbekannte Option $1"
            show_help
            exit 1
            ;;
    esac
done

echo "===== Optimierter Filter-Analyzer ====="
echo "Ausgabeverzeichnis: $OUTPUT_DIR"
echo ""

# Erstelle ein temporäres Python-Skript für die Filterung
FILTER_SCRIPT="$TEMP_DIR/filter_stocks_${TIMESTAMP}.py"
cat > "$FILTER_SCRIPT" << 'EOL'
#!/usr/bin/env python3

import yfinance as yf
import pandas as pd
import sys
import argparse
from datetime import datetime, timedelta
import json

def filter_stocks(symbols, pe=None, div=None, sector=None, country=None, market_cap=None, recent=None):
    """Filter stocks based on criteria"""
    # Get data for all symbols at once
    tickers = yf.Tickers(" ".join(symbols))
    
    filtered_symbols = []
    filtered_data = {}
    
    for symbol in symbols:
        ticker = tickers.tickers.get(symbol)
        if ticker is None:
            continue
            
        info = ticker.info
        if not info:
            continue
            
        # Apply filters
        
        # Forward P/E filter
        if pe is not None:
            forward_pe = info.get('forwardPE')
            if not forward_pe or forward_pe > pe:
                continue
                
        # Dividend yield filter
        if div is not None:
            div_yield = info.get('dividendYield')
            if not div_yield or div_yield < div / 100.0:  # Convert percentage to decimal
                continue
                
        # Sector filter
        if sector is not None:
            stock_sector = info.get('sector', '')
            if sector.lower() not in stock_sector.lower():
                continue
                
        # Country filter
        if country is not None:
            stock_country = info.get('country', '')
            if country.lower() not in stock_country.lower():
                continue
                
        # Market cap filter (in billions)
        if market_cap is not None:
            cap = info.get('marketCap')
            if not cap or cap < market_cap * 1_000_000_000:
                continue
                
        # Recent data filter
        if recent is not None:
            last_date = None
            try:
                hist = ticker.history(period="5d")
                if not hist.empty:
                    last_date = hist.index[-1].to_pydatetime()
            except:
                pass
                
            if not last_date or (datetime.now() - last_date).days > recent:
                continue
        
        # If all filters passed, add to filtered list
        filtered_symbols.append(symbol)
        
        # Store some basic info for the report
        filtered_data[symbol] = {
            'name': info.get('longName', 'N/A'),
            'sector': info.get('sector', 'N/A'),
            'country': info.get('country', 'N/A'),
            'forwardPE': info.get('forwardPE', 'N/A'),
            'dividendYield': info.get('dividendYield', 'N/A'),
            'marketCap': info.get('marketCap', 'N/A')
        }
    
    return filtered_symbols, filtered_data

def main():
    parser = argparse.ArgumentParser(description='Filter stocks based on criteria')
    parser.add_argument('--symbols', required=True, help='Comma-separated list of symbols')
    parser.add_argument('--pe', type=float, help='Forward P/E less than this value')
    parser.add_argument('--div', type=float, help='Dividend yield greater than this percentage')
    parser.add_argument('--sector', help='Filter by sector')
    parser.add_argument('--country', help='Filter by country')
    parser.add_argument('--market_cap', type=float, help='Market cap greater than this value (in billions)')
    parser.add_argument('--recent', type=int, help='Data updated within this many days')
    parser.add_argument('--output', required=True, help='Output file for filtered symbols')
    parser.add_argument('--data_output', required=True, help='Output file for filtered data')
    
    args = parser.parse_args()
    
    symbols = args.symbols.split(',')
    
    filtered_symbols, filtered_data = filter_stocks(
        symbols,
        pe=args.pe,
        div=args.div,
        sector=args.sector,
        country=args.country,
        market_cap=args.market_cap,
        recent=args.recent
    )
    
    # Save filtered symbols to file
    with open(args.output, 'w') as f:
        f.write('\n'.join(filtered_symbols))
    
    # Save filtered data as JSON
    with open(args.data_output, 'w') as f:
        json.dump(filtered_data, f, indent=2)
    
    print(f"Found {len(filtered_symbols)} symbols matching criteria")
    for symbol in filtered_symbols:
        print(f"- {symbol}: {filtered_data[symbol]['name']}")
    
if __name__ == "__main__":
    main()
EOL

chmod +x "$FILTER_SCRIPT"

# Lese Symbole aus der Datei
SYMBOLS=$(grep -v "^#" "$SYMBOLS_FILE" | awk 'NF' | tr '\n' ',' | sed 's/,$//')

if [ -z "$SYMBOLS" ]; then
    echo "Fehler: Keine gültigen Symbole in $SYMBOLS_FILE gefunden."
    exit 1
fi

# Filter-Kriterien anzeigen
echo "Angewandte Filter:"
[ -n "$FILTER_PE" ] && echo "- Forward P/E < $FILTER_PE"
[ -n "$FILTER_DIV" ] && echo "- Dividendenrendite > $FILTER_DIV%"
[ -n "$FILTER_SECTOR" ] && echo "- Sektor: $FILTER_SECTOR"
[ -n "$FILTER_COUNTRY" ] && echo "- Land: $FILTER_COUNTRY"
[ -n "$FILTER_MARKET_CAP" ] && echo "- Marktkapitalisierung > $FILTER_MARKET_CAP Mrd. €"
[ -n "$FILTER_RECENT" ] && echo "- Daten der letzten $FILTER_RECENT Tage"
[ "$ANALYZE_ALL" = true ] && echo "- Alle Aktien (keine Filter)"
echo ""

# Wenn alle Aktien analysiert werden sollen, überspringe die Filterung
FILTERED_SYMBOLS_FILE="$TEMP_DIR/filtered_symbols_${TIMESTAMP}.txt"
FILTERED_DATA_FILE="$TEMP_DIR/filtered_data_${TIMESTAMP}.json"

if [ "$ANALYZE_ALL" = true ]; then
    echo "Überspringe Filterung, alle Aktien werden analysiert..."
    cp "$SYMBOLS_FILE" "$FILTERED_SYMBOLS_FILE"
else
    # Führe das Filter-Skript aus
    echo "Filtere Aktien nach den angegebenen Kriterien..."
    python "$FILTER_SCRIPT" \
        --symbols "$SYMBOLS" \
        --pe "$FILTER_PE" \
        --div "$FILTER_DIV" \
        --sector "$FILTER_SECTOR" \
        --country "$FILTER_COUNTRY" \
        --market_cap "$FILTER_MARKET_CAP" \
        --recent "$FILTER_RECENT" \
        --output "$FILTERED_SYMBOLS_FILE" \
        --data_output "$FILTERED_DATA_FILE"
fi

# Prüfe, ob gefilterte Symbole vorhanden sind
if [ ! -s "$FILTERED_SYMBOLS_FILE" ]; then
    echo "Keine Aktien gefunden, die den Filterkriterien entsprechen."
    exit 0
fi

# Anzahl der gefilterten Symbole
FILTERED_COUNT=$(wc -l < "$FILTERED_SYMBOLS_FILE")
echo "Analysiere $FILTERED_COUNT gefilterte Aktien..."

# Erstelle Ausgabeverzeichnis für diese Filterung
FILTER_OUTPUT_DIR="$OUTPUT_DIR/filtered_${TIMESTAMP}"
mkdir -p "$FILTER_OUTPUT_DIR"

# Führe die optimierte Batch-Analyse für die gefilterten Symbole durch
echo "Starte optimierte Batch-Analyse..."
# Lese Symbole aus der gefilterten Datei und übergebe sie als Positionsargumente
FILTERED_SYMBOLS=$(grep -v '^#' "$FILTERED_SYMBOLS_FILE" | grep -v '^$' | tr '\n' ' ')

# Prüfen, ob Symbole gefunden wurden
if [ -z "$FILTERED_SYMBOLS" ]; then
    echo "Fehler: Keine Symbole nach Filterung gefunden."
    rm "$FILTERED_SYMBOLS_FILE"
    exit 1
fi

echo "Analysiere folgende gefilterte Symbole: $FILTERED_SYMBOLS"
python "$BATCH_ANALYZER" $FILTERED_SYMBOLS -o "$FILTER_OUTPUT_DIR"

# Erstelle Zusammenfassungsbericht
SUMMARY_FILE="$OUTPUT_DIR/filtered_summary_${TIMESTAMP}.txt"
echo "Erstelle Zusammenfassung in $SUMMARY_FILE..."

{
    echo "===== GEFILTERTE AKTIEN-ANALYSE ====="
    echo "Datum: $(date)"
    echo ""
    echo "Angewandte Filter:"
    [ -n "$FILTER_PE" ] && echo "- Forward P/E < $FILTER_PE"
    [ -n "$FILTER_DIV" ] && echo "- Dividendenrendite > $FILTER_DIV%"
    [ -n "$FILTER_SECTOR" ] && echo "- Sektor: $FILTER_SECTOR"
    [ -n "$FILTER_COUNTRY" ] && echo "- Land: $FILTER_COUNTRY"
    [ -n "$FILTER_MARKET_CAP" ] && echo "- Marktkapitalisierung > $FILTER_MARKET_CAP Mrd. €"
    [ -n "$FILTER_RECENT" ] && echo "- Daten der letzten $FILTER_RECENT Tage"
    [ "$ANALYZE_ALL" = true ] && echo "- Alle Aktien (keine Filter)"
    echo ""
    echo "GEFILTERTE AKTIEN:"
    echo ""
    
    # Füge gefilterte Aktien mit grundlegenden Infos hinzu
    if [ -f "$FILTERED_DATA_FILE" ]; then
        python3 -c '
import json, sys
with open(sys.argv[1], "r") as f:
    data = json.load(f)
for symbol, info in data.items():
    div = info.get("dividendYield", "N/A")
    div_str = f"{div * 100:.2f}%" if isinstance(div, float) else "N/A"
    pe = info.get("forwardPE", "N/A")
    pe_str = f"{pe:.2f}" if isinstance(pe, float) else "N/A"
    print(f"{symbol}: {info.get('name', 'N/A')} | {info.get('sector', 'N/A')} | {info.get('country', 'N/A')} | F-P/E: {pe_str} | Div: {div_str}")
' "$FILTERED_DATA_FILE"
    else
        cat "$FILTERED_SYMBOLS_FILE"
    fi
    
    echo ""
    echo "EMPFEHLUNGEN:"
    
    # Durchsuche alle generierten Dateien nach Empfehlungen
    for output_file in "$FILTER_OUTPUT_DIR"/stock_analysis_*.txt; do
        if [ -f "$output_file" ]; then
            echo "--- $(basename "$output_file") ---" 
            grep -A 5 "AKTIENSTRATEGIE & EMPFEHLUNG" "$output_file" | grep -E "Gesamtempfehlung|Stärken|Schwächen/Risiken" 
            echo ""
        fi
    done
} > "$SUMMARY_FILE"

echo ""
echo "===== Gefilterte Analyse abgeschlossen ====="
echo "Zusammenfassung: $SUMMARY_FILE"
echo "Detaillierte Analysen: $FILTER_OUTPUT_DIR"
echo ""

# Bereinige temporäre Dateien
rm -f "$FILTER_SCRIPT" "$FILTERED_SYMBOLS_FILE" "$FILTERED_DATA_FILE"
