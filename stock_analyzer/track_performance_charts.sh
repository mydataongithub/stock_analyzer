#!/bin/bash

# Performance Chart Generator für Stock Analyzer
# Dieses Skript generiert Performancecharts für empfohlene Aktien und vergleicht sie mit Benchmarks

OUTPUT_DIR="/home/ganzfrisch/finance/stock_analyzer/reports"
CHARTS_DIR="$OUTPUT_DIR/charts"
TRACKING_DIR="$OUTPUT_DIR/tracking"

# Python-Skript für Chart-Generierung
CHART_SCRIPT="/home/ganzfrisch/finance/stock_analyzer/generate_charts.py"

# Überprüfen ob Argument übergeben wurde (Zeitstempel)
if [ $# -eq 0 ]; then
    echo "Bitte Zeitstempel als Argument übergeben, z.B.:"
    echo "$0 20250621_120000"
    echo "Oder 'latest' für die neuesten Dateien."
    exit 1
fi

TIMESTAMP="$1"

# Benchmark-Indizes (können später erweitert werden)
BENCHMARKS=("^GDAXI" "^GSPC" "^IXIC")

# Bei "latest" den neuesten Zeitstempel finden
if [ "$TIMESTAMP" == "latest" ]; then
    TIMESTAMP=$(ls -1 "$OUTPUT_DIR"/buy_recommendations_*.txt 2>/dev/null | sort -r | head -1 | sed -E 's/.*buy_recommendations_([0-9]+_[0-9]+)\.txt/\1/')
    
    if [ -z "$TIMESTAMP" ]; then
        echo "Keine Empfehlungsdateien gefunden"
        exit 1
    fi
    
    echo "Neuester Zeitstempel gefunden: $TIMESTAMP"
fi

# Verzeichnisse erstellen
mkdir -p "$CHARTS_DIR"
mkdir -p "$TRACKING_DIR"

# Prüfen ob Dateien existieren
BUY_FILE="$OUTPUT_DIR/buy_recommendations_${TIMESTAMP}.txt"
SELL_FILE="$OUTPUT_DIR/sell_recommendations_${TIMESTAMP}.txt"

if [ ! -f "$BUY_FILE" ] || [ ! -f "$SELL_FILE" ]; then
    echo "Fehler: Eine oder mehrere erforderliche Dateien wurden nicht gefunden für Zeitstempel $TIMESTAMP"
    exit 1
fi

# Python-Skript für Charts erstellen, falls es noch nicht existiert
if [ ! -f "$CHART_SCRIPT" ]; then
    cat > "$CHART_SCRIPT" << 'EOL'
#!/usr/bin/env python3

import sys
import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime, timedelta
import yfinance as yf
from matplotlib.ticker import FuncFormatter

def format_percentage(x, pos):
    """Format tick labels as percentages"""
    return f"{x:.1f}%"

def download_data_once(symbols, benchmark_symbols, start_date):
    """Download stock data for all symbols once and return a DataFrame"""
    end_date = datetime.now().strftime('%Y-%m-%d')
    all_symbols = list(set(symbols + benchmark_symbols))  # Entferne Duplikate
    print(f"Downloading data for {len(all_symbols)} unique symbols...")
    return yf.download(all_symbols, start=start_date, end=end_date)

def generate_performance_chart(symbols, benchmark_symbols, start_date, output_file, title, data=None):
    """Generate performance comparison chart for a list of stock symbols"""
    # Download data if not provided
    if data is None:
        data = download_data_once(symbols, benchmark_symbols, start_date)
    
    # Use Adjusted Close prices
    adj_close_data = data['Adj Close']
    
    # Calculate performance (percentage change relative to first day)
    performance_df = pd.DataFrame()
    
    for symbol in symbols + benchmark_symbols:
        if symbol in adj_close_data.columns:
            # Skip if we don't have enough data
            if len(adj_close_data[symbol].dropna()) < 5:
                continue
                
            # Calculate percentage change
            start_price = adj_close_data[symbol].dropna().iloc[0]
            performance_df[symbol] = (adj_close_data[symbol] / start_price - 1) * 100
    
    if performance_df.empty:
        print(f"No valid data found for the provided symbols: {symbols}")
        return False
    
    # Create plot
    plt.figure(figsize=(12, 8))
    
    # Plot stock performance
    for symbol in symbols:
        if symbol in performance_df.columns:
            plt.plot(performance_df.index, performance_df[symbol], linewidth=2, label=symbol)
    
    # Plot benchmark performance with dashed lines
    for benchmark in benchmark_symbols:
        if benchmark in performance_df.columns:
            label = benchmark.replace('^', '')
            plt.plot(performance_df.index, performance_df[benchmark], linewidth=1.5, 
                    linestyle='--', label=label)
    
    # Format the plot
    plt.title(title, fontsize=16)
    plt.xlabel('Datum', fontsize=12)
    plt.ylabel('Performance (%)', fontsize=12)
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.legend(loc='best', fontsize=10)
    
    # Format x-axis dates
    plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%d-%m-%Y'))
    plt.gca().xaxis.set_major_locator(mdates.MonthLocator())
    plt.gcf().autofmt_xdate()
    
    # Format y-axis as percentage
    plt.gca().yaxis.set_major_formatter(FuncFormatter(format_percentage))
    
    # Add horizontal line at 0%
    plt.axhline(y=0, color='black', linestyle='-', alpha=0.3)
    
    # Save the plot
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"Chart saved to {output_file}")
    return True

