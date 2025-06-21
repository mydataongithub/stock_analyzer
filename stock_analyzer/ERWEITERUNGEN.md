# Stock Analyzer Erweiterungen - Handbuch

Dieses Handbuch beschreibt die neuen Erweiterungen für das Stock Analyzer System.

## 1. HTML-Report Generator

Der HTML-Report Generator verwandelt die Textausgaben des Stock Analyzers in interaktive HTML-Berichte mit Sortier- und Filterfunktionen.

**Verwendung:**
```bash
./generate_html_report.sh TIMESTAMP
```
oder
```bash
./generate_html_report.sh latest
```

**Funktionen:**
- Übersichtliche Darstellung aller Analysen in einer durchsuchbaren Tabelle
- Separate Tabs für Zusammenfassung, Kauf- und Verkaufsempfehlungen
- Detailansichten für alle analysierten Aktien
- Farbliche Kennzeichnung von Kauf- und Verkaufsempfehlungen
- Responsive Design für verschiedene Bildschirmgrößen

**Ausgabe:**
- HTML-Dateien im Verzeichnis `/home/ganzfrisch/finance/stock_analyzer/reports/html/`

## 2. Performance-Chart Generator

Erstellt visuelle Darstellungen der Performance von Kauf- und Verkaufsempfehlungen im Vergleich zu Benchmark-Indizes.

**Verwendung:**
```bash
./track_performance_charts.sh TIMESTAMP
```
oder
```bash
./track_performance_charts.sh latest
```

**Funktionen:**
- Generiert Performancecharts für Kauf- und Verkaufsempfehlungen
- Vergleicht die Performance mit wichtigen Benchmark-Indizes (DAX, S&P 500, NASDAQ)
- Erstellt CSV-Dateien mit detaillierten Performance-Kennzahlen
- Verfolgt die Performance über verschiedene Zeiträume (1W, 1M, 3M, YTD, seit Empfehlung)
- Aktualisiert eine zentrale Tracking-Datei für historische Vergleiche

**Abhängigkeiten:**
- Python mit pandas, numpy, matplotlib und yfinance

**Ausgabe:**
- PNG-Charts im Verzeichnis `/home/ganzfrisch/finance/stock_analyzer/reports/charts/`
- CSV-Dateien mit detaillierten Performance-Daten
- Tracking-Datei: `/home/ganzfrisch/finance/stock_analyzer/reports/tracking/recommendation_tracking.csv`

## 3. Filter-Tool 

Ermöglicht die Filterung von Aktienanalysen nach verschiedenen Kriterien.

**Verwendung:**
```bash
./filter_analyzer.sh TIMESTAMP FILTER_OPTION WERT
```
oder
```bash
./filter_analyzer.sh latest FILTER_OPTION WERT
```

**Filter-Optionen:**
- `--pe-max <max>` : Filtern nach maximalem KGV (Forward P/E)
- `--pe-min <min>` : Filtern nach minimalem KGV (Forward P/E)
- `--div-min <min>` : Filtern nach Mindest-Dividendenrendite (%)
- `--upside-min <min>` : Filtern nach Minimum Upside-Potenzial (%)
- `--sector <sector>` : Filtern nach Sektor
- `--country <country>` : Filtern nach Land
- `--analyst-rating <min>` : Filtern nach Mindest-Analystenbewertung (1-5)
- `--dcf-discount <min>` : Filtern nach DCF-Discount (%, min)

**Beispiele:**
```bash
./filter_analyzer.sh latest --pe-max 15
./filter_analyzer.sh latest --div-min 3.5
./filter_analyzer.sh latest --upside-min 20
./filter_analyzer.sh latest --sector "Technology"
./filter_analyzer.sh latest --country "Germany"
```

**Ausgabe:**
- Gefilterte Analysedateien im Verzeichnis `/home/ganzfrisch/finance/stock_analyzer/reports/filters/`
- Option zur Erstellung eines HTML-Reports für die gefilterten Ergebnisse

## 4. Alert-System

Das Alert-System überwacht Aktien auf bestimmte Ereignisse und sendet Benachrichtigungen.

