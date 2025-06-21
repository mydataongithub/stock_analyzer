#!/bin/bash

# Automatische Ausführung des optimierten Stock Analyzers
# Dieses Skript kann als Cron-Job eingerichtet werden, um regelmäßige Analysen zu ermöglichen
# Beispiel für einen wöchentlichen Cron-Job (jeden Sonntag um 5 Uhr morgens):
# 0 5 * * 0 /home/ganzfrisch/finance/stock_analyzer/auto_optimized_analyzer.sh

# Pfade
ANALYZER_SCRIPT="/home/ganzfrisch/finance/stock_analyzer/run_optimized_analysis.sh"
LOG_DIR="/home/ganzfrisch/finance/stock_analyzer/logs"
LOG_FILE="$LOG_DIR/auto_optimized_analyzer_$(date +"%Y%m%d").log"

# E-Mail-Konfiguration (optional)
EMAIL_RECIPIENT="your.email@example.com"
EMAIL_SUBJECT="Stock Analyzer - Optimierte Wöchentliche Analyse $(date +"%Y-%m-%d")"
EMAIL_BODY="Anbei die wöchentliche optimierte Aktienanalyse (reduzierte API-Aufrufe)."
SEND_EMAIL=false  # Auf 'true' setzen, um E-Mails zu aktivieren

# Erstelle Log-Verzeichnis, falls es nicht existiert
mkdir -p "$LOG_DIR"

# Starte die Analyse und protokolliere die Ausgabe
echo "===== AUTO OPTIMIZED STOCK ANALYZER =====" > "$LOG_FILE"
echo "Startzeit: $(date)" >> "$LOG_FILE"
echo "============================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Ausführen des optimierten Haupt-Skripts
bash "$ANALYZER_SCRIPT" >> "$LOG_FILE" 2>&1
RESULT=$?

echo "" >> "$LOG_FILE"
echo "============================" >> "$LOG_FILE"
echo "Endzeit: $(date)" >> "$LOG_FILE"

if [ $RESULT -eq 0 ]; then
    echo "Status: ERFOLG" >> "$LOG_FILE"
    STATUS_MSG="Optimierte Aktienanalyse erfolgreich abgeschlossen"
else
    echo "Status: FEHLER (Code: $RESULT)" >> "$LOG_FILE"
    STATUS_MSG="FEHLER bei der optimierten Aktienanalyse (Code: $RESULT)"
fi

echo "$STATUS_MSG" >> "$LOG_FILE"
echo "============================" >> "$LOG_FILE"

# Optional: Sende E-Mail mit den Ergebnissen
if [ "$SEND_EMAIL" = true ]; then
    LATEST_REPORTS=$(find "/home/ganzfrisch/finance/stock_analyzer/reports" -name "*.html" -mtime -1 | tr '\n' ' ')
    
    if [ -n "$LATEST_REPORTS" ]; then
        echo "Sende E-Mail mit den neuesten Reports an $EMAIL_RECIPIENT..."
        echo "$EMAIL_BODY" | mail -s "$EMAIL_SUBJECT" -a "$LATEST_REPORTS" "$EMAIL_RECIPIENT"
        echo "E-Mail gesendet: $STATUS_MSG" >> "$LOG_FILE"
    else
        echo "Keine aktuellen Reports gefunden." >> "$LOG_FILE"
    fi
fi

echo "Optimierte Analyse abgeschlossen. Log-Datei: $LOG_FILE"
