#!/usr/bin/env python3
# stock_analyzer.py
"""
Stock Analysis Script
Analysiert Aktien und gibt detaillierte Bewertungsinformationen aus
"""

import argparse
import yfinance as yf
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import warnings
import os
import sys

# Import custom modules
from config import RSI_PERIOD, HISTORICAL_DATA_PERIOD
from utils import (
    format_currency, format_percentage, print_section_header,
    print_subsection_header, display_table, handle_data_not_available
)
from recommend_logic import get_recommendation
from dcf_model import DCFModel
from data_viz import plot_price_history_ascii, compare_performance_ascii

# Ignoriere Warnungen, insbesondere von yfinance für fehlende Daten
warnings.filterwarnings('ignore')

class StockAnalyzer:
    """
    Diese Klasse führt eine umfassende Analyse einer Aktie durch,
    einschließlich technischer und fundamentaler Kennzahlen,
    DCF-Schätzung und generiert eine Empfehlung.
    """
    def __init__(self, symbol):
        """
        Initialisiert den StockAnalyzer.
        Args:
            symbol: Das Tickersymbol der zu analysierenden Aktie.
        """
        self.symbol = symbol.upper()
        self.ticker = yf.Ticker(self.symbol)
        self.info = self.ticker.info # Speichert die Ticker-Info für schnellen Zugriff
        self.hist = None # Speichert historische Daten der Aktie
        self.benchmark_hist = None # Speichert historische Daten des Benchmarks

        # Überprüfen, ob das Symbol gültig ist
        if not self.info:
            print(f"Fehler: Ungültiges Tickersymbol '{self.symbol}' oder keine Daten verfügbar.")
            sys.exit(1)

    def get_stock_data(self):
        """
        Holt historische Daten für die Aktie und einen relevanten Benchmark.
        Returns:
            True, wenn Daten erfolgreich abgerufen wurden, False sonst.
        """
        try:
            self.hist = self.ticker.history(period=HISTORICAL_DATA_PERIOD)
            if self.hist.empty:
                print(f"Fehler: Keine historischen Daten für {self.symbol} gefunden.")
                return False
            
            # Wählt einen Benchmark basierend auf dem Land der Aktie aus
            benchmark_symbol = "^GSPC" # Standard: S&P 500 für US-Aktien
            country = self.info.get('country')
            if country == 'Germany':
                benchmark_symbol = "^GDAXI" # DAX für deutsche Aktien
            elif country == 'United Kingdom':
                benchmark_symbol = "^FTSE" # FTSE 100 für UK-Aktien
            # Weitere Benchmarks können hier hinzugefügt werden

            benchmark_ticker = yf.Ticker(benchmark_symbol)
            self.benchmark_hist = benchmark_ticker.history(period=HISTORICAL_DATA_PERIOD)
            if self.benchmark_hist.empty:
                print(f"Hinweis: Benchmark-Daten für {benchmark_symbol} nicht verfügbar oder unvollständig.")
            
            return True
        except Exception as e:
            print(f"Fehler beim Abrufen der historischen Daten für {self.symbol} oder Benchmark: {e}")
            return False

    def calculate_technical_indicators(self):
        """
        Berechnet und gibt technische Indikatoren zurück.
        Returns:
            Ein Dictionary mit den berechneten technischen Indikatoren.
        """
        if self.hist is None or self.hist.empty:
            handle_data_not_available("technische Indikatoren")
            return {}

        try:
            # Aktuelle Preise
            # Ensure compatibility with both numpy.ndarray and pandas.Series
            if isinstance(self.hist['Close'], pd.Series):
                current_price = self.hist['Close'].iloc[-1]
                prev_close = self.hist['Close'].iloc[-2] if len(self.hist) > 1 else current_price
                ma_20 = self.hist['Close'].rolling(window=20).mean().iloc[-1] if len(self.hist) >= 20 else None
                ma_50 = self.hist['Close'].rolling(window=50).mean().iloc[-1] if len(self.hist) >= 50 else None
                ma_200 = self.hist['Close'].rolling(window=200).mean().iloc[-1] if len(self.hist) >= 200 else None
            else:
                current_price = self.hist['Close'][-1]
                prev_close = self.hist['Close'][-2] if len(self.hist['Close']) > 1 else current_price
                ma_20 = self.hist['Close'].rolling(window=20).mean()[-1] if len(self.hist) >= 20 else None
                ma_50 = self.hist['Close'].rolling(window=50).mean()[-1] if len(self.hist) >= 50 else None
                ma_200 = self.hist['Close'].rolling(window=200).mean()[-1] if len(self.hist) >= 200 else None

            # Prozentuale Änderung zum Vortag
            change_pct = ((current_price - prev_close) / prev_close) * 100

            # RSI Berechnung
            rsi = self._calculate_rsi(period=RSI_PERIOD)
            if isinstance(rsi, np.ndarray):
                rsi = rsi[-1] if len(rsi) > 0 else None  # Safely extract the last value if it's an array

            # 52-Wochen Hoch/Tief
            week_52_high = self.hist['High'].max()
            week_52_low = self.hist['Low'].min()

            # Volatilität (Standardabweichung der täglichen Returns)
            returns = self.hist['Close'].pct_change().dropna()
            volatility = returns.std() * np.sqrt(252) * 100 # Annualisierte Volatilität

            return {
                'current_price': current_price,
                'change_pct': change_pct,
                'ma_20': ma_20,
                'ma_50': ma_50,
                'ma_200': ma_200,
                'rsi': rsi,
                'week_52_high': week_52_high,
                'week_52_low': week_52_low,
                'volatility': volatility,
                'volume': self.hist['Volume'].iloc[-1]
            }
        except Exception as e:
            print(f"Fehler bei der Berechnung technischer Indikatoren: {e}")
            return {}

    def _calculate_rsi(self, period=14):
        """
        Berechnet den RSI (Relative Strength Index).
        Args:
            period: Die Periode für die RSI-Berechnung (Standard ist 14).
        Returns:
            Der RSI-Wert oder None, wenn nicht genügend Daten vorhanden sind.
        """
        if self.hist is None or len(self.hist) < period + 1: # Benötigt period + 1 für diff()
            return None

        delta = self.hist['Close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()

        # Behandle Fälle, in denen der Verlust Null ist, um Division durch Null zu vermeiden
        rs = np.where(loss == 0, np.inf, gain / loss)
        rsi = 100 - (100 / (1 + rs))

        if hasattr(rsi, 'iloc'):
            return rsi.iloc[-1]
        elif isinstance(rsi, np.ndarray):
            return rsi[-1]
        else:
            return rsi

    def get_fundamental_data(self):
        """
        Extrahiert und gibt fundamentale Kennzahlen zurück.
        Returns:
            Ein Dictionary mit den fundamentalen Kennzahlen.
        """
        try:
            fundamentals = {
                'market_cap': self.info.get('marketCap'),
                'pe_ratio': self.info.get('trailingPE'),
                'forward_pe': self.info.get('forwardPE'),
                'peg_ratio': self.info.get('pegRatio'),
                'price_to_book': self.info.get('priceToBook'),
                'price_to_sales': self.info.get('priceToSalesTrailing12Months'),
                'enterprise_value': self.info.get('enterpriseValue'),
                'ev_revenue': self.info.get('enterpriseToRevenue'),
                'ev_ebitda': self.info.get('enterpriseToEbitda'),
                'debt_to_equity': self.info.get('debtToEquity'),
                'return_on_equity': self.info.get('returnOnEquity'),
                'return_on_assets': self.info.get('returnOnAssets'),
                'profit_margin': self.info.get('profitMargins'),
                'operating_margin': self.info.get('operatingMargins'),
                'dividend_yield': self.info.get('dividendYield'),
                'payout_ratio': self.info.get('payoutRatio'),
                'beta': self.info.get('beta'),
                'shares_outstanding': self.info.get('sharesOutstanding'),
                'float_shares': self.info.get('floatShares'),
                'held_by_institutions': self.info.get('heldPercentInstitutions'),
                'analyst_target': self.info.get('targetMeanPrice'),
                'recommendation': self.info.get('recommendationKey'),
                'free_cashflow': self.info.get('freeCashflow') # Hinzugefügt für DCF-Modell
            }
            return fundamentals
        except Exception as e:
            print(f"Fehler beim Abrufen fundamentaler Daten: {e}")
            return {}

    def get_company_info(self):
        """
        Holt und gibt grundlegende Unternehmensinformationen zurück.
        Returns:
            Ein Dictionary mit Unternehmensinformationen.
        """
        return {
            'name': self.info.get('longName', 'N/A'),
            'sector': self.info.get('sector', 'N/A'),
            'industry': self.info.get('industry', 'N/A'),
            'country': self.info.get('country', 'N/A'),
            'website': self.info.get('website', 'N/A'),
            'description': self.info.get('longBusinessSummary', 'N/A')[:200] + "..." if self.info.get('longBusinessSummary') else 'N/A'
        }

    def get_dividend_growth(self):
        """
        Berechnet das Dividendenwachstum der letzten 10 Jahre.
        Returns:
            Ein Dictionary mit den jährlichen Dividenden und der Wachstumsrate.
        """
        try:
            dividends = self.ticker.dividends
            if dividends.empty:
                return None

            # Gruppiere Dividenden nach Jahr und summiere sie
            dividends_by_year = dividends.resample('Y').sum()
            last_10_years = dividends_by_year[-10:]  # Letzte 10 Jahre

            if len(last_10_years) < 2:
                return None

            # Berechne die jährliche Wachstumsrate
            start = last_10_years.iloc[0]
            end = last_10_years.iloc[-1]
            years = len(last_10_years) - 1
            growth_rate = ((end / start) ** (1 / years) - 1) * 100

            return {
                'dividends_by_year': last_10_years,
                'growth_rate': growth_rate
            }
        except Exception as e:
            print(f"Fehler beim Abrufen des Dividendenwachstums: {e}")
            return None

    def evaluate_dividend_growth(self, dividend_growth):
        """
        Bewertet den Verlauf des Dividendenwachstums.
        Args:
            dividend_growth: Ein Dictionary mit den jährlichen Dividenden und der Wachstumsrate.
        Returns:
            Eine qualitative Bewertung des Dividendenwachstums.
        """
        dividends = dividend_growth['dividends_by_year']
        growth_rate = dividend_growth['growth_rate']

        # Prüfen, ob die Dividenden jedes Jahr gestiegen sind
        is_consistent = all(dividends[i] <= dividends[i + 1] for i in range(len(dividends) - 1))

        if is_consistent:
            return f"Konstante und verlässliche Steigerung mit durchschnittlich {growth_rate:.2f}% pro Jahr."
        else:
            return f"Volatiles Wachstum mit durchschnittlich {growth_rate:.2f}% pro Jahr."

    def evaluate_fundamentals(self, fundamentals):
        """
        Bewertet die fundamentalen Kennzahlen.
        Args:
            fundamentals: Ein Dictionary mit den fundamentalen Kennzahlen.
        Returns:
            Ein Dictionary mit Bewertungen der Kennzahlen.
        """
        evaluations = {}

        # Bewertung basierend auf Schwellenwerten
        if fundamentals.get('pe_ratio') is not None:
            if fundamentals['pe_ratio'] < 15:
                evaluations['pe_ratio'] = "Gut (unterbewertet)"
            elif fundamentals['pe_ratio'] <= 25:
                evaluations['pe_ratio'] = "Durchschnittlich"
            else:
                evaluations['pe_ratio'] = "Schlecht (überbewertet)"

        if fundamentals.get('dividend_yield') is not None:
            if fundamentals['dividend_yield'] > 0.03:
                evaluations['dividend_yield'] = "Gut (hohe Rendite)"
            elif fundamentals['dividend_yield'] > 0.01:
                evaluations['dividend_yield'] = "Durchschnittlich"
            else:
                evaluations['dividend_yield'] = "Schlecht (niedrige Rendite)"

        if fundamentals.get('debt_to_equity') is not None:
            if fundamentals['debt_to_equity'] < 0.5:
                evaluations['debt_to_equity'] = "Gut (niedrige Verschuldung)"
            elif fundamentals['debt_to_equity'] <= 1:
                evaluations['debt_to_equity'] = "Durchschnittlich"
            else:
                evaluations['debt_to_equity'] = "Schlecht (hohe Verschuldung)"

        return evaluations

    def analyze_stock(self):
        """
        Führt die komplette Aktienanalyse durch und gibt die Ergebnisse aus.
        """
        print_section_header(f"AKTIENANALYSE: {self.symbol}")

        # Firmendaten abrufen und anzeigen
        print("Firmendaten werden abgerufen...")
        company_info = self.get_company_info()
        company_table = [
            ["Unternehmen", company_info['name'], "Name des Unternehmens"],
            ["Sektor", company_info['sector'], "Wirtschaftssektor"],
            ["Branche", company_info['industry'], "Industrie oder Geschäftsfeld"],
            ["Land", company_info['country'], "Herkunftsland"]
        ]
        display_table(company_table, headers=["Kategorie", "Details", "Erläuterung"])
        print(f"\nKurzbeschreibung: {company_info['description']}")

        # Historische Daten laden
        print("\nHistorische Daten werden abgerufen...")
        if not self.get_stock_data():
            print("Analyse kann ohne historische Daten nicht fortgesetzt werden.")
            return
        print("Historische Daten erfolgreich abgerufen.")

        # --- Visualisierung des Kursverlaufs ---
        print_subsection_header("KURSVERLAUF VISUALISIERUNG")
        print(plot_price_history_ascii(self.hist, period_days=90)) # Zeigt die letzten 90 Tage
        
        # --- Performance Vergleich ---
        if self.benchmark_hist is not None and not self.benchmark_hist.empty:
            print(compare_performance_ascii(self.hist, self.benchmark_hist, self.symbol))


        # Technische Analyse durchführen und anzeigen
        print_subsection_header("TECHNISCHE ANALYSE")
        tech_data = self.calculate_technical_indicators()
        tech_table = [
            ["Aktueller Kurs", format_currency(tech_data.get('current_price')), "Letzter Schlusskurs"],
            ["Tagesänderung", format_percentage(tech_data.get('change_pct')), "Prozentuale Änderung zum Vortag"],
            ["Volumen", f"{tech_data.get('volume', 'N/A'):,}" if isinstance(tech_data.get('volume'), (int, float)) else "N/A", "Gehandeltes Volumen"],
            ["MA(20)", format_currency(tech_data.get('ma_20')), "20-Tage-Durchschnitt"],
            ["MA(50)", format_currency(tech_data.get('ma_50')), "50-Tage-Durchschnitt"],
            ["MA(200)", format_currency(tech_data.get('ma_200')), "200-Tage-Durchschnitt"],
            ["RSI(14)", f"{tech_data.get('rsi', 'N/A'):.1f}" if tech_data.get('rsi') is not None else "N/A", "Relative Strength Index"],
            ["52W Hoch", format_currency(tech_data.get('week_52_high')), "52-Wochen-Höchstkurs"],
            ["52W Tief", format_currency(tech_data.get('week_52_low')), "52-Wochen-Tiefstkurs"],
            ["Volatilität", format_percentage(tech_data.get('volatility')), "Jährliche Volatilität"]
        ]
        display_table(tech_table, headers=["Kategorie", "Wert", "Erläuterung"])

        # Fundamentale Analyse durchführen und anzeigen
        print_subsection_header("FUNDAMENTALE KENNZAHLEN")
        fundamentals = self.get_fundamental_data()
        fundamental_table = [
            ["Marktkapitalisierung", format_currency(fundamentals.get('market_cap')), "Gesamtwert der Aktien"],
            ["KGV (P/E)", f"{fundamentals.get('pe_ratio', 'N/A'):.2f}" if fundamentals.get('pe_ratio') is not None else "N/A", "Kurs-Gewinn-Verhältnis"],
            ["Forward P/E", f"{fundamentals.get('forward_pe', 'N/A'):.2f}" if fundamentals.get('forward_pe') is not None else "N/A", "Erwartetes KGV"],
            ["Dividendenrendite", f"{fundamentals.get('dividend_yield', 'N/A'):.2f}%" if fundamentals.get('dividend_yield') is not None else "N/A", "Dividende im Verhältnis zum Kurs"],
            ["Verschuldungsgrad", f"{fundamentals.get('debt_to_equity', 'N/A'):.2f}" if fundamentals.get('debt_to_equity') is not None else "N/A", "Verhältnis von Schulden zu Eigenkapital"]
        ]
        display_table(fundamental_table, headers=["Kategorie", "Wert", "Erläuterung"])

        # Bewertung der fundamentalen Kennzahlen
        evaluations = self.evaluate_fundamentals(fundamentals)
        print("\nBewertung der fundamentalen Kennzahlen:")
        for key, evaluation in evaluations.items():
            print(f"- {key}: {evaluation}")

        # Analystenschätzungen anzeigen
        analyst_table = []  # Initialize with a default value

        if fundamentals.get('analyst_target') is not None and tech_data.get('current_price') is not None:
            current_price = tech_data['current_price']
            upside = ((fundamentals['analyst_target'] - current_price) / current_price) * 100
            analyst_table = [
                ["Analysten-Kursziel", format_currency(fundamentals['analyst_target']), "Durchschnittliches Kursziel"],
                ["Upside-Potenzial", format_percentage(upside), "Potenzial für Kurssteigerung"]
            ]
            print_subsection_header("ANALYSTENSCHÄTZUNGEN")
            display_table(analyst_table, headers=["Kategorie", "Wert", "Erläuterung"])
        else:
            handle_data_not_available("Analystenschätzungen")


        # DCF Schätzung und Szenarien durchführen
        free_cashflow = fundamentals.get('free_cashflow')
        shares_outstanding = fundamentals.get('shares_outstanding')
        dcf_base_value = None

        if free_cashflow is not None and shares_outstanding is not None:
            dcf_model = DCFModel(free_cashflow, shares_outstanding)

            # Finanzdaten für WACC abrufen
            financial_data = dcf_model.fetch_financial_data(self.symbol)
            equity_value = financial_data.get('equity_value')
            debt_value = financial_data.get('debt_value')
            tax_rate = financial_data.get('tax_rate')

            if equity_value and debt_value and tax_rate is not None:
                cost_of_equity = 0.08  # Beispielwert, kann durch CAPM ersetzt werden
                cost_of_debt = 0.05   # Beispielwert, kann durch Marktanalyse ersetzt werden

                wacc = dcf_model.calculate_wacc(cost_of_equity, cost_of_debt, equity_value, debt_value, tax_rate)
                print(f"Berechneter WACC: {format_percentage(wacc)}")

            # DCF-Analyse mit Sensitivitätsanalyse durchführen
            dcf_base_value = dcf_model.run_dcf_analysis(tech_data.get('current_price'), sensitivity_analysis=True)
        else:
            print_subsection_header("DCF SCHÄTZUNG & SZENARIEN")
            print("DCF Schätzung nicht möglich: Freier Cashflow oder ausstehende Aktien fehlen.")

        # Gesamtbewertung und Empfehlung generieren und anzeigen
        get_recommendation(tech_data, fundamentals, dcf_base_value)
        
        print("\n" + "=" * 30)
        print("Gesamtbewertung abgeschlossen".center(30))
        print("=" * 30 + "\n")

        # Entferne überflüssige Trennlinien in Tabellenformatierung
        display_table(company_table, headers=["Kategorie", "Details", "Erläuterung"])
        display_table(tech_table, headers=["Kategorie", "Wert", "Erläuterung"])
        display_table(fundamental_table, headers=["Kategorie", "Wert", "Erläuterung"])
        display_table(analyst_table, headers=["Kategorie", "Wert", "Erläuterung"])

        # Dynamische Werte für die Strategie-Tabelle berechnen
        forward_pe = f"Forward P/E: {fundamentals.get('forward_pe', 'N/A'):.2f}" if fundamentals.get('forward_pe') is not None else "Forward P/E: N/A"
        dividend_yield = fundamentals.get('dividend_yield')
        dividend_yield_text = f"{dividend_yield * 100:.2f}%" if dividend_yield is not None else "N/A"
        dcf_value = f"DCF: {dcf_base_value:.2f}%\n(EUR)" if dcf_base_value is not None else "DCF: N/A"
        buy_zone = f"{fundamentals.get('analyst_target', 'N/A'):.2f}\n(EUR)" if fundamentals.get('analyst_target') is not None else "N/A"

        # Dynamische Gesamtempfehlung basierend auf Analyseergebnissen
        overall_recommendation = "Keine Empfehlung verfügbar"

        # Ensure 'forward_pe' is not None before comparison
        forward_pe = fundamentals.get('forward_pe', 0)
        if forward_pe is None:
            forward_pe = 0  # Default to 0 if None to avoid TypeError

        # Update all comparisons to use the validated 'forward_pe' variable
        if dcf_base_value is not None and dcf_base_value > 0 and forward_pe < 15:
            overall_recommendation = "🟢 Kaufen"
        elif dcf_base_value is not None and dcf_base_value < 0:
            overall_recommendation = "🔴 Verkaufen"
        else:
            overall_recommendation = "🟡 Halten"

        strengths = []
        weaknesses = []

        if fundamentals.get('dividend_yield') is not None and fundamentals.get('dividend_yield', 0) > 0.02:
            strengths.append("Hohe Dividendenrendite")
        if tech_data.get('rsi', 0) < 30:
            strengths.append("Überverkauft (RSI)")
        if tech_data.get('volatility', 0) < 20:
            strengths.append("Geringe Volatilität")

        if dcf_base_value is not None and dcf_base_value < 0:
            weaknesses.append("DCF-Wert negativ")
        if fundamentals.get('debt_to_equity') is not None and fundamentals.get('debt_to_equity', 0) > 1:
            weaknesses.append("Hoher Verschuldungsgrad")
        if tech_data.get('rsi', 0) > 70:
            weaknesses.append("Überkauft (RSI)")
        strengths_text = ",\n".join(strengths) if strengths else "Keine besonderen Stärken"
        weaknesses_text = ",\n".join(weaknesses) if weaknesses else "Keine besonderen Schwächen"

        # --- Aktienstrategie & Empfehlung ---
        print_subsection_header("AKTIENSTRATEGIE & EMPFEHLUNG")
        forward_pe_text = f"{fundamentals.get('forward_pe', 'N/A'):.2f}" if fundamentals.get('forward_pe') is not None else "N/A"

        strategy_table = [
            ["Kategorie", "Wert", "Erläuterung"],
            ["Gesamtempfehlung", overall_recommendation, "Zusammenfassende Bewertung der Aktie."],
            ["Stärken", strengths_text, "Positive Aspekte der Analyse."],
            ["Schwächen/Risiken", weaknesses_text, "Negative Aspekte oder potenzielle Risiken."],
            ["Begründung", f"Forward P/E: {forward_pe_text}, Dividende: {dividend_yield_text}, DCF: {dcf_base_value if dcf_base_value is not None else 'N/A'} (EUR)", "Gründe für die Bewertung."],
            ["Kaufzone", f"{dcf_base_value if dcf_base_value is not None else 'N/A'} (EUR)", "Preisbereich für den Einstieg."]
        ]
        display_table(strategy_table, headers=["Kategorie", "Wert", "Erläuterung"])

        # Dividendenwachstum anzeigen
        print_subsection_header("DIVIDENDENWACHSTUM")
        dividend_growth = self.get_dividend_growth()
        if dividend_growth:
            growth_table = [
                ["Jahr", "Dividende (EUR)"]
            ]
            for year, dividend in dividend_growth['dividends_by_year'].items():
                growth_table.append([year.year, format_currency(dividend)])

            growth_table.append(["Wachstumsrate", f"{dividend_growth['growth_rate']:.2f}%"])
            display_table(growth_table, headers=["Kategorie", "Wert"])

            # Bewertung des Dividendenwachstums
            evaluation = self.evaluate_dividend_growth(dividend_growth)
            print(f"Bewertung: {evaluation}")
        else:
            print("Keine ausreichenden Daten für Dividendenwachstum verfügbar.")


        # Dynamische Werte für die Strategie-Tabelle berechnen
        forward_pe = f"Forward P/E: {fundamentals.get('forward_pe', 'N/A'):.2f}" if fundamentals.get('forward_pe') is not None else "Forward P/E: N/A"
        dividend_yield = fundamentals.get('dividend_yield')
        dividend_yield_text = f"{dividend_yield * 100:.2f}%" if dividend_yield is not None else "N/A"
        dcf_value = f"DCF: {dcf_base_value:.2f}%\n(EUR)" if dcf_base_value is not None else "DCF: N/A"
        buy_zone = f"{fundamentals.get('analyst_target', 'N/A'):.2f}\n(EUR)" if fundamentals.get('analyst_target') is not None else "N/A"

        # Dynamische Gesamtempfehlung basierend auf Analyseergebnissen
        overall_recommendation = "Keine Empfehlung verfügbar"

        # Dynamische Gesamtempfehlung basierend auf Analyseergebnissen
        # Ensure 'forward_pe' is not None before comparison
        forward_pe_value = fundamentals.get('forward_pe')
        if forward_pe_value is None:
            forward_pe_value = 0  # Default to 0 if None to avoid TypeError
            
        if dcf_base_value is not None and dcf_base_value > 0 and forward_pe_value < 15:
            overall_recommendation = "🟢 Kaufen"
        elif dcf_base_value is not None and dcf_base_value < 0:
            overall_recommendation = "🔴 Verkaufen"
        else:
            overall_recommendation = "🟡 Halten"

        # Dynamische Stärken und Schwächen basierend auf Analyseergebnissen
        strengths = []
        weaknesses = []

        if fundamentals.get('dividend_yield') is not None and fundamentals.get('dividend_yield', 0) > 0.02:
            strengths.append("Hohe Dividendenrendite")
        if tech_data.get('rsi', 0) < 30:
            strengths.append("Überverkauft (RSI)")
        if tech_data.get('volatility', 0) < 20:
            strengths.append("Geringe Volatilität")

        if dcf_base_value is not None and dcf_base_value < 0:
            weaknesses.append("DCF-Wert negativ")
        if fundamentals.get('debt_to_equity') is not None and fundamentals.get('debt_to_equity', 0) > 1:
            weaknesses.append("Hoher Verschuldungsgrad")
        if tech_data.get('rsi', 0) > 70:
            weaknesses.append("Überkauft (RSI)")
        strengths_text = ",\n".join(strengths) if strengths else "Keine besonderen Stärken"
        weaknesses_text = ",\n".join(weaknesses) if weaknesses else "Keine besonderen Schwächen"

if __name__ == "__main__":
    # Argument-Parser für die Befehlszeileneingabe
    parser = argparse.ArgumentParser(description="Analysiert Aktien und gibt detaillierte Bewertungsinformationen aus.")
    parser.add_argument("symbols", type=str, nargs='+', help="Die Tickersymbole der zu analysierenden Aktien (z.B. AAPL GOOG TSLA).")
    args = parser.parse_args()

    # Für jedes Tickersymbol eine Instanz des StockAnalyzer erstellen und die Analyse starten
    for symbol in args.symbols:
        print(f"\n{'=' * 30}\nAnalysiere Aktie: {symbol}\n{'=' * 30}")
        analyzer = StockAnalyzer(symbol)
        analyzer.analyze_stock()
