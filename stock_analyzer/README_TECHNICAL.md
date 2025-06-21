# Stock Analyzer - Technische Dokumentation

Diese technische Dokumentation beschreibt den Aufbau, die Komponenten und die Funktionsweise des optimierten Stock Analyzer Systems.

## Systemarchitektur

Das Stock Analyzer System besteht aus mehreren Komponenten:

1. **Kerndatenanalyse-Engine** (`stock_analyzer.py`)
2. **Optimierte Batch-Verarbeitung** (`batch_stock_analyzer.py`)
3. **Shell-Skripte** für verschiedene Anwendungsfälle
4. **Hilfsmodule** für spezifische Funktionen

```
stock_analyzer/
├── stock_analyzer.py         # Kern-Analyselogik
├── batch_stock_analyzer.py   # Optimierte Batch-Verarbeitung
├── config.py                 # Konfigurationsparameter
├── utils.py                  # Hilfsfunktionen
├── dcf_model.py              # DCF-Berechnungen
├── data_viz.py               # Datenvisualisierung
├── recommend_logic.py        # Empfehlungsalgorithmen
├── shell-scripts/
│   ├── run_optimized_analysis.sh     # Optimierte Batch-Analyse
│   ├── optimized_filter_analyzer.sh  # Gefilterte Analyse
│   ├── auto_optimized_analyzer.sh    # Automatisierte Analysen
│   └── track_performance_charts.sh   # Performance-Tracking
└── data/
    └── stock_symbols.txt      # Liste der zu analysierenden Aktien
```

## Komponenten im Detail

### 1. Stock Analyzer (`stock_analyzer.py`)

Die Kernkomponente, die für die Analyse einzelner Aktien verantwortlich ist.

**Hauptklasse:** `StockAnalyzer`

**Wichtige Methoden:**
- `__init__(symbol)` - Initialisiert den Analyzer mit einem Symbol
- `get_stock_data()` - Ruft historische Daten und Unternehmensinformationen ab
- `calculate_technical_indicators()` - Berechnet technische Indikatoren
- `calculate_fundamental_metrics()` - Berechnet fundamentale Kennzahlen
- `analyze_stock()` - Führt die vollständige Analyse durch

**Datenquellen:**
- yfinance API für Marktdaten und Unternehmensinformationen
- Berechnet zusätzliche Metriken auf Basis dieser Daten

### 2. Batch Stock Analyzer (`batch_stock_analyzer.py`)

Die optimierte Version für die Analyse mehrerer Aktien.

**Hauptklasse:** `BatchStockAnalyzer`

**Wichtige Methoden:**
- `__init__(symbols, output_dir)` - Initialisiert mit Liste von Symbolen
- `fetch_all_data_in_batch()` - Holt alle Daten in einem Batch
- `get_ticker_data(symbol)` - Extrahiert Daten für ein Symbol aus dem Cache
- `get_benchmark_data(country)` - Holt passende Benchmark-Daten
- `analyze_stocks(max_workers)` - Führt parallele Analyse durch
- `_analyze_single_stock(symbol, timestamp)` - Analysiert eine einzelne Aktie

**Optimierungen:**
- Reduziert API-Aufrufe durch Bündelung von Anfragen
- Parallele Verarbeitung mit ThreadPoolExecutor
- Robuste Fehlerbehandlung mit StringIO für stdout-Umleitung

### 3. Shell-Skripte

#### `run_optimized_analysis.sh`
Führt die Batch-Analyse für alle Symbole in der stock_symbols.txt durch.

**Hauptfunktionen:**
- Liest Symbole aus der stock_symbols.txt
- Übergibt Symbole als Positionsparameter an batch_stock_analyzer.py
- Erstellt Ausgabeverzeichnisse mit Zeitstempel

#### `optimized_filter_analyzer.sh`
Filtert Aktien nach verschiedenen Kriterien und führt dann die Analyse durch.

