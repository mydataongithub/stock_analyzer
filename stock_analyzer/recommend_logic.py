# recommend_logic.py

from config import (
    PE_RATIO_UNDERRVALUED_THRESHOLD, PE_RATIO_OVERVALUED_THRESHOLD,
    MA_OVERBOUGHT_MULTIPLIER, MA_OVERSOLD_MULTIPLIER
)
from utils import print_subsection_header, display_table, format_currency

def get_recommendation(tech_data, fundamentals, dcf_value=None):
    """
    Gibt eine detaillierte Empfehlung basierend auf technischen, fundamentalen Daten und DCF.
    Args:
        tech_data: Dictionary mit technischen Indikatoren.
        fundamentals: Dictionary mit fundamentalen Kennzahlen.
        dcf_value: Der geschätzte DCF-Wert pro Aktie (optional).
    """
    signals = []
    reasons = []
    entry_price_suggestion = None
    exit_price_suggestion = None
    overall_recommendation = "🟡 Halten" # Standardempfehlung

    current_price = tech_data.get('current_price')
    ma_50 = tech_data.get('ma_50')
    ma_200 = tech_data.get('ma_200')
    pe_ratio = fundamentals.get('pe_ratio')
    rsi = tech_data.get('rsi')
    dividend_yield = fundamentals.get('dividend_yield')
    payout_ratio = fundamentals.get('payout_ratio')
    forward_pe = fundamentals.get('forward_pe')

    # --- Fundamentale Bewertung ---
    if pe_ratio is not None:
        if pe_ratio < PE_RATIO_UNDERRVALUED_THRESHOLD:
            signals.append("🟢 Fundamentale Unterbewertung (niedriges KGV)")
            reasons.append(f"KGV ({pe_ratio:.2f}) unter Schwellenwert {PE_RATIO_UNDERRVALUED_THRESHOLD}.")
            # Wenn fundamental unterbewertet und noch keine negative Empfehlung, setze auf Kaufen
            if overall_recommendation != "🔴 Verkaufen":
                overall_recommendation = "🟢 Kaufen"
        elif pe_ratio > PE_RATIO_OVERVALUED_THRESHOLD:
            signals.append("🔴 Fundamentale Überbewertung (hohes KGV)")
            reasons.append(f"KGV ({pe_ratio:.2f}) über Schwellenwert {PE_RATIO_OVERVALUED_THRESHOLD}.")
            # Wenn fundamental überbewertet und noch keine positive Empfehlung, setze auf Verkaufen
            if overall_recommendation != "🟢 Kaufen":
                overall_recommendation = "🔴 Verkaufen"

    if forward_pe is not None and pe_ratio is not None and forward_pe < pe_ratio:
        signals.append("🟢 Erwartetes Gewinnwachstum (Forward P/E < Trailing P/E)")
        reasons.append(f"Forward P/E ({forward_pe:.2f}) deutet auf zukünftiges Gewinnwachstum hin.")

    # Dividendenstrategie
    if dividend_yield is not None and dividend_yield > 0.02: # Annahme: >2% als relevanter Wert
        if payout_ratio is not None and payout_ratio < 0.7: # Annahme: unter 70% als nachhaltig
            signals.append("🟢 Attraktive und nachhaltige Dividende")
            reasons.append(f"Dividendenrendite {dividend_yield:.2f}%, Ausschüttungsquote {payout_ratio:.1f}%.")

    # --- Technische Bewertung ---
    if current_price is not None and ma_50 is not None and ma_200 is not None:
        if current_price > ma_50 and ma_50 > ma_200:
            signals.append("🟢 Starker Aufwärtstrend (Kurs über MA(50) über MA(200))")
            reasons.append("Kurs bestätigt Aufwärtstrend.")
            # Wenn ein starker Trend vorliegt und keine entgegengesetzte fundamentale Empfehlung, verstärken
            if overall_recommendation == "🟡 Halten" or overall_recommendation == "🟢 Kaufen":
                overall_recommendation = "🟢 Kaufen"
        elif current_price < ma_50 and ma_50 < ma_200:
            signals.append("🔴 Abwärtstrend (Kurs unter MA(50) unter MA(200))")
            reasons.append("Kurs bestätigt Abwärtstrend.")
            if overall_recommendation == "🟡 Halten" or overall_recommendation == "🔴 Verkaufen":
                overall_recommendation = "🔴 Verkaufen"

    if rsi is not None:
        if rsi > 70:
            signals.append("🔴 Überkauft (RSI hoch)")
            reasons.append(f"RSI ({rsi:.1f}) deutet auf mögliche Korrektur hin.")
            # Wenn RSI überkauft ist, aber die Aktie als Kauf empfohlen wird, könnte es ein Halten sein
            if overall_recommendation == "🟢 Kaufen":
                overall_recommendation = "🟡 Halten"
        elif rsi < 30:
            signals.append("🟢 Überverkauft (RSI niedrig)")
            reasons.append(f"RSI ({rsi:.1f}) deutet auf mögliche Erholung hin.")
            # Wenn RSI überverkauft ist, aber die Aktie als Verkauf empfohlen wird, könnte es ein Halten sein
            if overall_recommendation == "🔴 Verkaufen":
                overall_recommendation = "🟡 Halten"

    # --- DCF-basierte Empfehlung (wenn verfügbar) ---
    if dcf_value is not None and current_price is not None and current_price > 0:
        dcf_upside = ((dcf_value - current_price) / current_price) * 100
        if dcf_upside > 20: # Beispiel: Über 20% Upside durch DCF gilt als signifikant
            signals.append("🟢 Erhebliches DCF Upside-Potenzial")
            reasons.append(f"DCF Wert ({format_currency(dcf_value)}) deutet auf {dcf_upside:+.1f}% Potenzial hin.")
            if overall_recommendation != "🔴 Verkaufen": # Nicht überschreiben, wenn Verkaufssignal sehr stark ist
                overall_recommendation = "🟢 Kaufen"
        elif dcf_upside < -10: # Beispiel: Unter -10% Downside durch DCF
            signals.append("🔴 DCF Downside-Potenzial")
            reasons.append(f"DCF Wert ({format_currency(dcf_value)}) deutet auf {dcf_upside:+.1f}% Downside hin.")
            if overall_recommendation != "🟢 Kaufen":
                overall_recommendation = "🔴 Verkaufen"

    # --- Einstiegs-/Ausstiegspreisvorschläge ---
    if current_price is not None:
        if overall_recommendation == "🟢 Kaufen" and ma_200 is not None:
            # Vorschlag für Entry: um den 200-Tage-MA oder leicht darunter bei einem Dip
            entry_price_suggestion = ma_200 * MA_OVERSOLD_MULTIPLIER
            reasons.append(f"Vorgeschlagene Kaufzone nahe 200-Tage-MA ({format_currency(entry_price_suggestion)}).")
        elif overall_recommendation == "🔴 Verkaufen" and ma_50 is not None:
            # Vorschlag für Exit: wenn der Kurs deutlich über dem MA(50) liegt (Überbewertung)
            exit_price_suggestion = ma_50 * MA_OVERBOUGHT_MULTIPLIER
            reasons.append(f"Vorgeschlagene Verkaufszone, wenn Kurs 20% über 50-Tage-MA ({format_currency(exit_price_suggestion)}).")

    # Removed redundant "AKTIENSTRATEGIE & EMPFEHLUNG" section to avoid duplication.
    # The main script (stock_analyzer.py) handles this output.

