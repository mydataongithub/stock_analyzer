# utils.py

from tabulate import tabulate

def format_currency(value):
    """
    Formatiert einen numerischen Wert als Währung.
    Args:
        value: Der zu formatierende numerische Wert.
    Returns:
        Ein formatierter String oder "N/A" wenn der Wert None ist.
    """
    if value is None:
        return "N/A"
    return f"${value:,.2f}"

def format_percentage(value):
    """
    Formatiert einen numerischen Wert als Prozent.
    Args:
        value: Der zu formatierende numerische Wert.
    Returns:
        Ein formatierter String oder "N/A" wenn der Wert None ist.
    """
    if value is None:
        return "N/A"
    return f"{value:.1f}%"

def print_section_header(title):
    """
    Druckt einen formatierten Abschnitts-Header.
    Args:
        title: Der Titel des Abschnitts.
    """
    print(f"\n{'='*60}")
    print(f"{title.upper().center(60)}")
    print(f"{'='*60}")

def print_subsection_header(title):
    """
    Druckt einen formatierten Unterabschnitts-Header.
    Args:
        title: Der Titel des Unterabschnitts.
    """
    print(f"\n{'─'*50}")
    print(f"{title.upper().center(50)}")
    print(f"{'─'*50}")

def display_table(data, headers, explanation_col=True):
    """
    Zeigt Daten in Tabellenform an. Erwartet eine Liste von Listen.
    Args:
        data: Eine Liste von Listen, die die Tabellenzeilen repräsentieren.
        headers: Eine Liste von Strings für die Spaltenüberschriften.
        explanation_col: Boolescher Wert, ob die Erläuterungsspalte (letzte Spalte) verwendet wird.
    """
    if explanation_col:
        print(tabulate(data, headers=headers, tablefmt="grid"))
    else:
        print(tabulate(data, headers=headers, tablefmt="grid"))

def handle_data_not_available(metric_name):
    """
    Gibt eine Meldung aus, wenn Daten für eine Metrik nicht verfügbar sind.
    Args:
        metric_name: Der Name der Metrik.
    """
    # Dies kann nach Bedarf angepasst werden, z.B. für Logging statt direktem Druck.
    # print(f"Hinweis: Daten für '{metric_name}' nicht verfügbar.")
    pass
