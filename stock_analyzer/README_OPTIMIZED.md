# Stock Analyzer - Optimierte Version

Dieses Projekt bietet eine umfassende Analyse von Aktien mit optimierten API-Anfragen.

## Optimierungen

Die folgenden Optimierungen wurden implementiert, um redundante API-Aufrufe zu minimieren:

1. **Batch Stock Analyzer (`batch_stock_analyzer.py`)**:
   - Lädt alle Tickerdaten für mehrere Symbole in einem einzigen API-Aufruf
   - Gruppiert historische Daten in einer Batch-Anfrage
   - Erstellt einen Daten-Cache für alle Aktien und Benchmarks
   - Reduziert die API-Aufrufe drastisch bei der Analyse mehrerer Aktien

2. **Optimierte Batch-Ausführung (`run_optimized_analysis.sh`)**:
   - Verwendet den Batch Stock Analyzer für optimierte Verarbeitung
   - Reduziert die API-Auslastung und verbessert die Ausführungsgeschwindigkeit
   - Erzeugt dieselben Ausgabeformate und -berichte wie die Standardversion

3. **Automatisierte optimierte Ausführung (`auto_optimized_analyzer.sh`)**:
   - Führt die optimierte Analyse als geplanten Cron-Job aus
   - Protokolliert die Ausführung und kann optional E-Mail-Berichte senden

## Verwendung

### Einzelne Aktienanalyse

Für die Analyse einer einzelnen Aktie:

```bash
python stock_analyzer.py SYMBOL
```

Beispiel: `python stock_analyzer.py AAPL`

### Optimierte Batch-Analyse mehrerer Aktien

Für die optimierte Analyse mehrerer Aktien:

```bash
python batch_stock_analyzer.py SYMBOL1 SYMBOL2 SYMBOL3
```

Oder mit zusätzlichen Optionen:

```bash
python batch_stock_analyzer.py -o output_directory -w 4 -f stock_symbols.txt
```

Optionen:

- `-o, --output-dir`: Ausgabeverzeichnis für die Analyseberichte
- `-w, --workers`: Anzahl der parallelen Worker (Standard: 4)
- `-f, --file`: Datei mit Aktien-Symbolen (eine pro Zeile)

### Ausführung der optimierten Batch-Analyse

```bash
./run_optimized_analysis.sh
```

Dieses Skript:

1. Führt den Batch Stock Analyzer aus
2. Erstellt Zusammenfassungen und Empfehlungslisten
3. Generiert optional einen HTML-Bericht

### Automatisierte Ausführung

Für regelmäßige automatische Analysen kann `auto_optimized_analyzer.sh` als Cron-Job eingerichtet werden.

Beispiel für wöchentliche Ausführung (jeden Sonntag um 5 Uhr morgens):

```bash
0 5 * * 0 /home/ganzfrisch/finance/stock_analyzer/auto_optimized_analyzer.sh
```

## Vorteile der Optimierung

- **Reduzierte API-Belastung**: Nur ein API-Aufruf pro Datentyp, unabhängig von der Anzahl der Aktien
- **Schnellere Ausführung**: Deutlich verbesserte Performance, besonders bei vielen Aktien
- **Effizienter Cache**: Wiederverwendung bereits abgerufener Daten
- **Parallele Verarbeitung**: Multi-Threading für schnellere Analyse