**Filterkriterien:**
- Forward P/E Ratio
- Dividendenrendite
- Sektor/Branche
- Land
- Marktkapitalisierung

#### `auto_optimized_analyzer.sh`
Automatisiert die regelmäßige Ausführung der Analyse, ideal für Cron-Jobs.

**Funktionen:**
- Protokollierung der Ausführung
- Optionales E-Mail-Reporting
- Fehlerbehandlung und Status-Tracking

## Datenfluss

1. **Datenabruf:**
   - Batch-Abruf aller Ticker-Informationen
   - Batch-Abruf aller historischen Daten
   - Batch-Abruf aller Benchmark-Daten

2. **Datenverarbeitung:**
   - Verteilung der Daten an einzelne Analyzer-Instanzen
   - Parallele Berechnung von Indikatoren und Kennzahlen
   - DCF-Modell und Szenarioberechnung

3. **Ausgabe:**
   - Konsolenausgabe oder Datei-Output
   - Strukturierte Berichte mit tabellarischen Daten
   - ASCII-Visualisierungen für Konsolendarstellung

## Optimierungen und Verbesserungen

### API-Optimierungen
- Gruppierte API-Anfragen reduzieren die Anzahl der Netzwerkanfragen
- Daten-Caching für wiederverwendbare Informationen
- Benchmark-Daten werden einmal für alle Symbole abgerufen

### Robuste Fehlerbehandlung
- Verbesserte Exception-Behandlung für die Ausgabeumleitung
- Nutzung von `io.StringIO()` für sichere Erfassung der Ausgabe
- Try-except-finally-Blöcke zur Sicherstellung korrekter Ressourcenfreigabe

### Parallelisierung
- ThreadPoolExecutor für parallele Verarbeitung
- Konfigurierbare Anzahl paralleler Worker
- Optimierungen für kleine Symbol-Listen (sequenzielle Verarbeitung)

## Bekannte Einschränkungen

1. **Datenqualität:** Abhängig von der Qualität und Verfügbarkeit der Daten in der Yahoo Finance API.
2. **Fehlende Daten:** Nicht alle Kennzahlen sind für alle Aktien verfügbar.
3. **API-Limits:** Bei sehr großen Symbol-Listen könnten API-Ratenbegrenzungen auftreten.
4. **DCF-Modell:** Verwendet vereinfachte Annahmen und sollte nicht als alleinige Entscheidungsgrundlage dienen.

## Debugging & Entwicklung

### Fehlerdiagnose
- Fehler beim Datenabruf werden im Terminal und in den Protokollen angezeigt
- Bei Ausgabeleitungsproblemen die aktuelle (verbesserte) Version verwenden

### Erweiterungen
- Neue Indikatoren können in `stock_analyzer.py` hinzugefügt werden
- Für neue Filterkriterien `optimized_filter_analyzer.sh` anpassen
- Zusätzliche Visualisierungen können zu `data_viz.py` hinzugefügt werden

## Testfälle

Das System wurde umfassend mit den folgenden Testsymbolen getestet:

| Symbol  | Unternehmen          | Land/Markt    | Besonderheiten                  |
|---------|----------------------|---------------|----------------------------------|
| NOVN.SW | Novartis             | Schweiz       | Internationale Aktie            |
| NOV.DE  | Novo Nordisk         | Deutschland   | Internationale Aktie            |
| BAYN.DE | Bayer                | Deutschland   | Aktie mit volatiler Geschichte  |
| RIVN    | Rivian               | USA           | Tech-Aktie mit negativem P/E    |
| XPEV    | XPeng                | China (ADR)   | Emerging Markets Aktie          |
| MDT     | Medtronic            | USA           | Large-Cap Healthcare            |

Diese Auswahl stellt sicher, dass das System mit verschiedenen Aktientypen, Märkten und Datenverfügbarkeiten umgehen kann.
