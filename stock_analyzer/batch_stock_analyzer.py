#!/usr/bin/env python3
"""
Batch Stock Analyzer (Fixed Version)
Optimiert die Analyse mehrerer Aktien durch Gruppierung der API-Anfragen
"""

import argparse
import yfinance as yf
import pandas as pd
import os
import sys
import io
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Any, Tuple, Optional

# Import lokales Modul
from stock_analyzer import StockAnalyzer
from config import HISTORICAL_DATA_PERIOD

class BatchStockAnalyzer:
    """
    Optimierte Batch-Verarbeitung für mehrere Aktien-Symbole
    Reduziert API-Aufrufe durch Bündelung von Datenabfragen
    """
    
    def __init__(self, symbols: List[str], output_dir: str = None):
        """
        Initialisiert den BatchStockAnalyzer
        
        Args:
            symbols: Eine Liste von Aktien-Symbolen
            output_dir: Verzeichnis für Ausgabe-Dateien (optional)
        """
        self.symbols = [s.upper() for s in symbols]
        self.data_cache = {}  # Cache für die abgerufenen Daten
        self.output_dir = output_dir
        
        if self.output_dir and not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)
    
    def fetch_all_data_in_batch(self) -> None:
        """
        Holt alle benötigten Daten für alle Symbole in einer Batch-Operation
        Minimiert die API-Aufrufe an yfinance
        
        Die Methode behandelt HTTP 404/401 Fehler und andere API-Verbindungsprobleme
        und versucht Anfragen bei Bedarf zu wiederholen.
        """
        print(f"Hole Daten für {len(self.symbols)} Symbole in einem Batch...")
        
        # Initialisiere Cache-Struktur
        self.data_cache = {
            "tickers": None,
            "all_hist": pd.DataFrame(),
            "benchmark_tickers": None,
            "benchmark_hist": pd.DataFrame(),
            "failed_symbols": []
        }
        
        # 1. Versuche alle Ticker-Informationen auf einmal zu holen
        try:
            tickers = yf.Tickers(" ".join(self.symbols))
            self.data_cache["tickers"] = tickers
            
            # Überprüfe auf fehlgeschlagene Symbole und sammle sie
            for symbol in self.symbols:
                if symbol not in tickers.tickers or not hasattr(tickers.tickers[symbol], 'info') or not tickers.tickers[symbol].info:
                    print(f"Warnung: Keine Daten für Symbol {symbol} gefunden (möglicherweise HTTP 404/401 Fehler)")
                    self.data_cache["failed_symbols"].append(symbol)
        except Exception as e:
            print(f"Fehler beim Abrufen von Ticker-Informationen: {str(e)}")
            # Falls der Batch-Aufruf scheitert, versuche jeden Ticker einzeln
            self._fetch_individual_tickers()
        
        # 2. Versuche alle historischen Daten auf einmal zu holen
        try:
            all_hist = tickers.history(period=HISTORICAL_DATA_PERIOD)
            self.data_cache["all_hist"] = all_hist
        except Exception as e:
            print(f"Fehler beim Abrufen von historischen Daten: {str(e)}")
            # Falls der Batch-Aufruf scheitert, versuche jeden Ticker einzeln
            self._fetch_individual_histories()
        
        # 3. Hole alle Benchmark-Indizes auf einmal
        benchmark_symbols = ["^GSPC", "^GDAXI", "^FTSE"]  # S&P 500, DAX, FTSE
        try:
            benchmark_tickers = yf.Tickers(" ".join(benchmark_symbols))
            benchmark_hist = benchmark_tickers.history(period=HISTORICAL_DATA_PERIOD)
            
            self.data_cache["benchmark_tickers"] = benchmark_tickers
            self.data_cache["benchmark_hist"] = benchmark_hist
        except Exception as e:
            print(f"Fehler beim Abrufen von Benchmark-Daten: {str(e)}")
            # Benchmarks sind nicht kritisch, daher fahren wir fort
        
        print("Batch-Daten abgerufen. " +
              (f"{len(self.data_cache['failed_symbols'])} Symbol(e) fehlgeschlagen." if self.data_cache['failed_symbols'] else "Alle Symbole erfolgreich."))
    
    def get_ticker_data(self, symbol: str) -> Tuple[Any, pd.DataFrame, Dict[str, Any]]:
        """
        Holt die Daten für ein bestimmtes Symbol aus dem Cache
        
        Args:
            symbol: Das Aktien-Symbol
        
        Returns:
            Ein Tuple mit (Ticker-Objekt, Historische Daten, Ticker-Info)
            Bei HTTP 404/401 Fehlern kann eines oder mehrere der zurückgegebenen Elemente None sein
        """
        symbol = symbol.upper()  # Normalisiere das Symbol
        
        if not self.data_cache:
            self.fetch_all_data_in_batch()
            
        # Überprüfe, ob das Symbol als fehlgeschlagen markiert wurde
        if "failed_symbols" in self.data_cache and symbol in self.data_cache["failed_symbols"]:
            print(f"Hinweis: Symbol {symbol} wurde aufgrund vorheriger API-Fehler (möglicherweise HTTP 404/401) übersprungen.")
            return None, None, None
        
        # Extrahiere die spezifischen Daten für dieses Symbol aus dem Cache
        try:
            ticker = self.data_cache["tickers"].tickers.get(symbol)
            
            if ticker is None:
                print(f"Fehler: Ticker für {symbol} konnte nicht gefunden werden.")
                # Versuche einen letzten direkten Aufruf
                try:
                    print(f"Versuche direkten Aufruf für {symbol}...")
                    ticker = yf.Ticker(symbol)
                    # Prüfe, ob der Ticker gültige Daten enthält
                    if not hasattr(ticker, 'info') or not ticker.info or len(ticker.info) <= 1:
                        ticker = None
                        print(f"Auch der direkte Aufruf lieferte keine Daten für {symbol}.")
                except Exception as e:
                    print(f"Fehler beim direkten Aufruf für {symbol}: {str(e)}")
                    ticker = None
                    
                if ticker is None:
                    return None, None, None
            
            # Ticker-Info abrufen (könnte None sein, wenn der Ticker existiert, aber keine Daten hat)
            ticker_info = ticker.info if hasattr(ticker, 'info') else None
                
            # Extrahiere und filtere die historischen Daten für dieses Symbol
            hist = None
            try:
                if isinstance(self.data_cache["all_hist"], pd.DataFrame):
                    if not self.data_cache["all_hist"].empty:
                        # Bei MultiIndex DataFrame: Prüfe, ob das Symbol im Index vorhanden ist
                        if hasattr(self.data_cache["all_hist"].index, 'levels') and len(self.data_cache["all_hist"].index.levels) > 0:
                            if symbol in self.data_cache["all_hist"].index.levels[0]:
                                hist = self.data_cache["all_hist"].loc[symbol]
                        # Für ein einzelnes Symbol ohne MultiIndex
                        else:
                            hist = self.data_cache["all_hist"]
                else:
                    # Panel mit mehreren DataFrames
                    hist = self.data_cache["all_hist"].get(symbol)
                    
                # Wenn keine Daten gefunden wurden, versuche sie direkt zu holen
                if hist is None or (isinstance(hist, pd.DataFrame) and hist.empty):
                    print(f"Versuche historische Daten für {symbol} direkt abzurufen...")
                    hist = ticker.history(period=HISTORICAL_DATA_PERIOD)
            except Exception as e:
                print(f"Fehler beim Abrufen historischer Daten für {symbol}: {str(e)}")
                hist = None
                
            return ticker, hist, ticker_info
            
        except Exception as e:
            print(f"Unerwarteter Fehler beim Abrufen von Daten für {symbol}: {str(e)}")
            return None, None, None
    
    def get_benchmark_data(self, country: str) -> pd.DataFrame:
        """
        Holt die Benchmark-Daten basierend auf dem Land aus dem Cache
        Mit verbesserter Fehlerbehandlung für HTTP 404/401 Fehler
        
        Args:
            country: Das Land des Unternehmens
        
        Returns:
            Ein DataFrame mit historischen Benchmark-Daten oder None bei Fehlern
        """
        if not self.data_cache:
            self.fetch_all_data_in_batch()
        
        benchmark_symbol = "^GSPC"  # Standard S&P 500
        
        if country == 'Germany':
            benchmark_symbol = "^GDAXI"
        elif country == 'United Kingdom':
            benchmark_symbol = "^FTSE"
        
        # Extrahiere die Benchmark-Daten
        try:
            if "benchmark_hist" not in self.data_cache or self.data_cache["benchmark_hist"].empty:
                # Versuche, die Benchmark-Daten direkt zu holen, wenn sie im Cache fehlen
                print(f"Benchmark-Daten für {benchmark_symbol} fehlen im Cache. Direkter Abruf...")
                try:
                    benchmark_ticker = yf.Ticker(benchmark_symbol)
                    benchmark_hist = benchmark_ticker.history(period=HISTORICAL_DATA_PERIOD)
                    
                    if not benchmark_hist.empty:
                        return benchmark_hist
                    else:
                        print(f"Warnung: Keine Benchmark-Daten für {benchmark_symbol} gefunden")
                        return None
                except Exception as e:
                    if "404" in str(e) or "401" in str(e):
                        print(f"HTTP {str(e)} Fehler beim Abrufen von Benchmark {benchmark_symbol}")
                    else:
                        print(f"Fehler beim Abrufen von Benchmark {benchmark_symbol}: {str(e)}")
                    return None
                    
            benchmark_hist = self.data_cache["benchmark_hist"]
            
            # Bei MultiIndex DataFrame für mehrere Benchmarks
            if hasattr(benchmark_hist.index, 'levels') and len(benchmark_hist.index.levels) > 0:
                if benchmark_symbol in benchmark_hist.index.levels[0]:
                    return benchmark_hist.loc[benchmark_symbol]
                else:
                    # Wenn das Symbol nicht im Index ist, versuche S&P 500
                    if "^GSPC" in benchmark_hist.index.levels[0]:
                        print(f"Verwende S&P 500 als Fallback für {benchmark_symbol}")
                        return benchmark_hist.loc["^GSPC"]
                    else:
                        # Nehme den ersten verfügbaren Benchmark
                        print("Verwende ersten verfügbaren Benchmark als Fallback")
                        return benchmark_hist.iloc[0]
            else:
                # Für einen einzelnen Benchmark ohne MultiIndex
                return benchmark_hist
                
        except (KeyError, AttributeError, IndexError) as e:
            print(f"Fehler beim Zugriff auf Benchmark-Daten: {str(e)}")
            
            # Letzter Versuch: Direkter API-Aufruf für S&P 500
            try:
                print("Direkter Abruf für S&P 500 als Fallback...")
                sp500_ticker = yf.Ticker("^GSPC")
                return sp500_ticker.history(period=HISTORICAL_DATA_PERIOD)
            except Exception as fallback_error:
                print(f"Auch der S&P 500 Fallback ist fehlgeschlagen: {str(fallback_error)}")
                return None
                
        return None
    
    def analyze_stocks(self, max_workers: int = 4) -> Tuple[int, int]:
        """
        Führt die Analyse für alle angegebenen Aktien durch
        
        Args:
            max_workers: Maximale Anzahl an parallelen Worker-Threads
            
        Returns:
            Ein Tuple mit (Anzahl erfolgreicher Analysen, Anzahl fehlgeschlagener Analysen)
        """
        # Stelle sicher, dass alle Daten im Cache sind
        if not self.data_cache:
            self.fetch_all_data_in_batch()
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        successful_analyses = 0
        failed_analyses = 0
        
        # Für kleine Symbol-Listen ist es besser, sequentiell zu arbeiten
        if len(self.symbols) <= 2:
            for symbol in self.symbols:
                try:
                    success = self._analyze_single_stock(symbol, timestamp)
                    if success:
                        successful_analyses += 1
                    else:
                        failed_analyses += 1
                except Exception as e:
                    print(f"Fehler bei der Analyse von {symbol}: {str(e)}")
                    failed_analyses += 1
        else:
            # Verwende ThreadPoolExecutor für parallele Analyse bei größeren Listen
            with ThreadPoolExecutor(max_workers=max_workers) as executor:
                # Starte alle Analysen
                futures = {executor.submit(self._analyze_single_stock, symbol, timestamp): symbol for symbol in self.symbols}
                
                # Verarbeite die Ergebnisse, sobald sie fertig sind
                for future in as_completed(futures):
                    symbol = futures[future]
                    try:
                        success = future.result()
                        if success:
                            successful_analyses += 1
                        else:
                            failed_analyses += 1
                    except Exception as e:
                        print(f"Fehler bei der Analyse von {symbol}: {str(e)}")
                        failed_analyses += 1
        
        print(f"\n===== Batch-Analyse abgeschlossen =====")
        print(f"Erfolgreich: {successful_analyses} Aktien")
        print(f"Fehlgeschlagen: {failed_analyses} Aktien")
        print(f"===================================")
        
        return successful_analyses, failed_analyses
    
    def _analyze_single_stock(self, symbol: str, timestamp: str) -> bool:
        """
        Analysiert eine einzelne Aktie mit den vorgeladenen Daten
        VERBESSERTE VERSION: Robustere Dateibehandlung mit StringIO und HTTP-Fehlerbehandlung
        
        Args:
            symbol: Das zu analysierende Symbol
            timestamp: Zeitstempel für die Ausgabedatei
            
        Returns:
            True bei erfolgreicher Analyse, False sonst
        """
        # Speichere die ursprüngliche stdout-Referenz außerhalb von try-except
        original_stdout = sys.stdout
        capture_buffer = None
        
        try:
            print(f"\n{'=' * 30}\nAnalysiere Aktie: {symbol}\n{'=' * 30}")
            
            # Hole Daten aus dem Cache
            ticker, hist, info = self.get_ticker_data(symbol)
            
            # Prüfe auf fehlende Daten durch HTTP 404/401 Fehler
            if ticker is None:
                print(f"Fehler: Ticker-Daten für {symbol} konnten nicht gefunden werden. "
                      f"Mögliche Ursache: HTTP 404/401 Fehler bei der API-Anfrage.")
                
                # Versuche es ein letztes Mal direkt mit doppelter Wartezeit zwischen Anfragen
                try:
                    print(f"Letzter Versuch: Direkter Abruf für {symbol} mit größerer Pause...")
                    import time
                    time.sleep(2)
                    ticker = yf.Ticker(symbol)
                    
                    # Überprüfen, ob gültige Daten zurückgegeben wurden
                    if hasattr(ticker, 'info') and ticker.info and len(ticker.info) > 1:
                        info = ticker.info
                        hist = ticker.history(period=HISTORICAL_DATA_PERIOD)
                        print(f"Letzter Versuch war erfolgreich für {symbol}")
                    else:
                        print(f"Auch der letzte Versuch lieferte keine gültigen Daten für {symbol}")
                        
                        # Füge Fehlerhinweis in die API-Fehler-Logs ein
                        error_log_path = os.path.join(self.output_dir if self.output_dir else '.', 'api_errors.log')
                        with open(error_log_path, 'a') as error_log:
                            error_log.write(f"{datetime.now().isoformat()}: HTTP-Fehler (vermutlich 404/401) für Symbol {symbol}\n")
                        
                        return False
                except Exception as e:
                    print(f"Fehler beim letzten Versuch für {symbol}: {str(e)}")
                    return False
            
            # Erstelle einen StockAnalyzer
            analyzer = StockAnalyzer(symbol)
                
            # Setze die gecachten Daten in den Analyzer
            analyzer.ticker = ticker
            analyzer.info = info if info is not None else {}
            analyzer.hist = hist if hist is not None else pd.DataFrame()
            
            # Überprüfe ob ausreichende Daten vorhanden sind
            if analyzer.info is None or len(analyzer.info) <= 1 or (isinstance(hist, pd.DataFrame) and hist.empty):
                print(f"Unzureichende Daten für {symbol}. Kann keine vollständige Analyse durchführen.")
                
                # Auch hier Fehlerhinweis loggen
                if self.output_dir:
                    error_log_path = os.path.join(self.output_dir, 'data_errors.log')
                    with open(error_log_path, 'a') as error_log:
                        error_log.write(f"{datetime.now().isoformat()}: Unzureichende Daten für {symbol}\n")
                        
                return False
                
            # Setze die Benchmark-Daten
            country = info.get('country') if info else None
            benchmark_hist = self.get_benchmark_data(country)
            if benchmark_hist is not None:
                analyzer.benchmark_hist = benchmark_hist
            
            # Führe die Analyse durch
            if self.output_dir:
                # Ausgabe in Datei umleiten
                output_file = os.path.join(self.output_dir, f"stock_analysis_{symbol}_{timestamp}.txt")
                
                # Verwende StringIO, um die Ausgabe zu erfassen
                capture_buffer = io.StringIO()
                
                try:
                    # Umleite stdout in den StringIO-Puffer
                    sys.stdout = capture_buffer
                    
                    # Führe die eigentliche Analyse durch
                    analyzer.analyze_stock()
                    
                finally:
                    # Wichtig: Immer stdout zurücksetzen!
                    sys.stdout = original_stdout
                
                # Jetzt, wo stdout zurückgesetzt ist, können wir die Ausgabe verarbeiten
                if capture_buffer:
                    output_content = capture_buffer.getvalue()
                    
                    # Prüfe auf Fehlermeldungen im Output
                    if "Fehler:" in output_content and ("404" in output_content or "401" in output_content):
                        print(f"HTTP-Fehler bei der Analyse von {symbol} erkannt (aus Output)")
                        
                        # Füge Fehlerhinweis in die HTTP-Fehler-Logs ein
                        error_log_path = os.path.join(self.output_dir, 'http_errors.log')
                        with open(error_log_path, 'a') as error_log:
                            error_log.write(f"{datetime.now().isoformat()}: HTTP-Fehler in der Analyse für {symbol}\n")
                    
                    # Schreibe die erfasste Ausgabe in die Datei
                    with open(output_file, 'w') as f:
                        f.write(output_content)
                    print(f"Analyse für {symbol} in {output_file} gespeichert.")
            else:
                # Direkte Ausgabe auf der Konsole
                analyzer.analyze_stock()
            
            return True
            
        except Exception as e:
            # Stelle sicher, dass stdout zurückgesetzt wird
            sys.stdout = original_stdout
            print(f"Fehler bei der Analyse von {symbol}: {str(e)}")
            return False
            
        finally:
            # Stelle immer sicher, dass stdout zurückgesetzt wird
            sys.stdout = original_stdout
            # Schließe den Buffer, falls vorhanden
            if capture_buffer:
                capture_buffer.close()
    
    def _fetch_individual_tickers(self) -> None:
        """
        Hilfsmethode: Holt Ticker-Informationen einzeln, falls der Batch-Aufruf fehlschlägt
        Dies ist eine Fallback-Methode mit Wiederholungslogik für HTTP-Fehler
        """
        print("Versuche, Ticker-Informationen einzeln abzurufen...")
        tickers_dict = {}
        
        for symbol in self.symbols:
            retries = 3  # Anzahl der Wiederholungsversuche
            
            for attempt in range(retries):
                try:
                    ticker = yf.Ticker(symbol)
                    if hasattr(ticker, 'info') and ticker.info and len(ticker.info) > 1:
                        tickers_dict[symbol] = ticker
                        break  # Erfolgreich, breche Wiederholungsversuche ab
                    else:
                        print(f"Warnung: Keine vollständigen Infos für {symbol} (Versuch {attempt+1}/{retries})")
                        if attempt == retries - 1:
                            self.data_cache["failed_symbols"].append(symbol)
                except Exception as e:
                    if "404" in str(e) or "401" in str(e):
                        print(f"HTTP {str(e)} Fehler für Symbol {symbol} (Versuch {attempt+1}/{retries})")
                    else:
                        print(f"Fehler bei {symbol}: {str(e)} (Versuch {attempt+1}/{retries})")
                    
                    if attempt == retries - 1:
                        self.data_cache["failed_symbols"].append(symbol)
                    else:
                        # Warte etwas länger bei jedem neuen Versuch
                        import time
                        time.sleep(1 + attempt)
        
        # Erstelle ein Dummy-Tickers-Objekt mit unserem Dictionary
        class DummyTickers:
            def __init__(self, tickers_dict):
                self.tickers = tickers_dict
                
        self.data_cache["tickers"] = DummyTickers(tickers_dict)
    
    def _fetch_individual_histories(self) -> None:
        """
        Hilfsmethode: Holt historische Daten einzeln, falls der Batch-Aufruf fehlschlägt
        """
        print("Versuche, historische Daten einzeln abzurufen...")
        all_hist = pd.DataFrame()
        
        for symbol in self.symbols:
            if symbol in self.data_cache["failed_symbols"]:
                continue  # Überspringe bereits fehlgeschlagene Symbole
                
            try:
                ticker = yf.Ticker(symbol)
                hist = ticker.history(period=HISTORICAL_DATA_PERIOD)
                
                if not hist.empty:
                    # Füge die Daten zum DataFrame hinzu (mit Multi-Index für Symbol)
                    hist_with_symbol = hist.copy()
                    all_hist = pd.concat([all_hist, hist_with_symbol], keys=[symbol], names=['Ticker'])
                else:
                    print(f"Warnung: Keine historischen Daten für {symbol} verfügbar")
                    if symbol not in self.data_cache["failed_symbols"]:
                        self.data_cache["failed_symbols"].append(symbol)
            except Exception as e:
                print(f"Fehler beim Abrufen von historischen Daten für {symbol}: {str(e)}")
                if symbol not in self.data_cache["failed_symbols"]:
                    self.data_cache["failed_symbols"].append(symbol)
        
        self.data_cache["all_hist"] = all_hist


