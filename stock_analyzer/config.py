# config.py

# DCF Modell Parameter
DCF_GROWTH_RATE_BASE = 0.05       # 5% Basis-Wachstumsrate
DCF_GROWTH_RATE_OPTIMISTIC = 0.07 # 7% Optimistische Wachstumsrate
DCF_GROWTH_RATE_PESSIMISTIC = 0.03 # 3% Pessimistische Wachstumsrate
DCF_DISCOUNT_RATE_BASE = 0.10    # 10% Basis-Diskontierungsrate
DCF_DISCOUNT_RATE_OPTIMISTIC = 0.09 # 9% Optimistische Diskontierungsrate
DCF_DISCOUNT_RATE_PESSIMISTIC = 0.12 # 12% Pessimistische Diskontierungsrate
DCF_TERMINAL_GROWTH = 0.03       # 3% terminale Wachstumsrate
DCF_YEARS = 5                    # Anzahl der Jahre für detaillierte Prognose

# Technische Indikatoren
RSI_PERIOD = 14                  # RSI Periode

# Empfehlungs-Schwellenwerte
PE_RATIO_UNDERRVALUED_THRESHOLD = 15 # KGV unter diesem Wert gilt als potenziell unterbewertet
PE_RATIO_OVERVALUED_THRESHOLD = 25  # KGV über diesem Wert gilt als potenziell überbewertet
MA_OVERBOUGHT_MULTIPLIER = 1.2     # Kurs 20% über MA(50)
MA_OVERSOLD_MULTIPLIER = 0.95      # Kurs 5% unter MA(200)

# Allgemeine Einstellungen
HISTORICAL_DATA_PERIOD = "2y"    # Historische Daten für 2 Jahre
