# dcf_model.py

import numpy as np
from config import (
    DCF_GROWTH_RATE_BASE, DCF_GROWTH_RATE_OPTIMISTIC, DCF_GROWTH_RATE_PESSIMISTIC,
    DCF_DISCOUNT_RATE_BASE, DCF_DISCOUNT_RATE_OPTIMISTIC, DCF_DISCOUNT_RATE_PESSIMISTIC,
    DCF_TERMINAL_GROWTH, DCF_YEARS
)
from utils import format_currency, format_percentage, print_subsection_header, display_table

class DCFModel:
    """
    Klasse zur Durchführung von Discounted Cash Flow (DCF) Schätzungen.
    """
    def __init__(self, free_cashflow, shares_outstanding):
        """
        Initialisiert das DCFModel.
        Args:
            free_cashflow: Der aktuelle freie Cashflow des Unternehmens.
            shares_outstanding: Die Anzahl der ausstehenden Aktien.
        """
        self.fcf = free_cashflow
        # Sicherstellen, dass shares_outstanding nicht Null ist, um Division durch Null zu vermeiden
        self.shares = shares_outstanding if shares_outstanding and shares_outstanding > 0 else 1

    def calculate_dcf(self, growth_rate, discount_rate, terminal_growth_rate, years):
        """
        Berechnet den DCF-Wert pro Aktie für gegebene Parameter.
        Args:
            growth_rate: Die jährliche Wachstumsrate des freien Cashflows.
            discount_rate: Die Diskontierungsrate (WACC).
            terminal_growth_rate: Die Wachstumsrate für den terminalen Wert.
            years: Die Anzahl der Jahre für die detaillierte Prognose.
        Returns:
            Der geschätzte DCF-Wert pro Aktie oder None, wenn die Berechnung nicht möglich ist.
        """
        if not self.fcf or self.fcf <= 0:
            return None

        future_fcf = []
        for year in range(1, years + 1):
            projected_fcf = self.fcf * (1 + growth_rate) ** year
            future_fcf.append(projected_fcf)

        # Terminal Value Berechnung
        # Vermeiden Sie Division durch Null oder negativen Nenner
        if discount_rate <= terminal_growth_rate:
            # print(f"Warnung: Diskontierungsrate ({discount_rate}) muss größer sein als die terminale Wachstumsrate ({terminal_growth_rate}).")
            return None
        
        # Der terminale Wert wird am Ende des letzten Prognosejahres berechnet und diskontiert
        terminal_value = future_fcf[-1] * (1 + terminal_growth_rate) / (discount_rate - terminal_growth_rate)
        
        pv_sum = 0
        # Diskontierung der prognostizierten freien Cashflows
        for i, cf in enumerate(future_fcf):
            pv = cf / (1 + discount_rate) ** (i + 1)
            pv_sum += pv
        
        # Diskontierung des terminalen Wertes
        pv_terminal_value = terminal_value / (1 + discount_rate) ** years
        pv_sum += pv_terminal_value

        dcf_per_share = pv_sum / self.shares
        return dcf_per_share

    def calculate_wacc(self, cost_of_equity, cost_of_debt, equity_value, debt_value, tax_rate):
        """
        Berechnet den gewichteten durchschnittlichen Kapitalkostensatz (WACC).
        Args:
            cost_of_equity: Kosten des Eigenkapitals (z. B. CAPM).
            cost_of_debt: Kosten des Fremdkapitals.
            equity_value: Marktwert des Eigenkapitals.
            debt_value: Marktwert des Fremdkapitals.
            tax_rate: Unternehmenssteuersatz.
        Returns:
            Der berechnete WACC-Wert.
        """
        total_value = equity_value + debt_value
        if total_value == 0:
            return None

        equity_weight = equity_value / total_value
        debt_weight = debt_value / total_value

        wacc = (equity_weight * cost_of_equity) + (debt_weight * cost_of_debt * (1 - tax_rate))
        return wacc

    def run_dcf_analysis(self, current_price, sensitivity_analysis=False):
        """
        Führt DCF-Analyse mit verschiedenen Szenarien durch und gibt die Ergebnisse aus.
        Args:
            current_price: Der aktuelle Aktienkurs für die Berechnung des Upside-Potenzials.
            sensitivity_analysis: Boolescher Wert, ob eine Sensitivitätsanalyse durchgeführt werden soll.
        """
        print_subsection_header("DCF SCHÄTZUNG & SZENARIEN")

        dcf_results = []

        # Basis-Szenario
        dcf_base = self.calculate_dcf(DCF_GROWTH_RATE_BASE, DCF_DISCOUNT_RATE_BASE, DCF_TERMINAL_GROWTH, DCF_YEARS)
        if dcf_base:
            upside_base = ((dcf_base - current_price) / current_price) * 100 if current_price else 0
            dcf_results.append(["Basis-Szenario", format_currency(dcf_base), format_percentage(upside_base),
                                f"Annahmen: Wachstum {format_percentage(DCF_GROWTH_RATE_BASE)}, Diskontierung {format_percentage(DCF_DISCOUNT_RATE_BASE)}"])

        # Optimistisches Szenario
        dcf_optimistic = self.calculate_dcf(DCF_GROWTH_RATE_OPTIMISTIC, DCF_DISCOUNT_RATE_OPTIMISTIC, DCF_TERMINAL_GROWTH, DCF_YEARS)
        if dcf_optimistic:
            upside_optimistic = ((dcf_optimistic - current_price) / current_price) * 100 if current_price else 0
            dcf_results.append(["Optimistisches Szenario", format_currency(dcf_optimistic), format_percentage(upside_optimistic),
                                f"Annahmen: Wachstum {format_percentage(DCF_GROWTH_RATE_OPTIMISTIC)}, Diskontierung {format_percentage(DCF_DISCOUNT_RATE_OPTIMISTIC)}"])

        # Pessimistisches Szenario
        dcf_pessimistic = self.calculate_dcf(DCF_GROWTH_RATE_PESSIMISTIC, DCF_DISCOUNT_RATE_PESSIMISTIC, DCF_TERMINAL_GROWTH, DCF_YEARS)
        if dcf_pessimistic:
            upside_pessimistic = ((dcf_pessimistic - current_price) / current_price) * 100 if current_price else 0
            dcf_results.append(["Pessimistisches Szenario", format_currency(dcf_pessimistic), format_percentage(upside_pessimistic),
                                f"Annahmen: Wachstum {format_percentage(DCF_GROWTH_RATE_PESSIMISTIC)}, Diskontierung {format_percentage(DCF_DISCOUNT_RATE_PESSIMISTIC)}"])

        if dcf_results:
            display_table(dcf_results, headers=["Szenario", "DCF Wert", "Upside", "Annahmen"], explanation_col=False)
        else:
            print("DCF Schätzung nicht möglich (unzureichende Daten oder FCF ist 0).")

        # Sensitivitätsanalyse
        if sensitivity_analysis:
            print_subsection_header("SENSITIVITÄTSANALYSE")
            sensitivity_results = []
            growth_rates = [DCF_GROWTH_RATE_PESSIMISTIC, DCF_GROWTH_RATE_BASE, DCF_GROWTH_RATE_OPTIMISTIC]
            discount_rates = [DCF_DISCOUNT_RATE_PESSIMISTIC, DCF_DISCOUNT_RATE_BASE, DCF_DISCOUNT_RATE_OPTIMISTIC]

            for growth_rate in growth_rates:
                for discount_rate in discount_rates:
                    dcf_value = self.calculate_dcf(growth_rate, discount_rate, DCF_TERMINAL_GROWTH, DCF_YEARS)
                    sensitivity_results.append([f"Wachstum {format_percentage(growth_rate)}", f"Diskontierung {format_percentage(discount_rate)}", format_currency(dcf_value)])

            display_table(sensitivity_results, headers=["Wachstumsrate", "Diskontierungsrate", "DCF Wert"], explanation_col=False)

        return dcf_base # Gibt den Basis-DCF-Wert für die Empfehlungslogik zurück

    def fetch_financial_data(self, ticker):
        """
        Ruft Finanzdaten von Yahoo Finance ab, um WACC-Parameter zu berechnen.
        Args:
            ticker: Das Tickersymbol des Unternehmens.
        Returns:
            Ein Dictionary mit equity_value, debt_value und tax_rate.
        """
        import yfinance as yf

        try:
            stock = yf.Ticker(ticker)
            balance_sheet = stock.balance_sheet
            financials = stock.financials

            # Extrahiere relevante Werte
            equity_value = balance_sheet.loc['Total Stockholder Equity'][0] if 'Total Stockholder Equity' in balance_sheet.index else None
            debt_value = balance_sheet.loc['Total Debt'][0] if 'Total Debt' in balance_sheet.index else None
            tax_rate = financials.loc['Income Tax Expense'][0] / financials.loc['Income Before Tax'][0] if 'Income Tax Expense' in financials.index and 'Income Before Tax' in financials.index else None

            return {
                'equity_value': equity_value,
                'debt_value': debt_value,
                'tax_rate': tax_rate
            }
        except Exception as e:
            print(f"Fehler beim Abrufen der Finanzdaten: {e}")
            return {
                'equity_value': None,
                'debt_value': None,
                'tax_rate': None
            }