def main():
    """Hauptfunktion für die Befehlszeilenverarbeitung"""
    parser = argparse.ArgumentParser(description="Batch-Analyse mehrerer Aktien mit optimierten API-Aufrufen.")
    parser.add_argument("symbols", nargs='*', help="Liste der zu analysierenden Aktien-Symbole.")
    parser.add_argument("-o", "--output-dir", help="Verzeichnis für Ausgabedateien.")
    parser.add_argument("-w", "--workers", type=int, default=4, help="Anzahl der parallelen Worker (Standard: 4)")
    parser.add_argument("-f", "--file", help="Datei mit Aktien-Symbolen (eine pro Zeile).")
    
    args = parser.parse_args()
    
    # Sammle alle Symbole
    symbols = args.symbols if args.symbols else []
    
    # Füge Symbole aus der Datei hinzu, falls angegeben
    if args.file:
        try:
            with open(args.file, 'r') as f:
                file_symbols = []
                for line in f:
                    # Entferne Kommentare und Leerzeichen
                    symbol = line.split('#')[0].strip()
                    if symbol:  # Ignoriere leere Zeilen
                        file_symbols.append(symbol)
                if file_symbols:
                    symbols.extend(file_symbols)
        except FileNotFoundError:
            print(f"Warnung: Symbole-Datei {args.file} nicht gefunden.")
    
    # Entferne Duplikate und leere Symbole
    symbols = list(filter(None, set(symbols)))
    
    if not symbols:
        print("Fehler: Keine Aktien-Symbole angegeben.")
        sys.exit(1)
    
    print(f"Starte Batch-Analyse für {len(symbols)} Aktien...")
    
    # Erstelle den BatchStockAnalyzer und führe die Analyse durch
    batch_analyzer = BatchStockAnalyzer(symbols, args.output_dir)
    batch_analyzer.analyze_stocks(max_workers=args.workers)

if __name__ == "__main__":
    main()