def create_performance_table(symbols, benchmark_symbols, start_date, output_file, data=None):
    """Create performance table for stocks and benchmarks"""
    # Download data if not provided
    if data is None:
        data = download_data_once(symbols, benchmark_symbols, start_date)
    
    # Use Adjusted Close prices
    adj_close_data = data['Adj Close']
    
    # Calculate performance for different time periods
    performance = pd.DataFrame(index=all_symbols)
    
    now = datetime.now()
    
    # Calculate relevant dates
    week_ago = (now - timedelta(days=7)).strftime('%Y-%m-%d')
    month_ago = (now - timedelta(days=30)).strftime('%Y-%m-%d')
    three_months_ago = (now - timedelta(days=90)).strftime('%Y-%m-%d')
    year_start = f"{now.year}-01-01"
    
    # Add columns for different time periods
    performance['1W'] = None  # 1 week
    performance['1M'] = None  # 1 month
    performance['3M'] = None  # 3 months
    performance['YTD'] = None  # Year to Date
    performance['Since Recommendation'] = None  # Since recommendation date
    
    # Calculate performance for each symbol and period
    for symbol in all_symbols:
        if symbol in data.columns:
            symbol_data = data[symbol].dropna()
            if len(symbol_data) < 5:
                continue
                
            # Latest price
            latest_price = symbol_data.iloc[-1]
            
            # 1 week
            try:
                week_price = symbol_data.loc[:week_ago].iloc[-1]
                performance.loc[symbol, '1W'] = (latest_price / week_price - 1) * 100
            except:
                pass
            
            # 1 month
            try:
                month_price = symbol_data.loc[:month_ago].iloc[-1]
                performance.loc[symbol, '1M'] = (latest_price / month_price - 1) * 100
            except:
                pass
            
            # 3 months
            try:
                three_month_price = symbol_data.loc[:three_months_ago].iloc[-1]
                performance.loc[symbol, '3M'] = (latest_price / three_month_price - 1) * 100
            except:
                pass
            
            # Year to Date
            try:
                year_start_price = symbol_data.loc[:year_start].iloc[-1]
                performance.loc[symbol, 'YTD'] = (latest_price / year_start_price - 1) * 100
            except:
                pass
            
            # Since recommendation date
            try:
                start_price = symbol_data.iloc[0]
                performance.loc[symbol, 'Since Recommendation'] = (latest_price / start_price - 1) * 100
            except:
                pass
    
    # Format the table
    performance = performance.round(2)
    
    # Save to CSV
    performance.to_csv(output_file)
    print(f"Performance table saved to {output_file}")
    
    return performance

def extract_symbols_from_file(file_path):
    """Extract stock symbols from a recommendations file"""
    symbols = []
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            for line in content.split('\n'):
                if line.startswith('Symbol:'):
                    symbol = line.replace('Symbol:', '').strip()
                    symbols.append(symbol)
        return symbols
    except Exception as e:
        print(f"Error reading file {file_path}: {e}")
        return []

