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
        """
        print(f"Hole Daten für {len(self.symbols)} Symbole in einem Batch...")
        
        # 1. Hole alle Ticker-Informationen auf einmal
        tickers = yf.Tickers(" ".join(self.symbols))
        
        # 2. Hole alle historischen Daten auf einmal
        all_hist = tickers.history(period=HISTORICAL_DATA_PERIOD)
        
        # 3. Hole alle Benchmark-Indizes auf einmal (die häufig verwendet werden)
        benchmark_symbols = ["^GSPC", "^GDAXI", "^FTSE"]  # S&P 500, DAX, FTSE
        benchmark_tickers = yf.Tickers(" ".join(benchmark_symbols))
        benchmark_hist = benchmark_tickers.history(period=HISTORICAL_DATA_PERIOD)
        
        # Speichere alle Daten im Cache
        self.data_cache = {
            "tickers": tickers,
            "all_hist": all_hist,
            "benchmark_tickers": benchmark_tickers,
            "benchmark_hist": benchmark_hist
        }
        
        print("Batch-Daten erfolgreich abgerufen.")
    
    def get_ticker_data(self, symbol: str) -> Tuple[Any, pd.DataFrame, Dict[str, Any]]:
        """
        Holt die Daten für ein bestimmtes Symbol aus dem Cache
        
        Args:
            symbol: Das Aktien-Symbol
        
        Returns:
            Ein Tuple mit (Ticker-Objekt, Historische Daten, Ticker-Info)
        """
        if not self.data_cache:
            self.fetch_all_data_in_batch()
        
        # Extrahiere die spezifischen Daten für dieses Symbol aus dem Cache
        ticker = self.data_cache["tickers"].tickers.get(symbol)
        
        if ticker is None:
            print(f"Fehler: Ticker für {symbol} konnte nicht gefunden werden.")
            return None, None, None
        
        # Extrahiere und filtere die historischen Daten für dieses Symbol
        if isinstance(self.data_cache["all_hist"], pd.DataFrame):
            # MultiIndex DataFrame (für ein Symbol)
            hist = self.data_cache["all_hist"]
        else:
            # Panel mit mehreren DataFrames (für mehrere Symbole)
            hist = self.data_cache["all_hist"][symbol]
        
        return ticker, hist, ticker.info
    
    def get_benchmark_data(self, country: str) -> pd.DataFrame:
        """
        Holt die Benchmark-Daten basierend auf dem Land aus dem Cache
        
        Args:
            country: Das Land des Unternehmens
        
        Returns:
            Ein DataFrame mit historischen Benchmark-Daten
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
            benchmark_hist = self.data_cache["benchmark_hist"]
            if benchmark_symbol in self.data_cache["benchmark_tickers"].tickers:
                return benchmark_hist
        except (KeyError, AttributeError):
            pass
        
        # Als Fallback S&P 500 verwenden
        return self.data_cache["benchmark_hist"]
    
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
        VERBESSERTE VERSION: Robustere Dateibehandlung mit StringIO
        
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
            
            # Erstelle einen StockAnalyzer
            analyzer = StockAnalyzer(symbol)
            
            # Hole Daten aus dem Cache
            ticker, hist, info = self.get_ticker_data(symbol)
            
            if ticker is None:
                print(f"Fehler: Ticker-Daten für {symbol} konnten nicht gefunden werden.")
                return False
                
            # Setze die gecachten Daten in den Analyzer
            analyzer.ticker = ticker
            analyzer.info = info if info is not None else {}
            analyzer.hist = hist if hist is not None else pd.DataFrame()
            
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
