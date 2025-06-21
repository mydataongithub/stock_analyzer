# data_viz.py

import pandas as pd

def plot_price_history_ascii(history_data, period_days=90):
    """
    Generiert einen einfachen ASCII-Art-Plot der Schlusskurse.
    Args:
        history_data: Pandas DataFrame mit 'Close' Spalte.
        period_days: Anzahl der letzten Tage, die angezeigt werden sollen.
    Returns:
        Ein String, der den ASCII-Art-Plot darstellt.
    """
    if history_data is None or history_data.empty:
        return "Keine historischen Daten verfügbar für Visualisierung."

    # Stellen Sie sicher, dass 'Close' im DataFrame ist
    if 'Close' not in history_data.columns:
        return "Die Spalte 'Close' wurde in den historischen Daten nicht gefunden."

    recent_history = history_data['Close'].tail(period_days)
    if recent_history.empty:
        return f"Nicht genügend Daten für Visualisierung im angegebenen Zeitraum (letzte {period_days} Tage)."

    min_price = recent_history.min()
    max_price = recent_history.max()
    price_range = max_price - min_price
    
    if price_range <= 0.001: # Fast konstanter Preis, um Division durch Null zu vermeiden
        return "Preis bleibt über den Zeitraum nahezu konstant. Keine sinnvolle Visualisierung."

    num_rows = 10 # Höhe des Plots
    scale = (num_rows - 1) / price_range

    # Initialisiere die Plot-Linien mit Leerzeichen
    plot_lines = [' ' * len(recent_history) for _ in range(num_rows)]

    for i, price in enumerate(recent_history):
        # Normalisiere den Preis auf die Plot-Höhe (0 bis num_rows-1)
        row_index = int((price - min_price) * scale)
        row_index = min(max(0, row_index), num_rows - 1) # Sicherstellen, dass Index innerhalb der Grenzen liegt
        
        # Platziere ein Sternchen an der entsprechenden Position.
        # plot_lines[Zeile] = Teil vor *, *, Teil nach *
        # Wir müssen von oben nach unten plotten, daher num_rows - 1 - row_index
        plot_lines[num_rows - 1 - row_index] = (
            plot_lines[num_rows - 1 - row_index][:i] + '*' + 
            plot_lines[num_rows - 1 - row_index][i+1:]
        )

    plot_output = ["ASCII-ART KURSVERLAUF (Letzte {} Tage)".format(period_days)]
    plot_output.append(f"Hoch: {max_price:.2f} | Tief: {min_price:.2f}")
    plot_output.append("--------------------------------------------------")
    plot_output.extend(plot_lines)
    plot_output.append("--------------------------------------------------")
    plot_output.append("Datenpunkte: Jeder * repräsentiert einen Tag")

    return "\n".join(plot_output)

def compare_performance_ascii(stock_history, benchmark_history, stock_symbol, benchmark_symbol="S&P500", period_days=252):
    """
    Vergleicht die Performance der Aktie mit einem Benchmark-Index über einen Zeitraum.
    Zeigt die prozentuale Änderung an.
    Args:
        stock_history: Pandas DataFrame mit historischen Daten der Aktie.
        benchmark_history: Pandas DataFrame mit historischen Daten des Benchmarks.
        stock_symbol: Tickersymbol der Aktie.
        benchmark_symbol: Tickersymbol des Benchmarks.
        period_days: Anzahl der Handelstage für den Vergleich.
    Returns:
        Ein String, der den Performance-Vergleich darstellt.
    """
    if stock_history is None or stock_history.empty or benchmark_history is None or benchmark_history.empty:
        return "Nicht genügend Daten für Performance-Vergleich."
    
    # Stellen Sie sicher, dass 'Close' in beiden DataFrames ist
    if 'Close' not in stock_history.columns or 'Close' not in benchmark_history.columns:
        return "Spalte 'Close' nicht in den Verlaufsdaten für Performance-Vergleich gefunden."

    # Letzte N Tage
    # Sicherstellen, dass die Daten synchronisiert sind (gleiche Indizes)
    combined_history = pd.concat([stock_history['Close'], benchmark_history['Close']], axis=1, join='inner')
    combined_history.columns = ['stock_close', 'benchmark_close']
    
    recent_combined = combined_history.tail(period_days)

    if recent_combined.empty or len(recent_combined) < 2:
        return f"Nicht genügend gemeinsame Datenpunkte für Performance-Vergleich im angegebenen Zeitraum (letzte {period_days} Handelstage)."

    # Berechnung der kumulativen Renditen
    stock_returns = recent_combined['stock_close'].pct_change().dropna()
    benchmark_returns = recent_combined['benchmark_close'].pct_change().dropna()

    if stock_returns.empty or benchmark_returns.empty:
        return "Nicht genügend valide Renditedaten für Performance-Vergleich."

    stock_cum_returns = (1 + stock_returns).cumprod() - 1
    benchmark_cum_returns = (1 + benchmark_returns).cumprod() - 1

    final_stock_return = stock_cum_returns.iloc[-1] * 100 if not stock_cum_returns.empty else 0
    final_benchmark_return = benchmark_cum_returns.iloc[-1] * 100 if not benchmark_cum_returns.empty else 0

    output = []
    output.append("\nPERFORMANCE VERGLEICH (Letzte {} Handelstage)".format(period_days))
    output.append(f"--------------------------------------------------")
    output.append(f"{stock_symbol:<20}: {final_stock_return:+.2f}%")
    output.append(f"{benchmark_symbol:<20}: {final_benchmark_return:+.2f}%")
    output.append(f"--------------------------------------------------")
    
    if final_stock_return > final_benchmark_return:
        output.append(f"{stock_symbol} hat den {benchmark_symbol} outperformt!")
    elif final_stock_return < final_benchmark_return:
        output.append(f"{stock_symbol} hat den {benchmark_symbol} underperformt.")
    else:
        output.append(f"{stock_symbol} und {benchmark_symbol} haben ähnlich performt.")
    
    return "\n".join(output)