def main():
    if len(sys.argv) < 5:
        print("Usage: generate_charts.py <buy_file> <sell_file> <benchmarks> <output_dir> <timestamp>")
        sys.exit(1)
    
    buy_file = sys.argv[1]
    sell_file = sys.argv[2]
    benchmarks = sys.argv[3].split(',')
    output_dir = sys.argv[4]
    timestamp = sys.argv[5]
    
    # Extract recommendation date from timestamp
    recommendation_date = f"{timestamp[:4]}-{timestamp[4:6]}-{timestamp[6:8]}"
    
    # Get buy and sell symbols
    buy_symbols = extract_symbols_from_file(buy_file)
    sell_symbols = extract_symbols_from_file(sell_file)
    
    print(f"Found {len(buy_symbols)} buy recommendations and {len(sell_symbols)} sell recommendations")
    
    # Lade alle Daten einmalig
    all_symbols = list(set(buy_symbols + sell_symbols + benchmarks))
    if all_symbols:
        print(f"Downloading data for {len(all_symbols)} unique symbols in one batch...")
        stock_data = download_data_once(all_symbols, benchmarks, recommendation_date)
    else:
        print("No symbols found to analyze")
        return
    
    # Generate buy recommendations chart
    if buy_symbols:
        buy_chart_file = f"{output_dir}/buy_performance_{timestamp}.png"
        buy_csv_file = f"{output_dir}/buy_performance_{timestamp}.csv"
        
        title = f"Performance der Kaufempfehlungen (seit {recommendation_date})"
        success = generate_performance_chart(buy_symbols, benchmarks, recommendation_date, 
                                            buy_chart_file, title, data=stock_data)
        
        if success:
            create_performance_table(buy_symbols, benchmarks, recommendation_date, 
                                    buy_csv_file, data=stock_data)
    
    # Generate sell recommendations chart
    if sell_symbols:
        sell_chart_file = f"{output_dir}/sell_performance_{timestamp}.png"
        sell_csv_file = f"{output_dir}/sell_performance_{timestamp}.csv"
        
        title = f"Performance der Verkaufsempfehlungen (seit {recommendation_date})"
        success = generate_performance_chart(sell_symbols, benchmarks, recommendation_date, 
                                           sell_chart_file, title, data=stock_data)
        
        if success:
            create_performance_table(sell_symbols, benchmarks, recommendation_date, 
                                   sell_csv_file, data=stock_data)

if __name__ == "__main__":
    main()
EOL

    # Mache das Skript ausführbar
    chmod +x "$CHART_SCRIPT"
    echo "Chart-Generierungs-Skript erstellt: $CHART_SCRIPT"
fi

# Prüfen, ob die notwendigen Python-Pakete installiert sind
echo "Prüfe und installiere notwendige Python-Pakete..."
pip install --quiet pandas numpy matplotlib yfinance || {
    echo "Fehler: Konnte notwendige Python-Pakete nicht installieren. Bitte installieren Sie manuell:"
    echo "pip install pandas numpy matplotlib yfinance"
    exit 1
}

# Konvertiere Benchmarks in durch Komma getrennte Liste
BENCHMARK_LIST=$(IFS=,; echo "${BENCHMARKS[*]}")

# Führe Python-Skript aus
echo "Generiere Performance-Charts..."
python3 "$CHART_SCRIPT" "$BUY_FILE" "$SELL_FILE" "$BENCHMARK_LIST" "$CHARTS_DIR" "$TIMESTAMP"

