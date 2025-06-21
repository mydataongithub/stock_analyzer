# Stock Analyzer - Benutzerhandbuch

Dieses Dokument erklärt die Verwendung des optimierten Stock Analyzer Systems für die Analyse von Aktien und Wertpapieren.

## Inhaltsverzeichnis

1. [Übersicht](#übersicht)
2. [Installation und Voraussetzungen](#installation-und-voraussetzungen)
3. [Schnellstart](#schnellstart)
4. [Grundlegende Befehle](#grundlegende-befehle)
5. [Optimierte Batch-Analyse](#optimierte-batch-analyse)
6. [Nutzungsszenarien](#nutzungsszenarien)
7. [Fehlerbehebung](#fehlerbehebung)
8. [FAQ](#faq)

## Übersicht

Das Stock Analyzer System ist ein leistungsstarkes Werkzeug zur Analyse von Aktien, das sowohl technische als auch fundamentale Analysen durchführt. Das System kann einzelne Aktien oder Gruppen von Aktien analysieren und bietet umfassende Informationen zu:

- Technischen Indikatoren (RSI, gleitende Durchschnitte, etc.)
- Fundamentaldaten (KGV, Dividendenrendite, etc.)
- DCF-Bewertung mit Szenarioanalyse
- Dividendenhistorie und -prognose
- Kursentwicklung und Performance-Vergleich
- Automatische Handelsempfehlungen

Die optimierte Version des Systems reduziert API-Anfragen erheblich, indem Daten für mehrere Symbole in einem einzigen Batch abgerufen werden.

## Installation und Voraussetzungen

### Systemvoraussetzungen

- Python 3.8 oder höher
- Internetverbindung für Marktdaten-API
- Linux/macOS/Windows Betriebssystem

### Abhängigkeiten

Installieren Sie die erforderlichen Python-Pakete:

```bash
pip install yfinance pandas numpy matplotlib seaborn tabulate
```

## Schnellstart

Für eine schnelle Analyse einer einzelnen Aktie:

```bash
./stock_analyzer.py AAPL
```

Für eine optimierte Batch-Analyse mehrerer Aktien:

```bash
./batch_stock_analyzer.py AAPL MSFT GOOG -o reports
```

Oder verwenden Sie das praktische Shell-Skript:

```bash
./run_optimized_analysis.sh
```

## Grundlegende Befehle

### Einzelne Aktienanalyse

```bash
./stock_analyzer.py SYMBOL
```

Beispiel:
```bash
./stock_analyzer.py NOVN.SW
```

### Parameter für die Einzelanalyse

- `-o, --output` - Ausgabeverzeichnis für die Analyseergebnisse
- `-b, --benchmark` - Alternativer Benchmark für Performance-Vergleich
- `--no-plots` - Deaktiviert die Generierung von Visualisierungen

Beispiel:
```bash
./stock_analyzer.py AAPL -o reports --benchmark ^GSPC
```

## Optimierte Batch-Analyse

Die optimierte Batch-Analyse ermöglicht die Analyse mehrerer Aktien mit nur einem API-Aufruf pro Datentyp. Dies ist wesentlich effizienter bei der Analyse mehrerer Aktien.

### Batch-Analyzer direkt verwenden

```bash
./batch_stock_analyzer.py SYMBOL1 SYMBOL2 SYMBOL3 -o output_dir -w 4
```

Parameter:
- Liste von Symbolen als Positionsparameter
- `-o, --output-dir` - Ausgabeverzeichnis für Berichte
- `-w, --workers` - Anzahl paralleler Worker (Standard: 4)

Beispiel:
```bash
./batch_stock_analyzer.py AAPL MSFT GOOG AMZN -o reports/batch -w 6
```

### Analyse mit vordefinierten Symbolen

```bash
./run_optimized_analysis.sh
```

Dieses Skript analysiert alle Symbole aus der `stock_symbols.txt` Datei mit optimierten API-Aufrufen.

### Gefilterte Batch-Analyse

```bash
./optimized_filter_analyzer.sh -p 15 -d 2
```

Parameter:
- `-p, --pe` - Maximales Forward P/E
- `-d, --div` - Minimale Dividendenrendite in Prozent
- `-s, --sector` - Filtern nach Sektor
- `-c, --country` - Filtern nach Land
- `-m, --market-cap` - Minimale Marktkapitalisierung in Mrd. EUR
- `-r, --recent` - Nur Aktien mit Updates in den letzten X Tagen
- `--all` - Alle Aktien ohne Filter

Beispiel (Deutsche Aktien mit Dividendenrendite > 3%):
```bash
./optimized_filter_analyzer.sh -c Germany -d 3
```

## Nutzungsszenarien

### Wöchentliche Portfolioüberwachung

Für regelmäßige Überwachung eines Portfolios von Aktien:

```bash
./auto_optimized_analyzer.sh
```

Fügen Sie dieses Skript zu Ihren Cron-Jobs hinzu für automatische wöchentliche Analysen.

### DCF-Bewertung für Kaufentscheidungen

Um fundierte Kaufentscheidungen zu treffen:

```bash
./batch_stock_analyzer.py NOVN.SW NOV.DE BAYN.DE -o kaufentscheidungen
```

### Performance-Tracking

Um die Performance mehrerer Aktien im Vergleich zu einem Benchmark zu verfolgen:

```bash
./track_performance_charts.sh
```

## Fehlerbehebung

### Fehlende Daten

Wenn für bestimmte Symbole keine Daten gefunden werden:
- Überprüfen Sie, ob das Symbol korrekt ist (inkl. Suffix für nicht-US-Aktien)
- Versuchen Sie ein alternatives Symbol für dasselbe Wertpapier
- Prüfen Sie die Internetverbindung

### Leistungsprobleme

Bei langsamer Analyse bei vielen Symbolen:
- Reduzieren Sie die Anzahl der Worker (`-w` Parameter)
- Teilen Sie große Symbol-Listen in kleinere Batches
- Verwenden Sie die optimierten Skripts statt direkter Einzelanalyse

## FAQ

**F: Welche Aktien kann ich analysieren?**  
A: Alle Aktien, die über Yahoo Finance verfügbar sind. Für nicht-US-Aktien müssen entsprechende Suffixe hinzugefügt werden (z.B. `.DE` für Deutschland, `.SW` für Schweiz).

**F: Wie oft werden die Daten aktualisiert?**  
A: Die Daten werden bei jeder Analyse frisch von der API abgerufen und sind daher so aktuell wie die API-Quelle.

**F: Können mehrere Symbole gleichzeitig analysiert werden?**  
A: Ja, verwenden Sie den `batch_stock_analyzer.py` oder die optimierten Shell-Skripte, um mehrere Symbole effizient zu analysieren.

**F: Wie kann ich einen anderen Benchmark verwenden?**  
A: Standardmäßig wird basierend auf dem Land der Aktie ein passender Benchmark gewählt. Sie können jedoch mit dem `-b` Parameter einen alternativen Benchmark angeben.

**F: Wohin werden die Ergebnisse gespeichert?**  
A: Standardmäßig in das Verzeichnis `reports`. Sie können mit dem `-o` Parameter ein anderes Ausgabeverzeichnis angeben.

---

Für weitere Informationen und technische Details konsultieren Sie bitte die technische Dokumentation oder den Quellcode.