**Einrichtung:**
```bash
./setup_alerts.sh
```

Dies erstellt:
- Eine Konfigurationsdatei für Alerts (`/home/ganzfrisch/finance/stock_analyzer/config/alert_config.json`)
- Ein Python-Skript zur Alert-Generierung
- Ein Bash-Skript zum Ausführen der Alerts

**Alert-Typen:**
- Signifikante Kursveränderungen
- Änderungen bei Analysten-Bewertungen
- Ungewöhnlich hohes Handelsvolumen
- Dividendenankündigungen und -termine
- Bevorstehende Ergebnisberichte

**Verwendung:**
```bash
./reports/alerts/run_alerts.sh                # Prüfe die Aktien in der Watchlist
./reports/alerts/run_alerts.sh --from-file    # Prüfe alle Aktien aus stock_symbols.txt
./reports/alerts/run_alerts.sh --symbol AAPL  # Prüfe eine einzelne Aktie
./reports/alerts/run_alerts.sh --config-only  # Zeige die aktuelle Konfiguration
./reports/alerts/run_alerts.sh --add-watchlist # Füge Aktien aus stock_symbols.txt zur Watchlist hinzu
```

**Benachrichtigungsmethoden:**
- Log-Dateien
- Terminal-Ausgabe
- E-Mail (erfordert zusätzliche Konfiguration)

**Automatisierung:**
Für regelmäßige Überprüfungen können Sie einen Cron-Job einrichten:
```
0 9,12,15,18 * * 1-5 /home/ganzfrisch/finance/stock_analyzer/reports/alerts/run_alerts.sh --quiet
```

## Integration

Alle neuen Tools sind so gestaltet, dass sie nahtlos mit dem bestehenden Stock Analyzer System zusammenarbeiten. Sie können verwendet werden um:

1. Große Mengen von Aktien zu analysieren (`run_analysis.sh`)
2. Die Ergebnisse visuell ansprechend darzustellen (`generate_html_report.sh`)
3. Die Performance der Empfehlungen zu verfolgen (`track_performance_charts.sh`)
4. Spezifische Aktien nach bestimmten Kriterien zu finden (`filter_analyzer.sh`)
5. Wichtige Ereignisse zu überwachen und benachrichtigt zu werden (`setup_alerts.sh`)

## Empfohlener Arbeitsablauf

1. **Tägliche Analyse ausführen**
   ```bash
   ./run_analysis.sh
   ```

2. **HTML-Report erstellen**
   ```bash
   ./generate_html_report.sh latest
   ```

3. **Nach interessanten Aktien filtern**
   ```bash
   ./filter_analyzer.sh latest --pe-max 15 --div-min 2.5
   ```

4. **Performance überprüfen**
   ```bash
   ./track_performance_charts.sh latest
   ```

5. **Watchlist aktualisieren und Alerts konfigurieren**
   ```bash
   ./reports/alerts/run_alerts.sh --add-watchlist
   ```

## Hinweise zur Konfiguration

### E-Mail-Benachrichtigungen einrichten

Um E-Mail-Benachrichtigungen für das Alert-System zu aktivieren:

1. Öffnen Sie die Datei `/home/ganzfrisch/finance/stock_analyzer/config/generate_alerts.py`
2. Suchen Sie nach dem Kommentar "Uncomment and configure this section to actually send emails"
3. Entfernen Sie die Kommentarzeichen und konfigurieren Sie Ihre E-Mail-Einstellungen:
   ```python
   sender_email = "ihre_email@gmail.com"
   password = "ihr_app_passwort"  # Verwenden Sie ein App-Passwort für Gmail
   ```

### Benchmark-Indizes anpassen

Um die Benchmark-Indizes für das Performance-Tracking anzupassen:

1. Öffnen Sie die Datei `/home/ganzfrisch/finance/stock_analyzer/track_performance_charts.sh`
2. Suchen Sie nach der Zeile `BENCHMARKS=("^GDAXI" "^GSPC" "^IXIC")`
3. Ändern Sie die Liste der Benchmark-Symbole nach Ihren Wünschen