# Tracking-Datei für langfristige Performance-Verfolgung aktualisieren
TRACKING_FILE="$TRACKING_DIR/recommendation_tracking.csv"
RECOMMENDATION_DATE=$(echo $TIMESTAMP | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3/')

# Extrahiere Symbole und Empfehlungen
echo "Aktualisiere Tracking-Datei..."
BUY_SYMBOLS=$(grep "Symbol:" "$BUY_FILE" | sed 's/Symbol: \(.*\)/\1/')
SELL_SYMBOLS=$(grep "Symbol:" "$SELL_FILE" | sed 's/Symbol: \(.*\)/\1/')

# Erstelle oder aktualisiere Header der Tracking-Datei
if [ ! -f "$TRACKING_FILE" ]; then
    echo "Datum,Symbol,Empfehlung,Unternehmen,Startpreis,Aktueller Preis,Performance (%)" > "$TRACKING_FILE"
fi

# Temporäre Python-Datei erstellen, um alle Kursdaten in einem Schritt zu laden
TEMP_SCRIPT=$(mktemp --suffix=.py)
cat > "$TEMP_SCRIPT" << 'EOL'
import sys
import yfinance as yf
import json

symbols = sys.argv[1].split(',')

# Lade alle Kursdaten in einem Schritt
data = yf.download(symbols, period='1d')
prices = {}

# Extrahiere den letzten Schlusskurs für jedes Symbol
for symbol in symbols:
    try:
        # Wenn es nur ein Symbol gibt, hat data eine andere Struktur
        if len(symbols) == 1:
            close_price = data['Close'].iloc[-1]
        else:
            close_price = data['Close'][symbol].iloc[-1]
        prices[symbol] = round(close_price, 2)
    except Exception as e:
        prices[symbol] = None

# Gib die Ergebnisse als JSON aus
print(json.dumps(prices))
EOL

# Alle Symbole kombinieren (ohne Duplikate)
ALL_SYMBOLS=$(echo "$BUY_SYMBOLS $SELL_SYMBOLS" | tr ' ' '\n' | sort -u | tr '\n' ' ')
# Formatiere für Python-Skript
ALL_SYMBOLS_STR=$(echo $ALL_SYMBOLS | tr ' ' ',')

echo "Hole aktuelle Kursdaten für alle Symbole in einem Schritt..."
# Führe das Python-Skript aus, um alle Kurse auf einmal zu laden
PRICES_JSON=$(python3 "$TEMP_SCRIPT" "$ALL_SYMBOLS_STR")
# Lösche das temporäre Skript
rm "$TEMP_SCRIPT"

# Füge Kaufempfehlungen hinzu
for symbol in $BUY_SYMBOLS; do
    # Extrahiere Unternehmen und Startpreis
    company=$(grep -A 1 "Symbol: $symbol" "$BUY_FILE" | grep "Unternehmen:" | sed 's/Unternehmen: \(.*\)/\1/')
    start_price=$(grep -A 3 "Symbol: $symbol" "$BUY_FILE" | grep "Aktueller Kurs:" | sed 's/Aktueller Kurs: \(.*\)/\1/' | sed 's/[^0-9.,]//g')
    
    # Hole den aktuellen Preis aus dem JSON-Ergebnis
    current_price=$(echo "$PRICES_JSON" | python3 -c "import json, sys; prices = json.load(sys.stdin); print(prices.get('$symbol', 'None'))")
    
    # Berechne Performance
    performance="N/A"
    if [ -n "$start_price" ] && [ -n "$current_price" ] && [ "$current_price" != "None" ]; then
        # Konvertiere Preisformate für Berechnung
        start_price_num=$(echo $start_price | sed 's/,/./g')
        performance=$(python3 -c "print(round(($current_price / $start_price_num - 1) * 100, 2))")
    fi
    
    # Füge Daten zum Tracking hinzu
    echo "$RECOMMENDATION_DATE,$symbol,BUY,$company,$start_price,$current_price,$performance" >> "$TRACKING_FILE"
done

# Füge Verkaufsempfehlungen hinzu
for symbol in $SELL_SYMBOLS; do
    # Extrahiere Unternehmen und Startpreis
    company=$(grep -A 1 "Symbol: $symbol" "$SELL_FILE" | grep "Unternehmen:" | sed 's/Unternehmen: \(.*\)/\1/')
    start_price=$(grep -A 3 "Symbol: $symbol" "$SELL_FILE" | grep "Aktueller Kurs:" | sed 's/Aktueller Kurs: \(.*\)/\1/' | sed 's/[^0-9.,]//g')
    
    # Hole den aktuellen Preis aus dem JSON-Ergebnis
    current_price=$(echo "$PRICES_JSON" | python3 -c "import json, sys; prices = json.load(sys.stdin); print(prices.get('$symbol', 'None'))")
    
    # Berechne Performance
    performance="N/A"
    if [ -n "$start_price" ] && [ -n "$current_price" ] && [ "$current_price" != "None" ]; then
        # Konvertiere Preisformate für Berechnung
        start_price_num=$(echo $start_price | sed 's/,/./g')
        performance=$(python3 -c "print(round(($current_price / $start_price_num - 1) * 100, 2))")
    fi
    
    # Für Verkaufsempfehlungen ist ein negativer Wert eigentlich gut
    echo "$RECOMMENDATION_DATE,$symbol,SELL,$company,$start_price,$current_price,$performance" >> "$TRACKING_FILE"
done

echo "Fertig! Performance-Charts und Tracking-Daten wurden erstellt."
echo "Charts: $CHARTS_DIR"
echo "Tracking-Datei: $TRACKING_FILE"

# Bei Bedarf HTML-Report aktualisieren
if [ -f "/home/ganzfrisch/finance/stock_analyzer/generate_html_report.sh" ]; then
    read -p "Möchten Sie auch den HTML-Report aktualisieren? (j/n): " update_html
    if [[ "$update_html" == "j" || "$update_html" == "J" ]]; then
        /home/ganzfrisch/finance/stock_analyzer/generate_html_report.sh "$TIMESTAMP"
    fi
fi
