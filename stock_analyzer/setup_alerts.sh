#!/bin/bash

# Stock Alert System für Stock Analyzer
# Überwacht Aktien auf bestimmte Ereignisse und sendet Benachrichtigungen

OUTPUT_DIR="/home/ganzfrisch/finance/stock_analyzer/reports"
ALERT_DIR="$OUTPUT_DIR/alerts"
CONFIG_DIR="/home/ganzfrisch/finance/stock_analyzer/config"
ALERT_CONFIG="$CONFIG_DIR/alert_config.json"

# Standard-Mail-Adresse für Benachrichtigungen
DEFAULT_EMAIL="example@example.com"

# Erstelle Verzeichnisse
mkdir -p "$ALERT_DIR"
mkdir -p "$CONFIG_DIR"

# Erstelle Konfiguration, wenn sie noch nicht existiert
if [ ! -f "$ALERT_CONFIG" ]; then
    cat > "$ALERT_CONFIG" << EOL
{
    "email": "${DEFAULT_EMAIL}",
    "alerts": {
        "price_threshold": true,
        "analyst_rating_change": true,
        "dividend_announcement": true,
        "earnings_report": true,
        "unusual_volume": true,
        "technical_signals": false
    },
    "thresholds": {
        "price_change_percent": 5,
        "volume_increase_percent": 50,
        "minimum_analyst_count": 5
    },
    "watchlist": [
    ],
    "notification_methods": {
        "email": true,
        "file": true,
        "terminal": true
    }
}
EOL
    echo "Alert-Konfiguration erstellt: $ALERT_CONFIG"
    echo "Bitte passen Sie die Konfiguration an Ihre Bedürfnisse an."
    echo "Insbesondere sollten Sie Ihre E-Mail-Adresse eintragen und die gewünschten"
    echo "Aktien zur Watchlist hinzufügen."
fi

# Python-Skript für Alerts erstellen
ALERT_SCRIPT="${CONFIG_DIR}/generate_alerts.py"

if [ ! -f "$ALERT_SCRIPT" ]; then
    cat > "$ALERT_SCRIPT" << 'EOL'
#!/usr/bin/env python3

import sys
import os
import json
import yfinance as yf
import pandas as pd
from datetime import datetime, timedelta
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import argparse

def load_config(config_path):
    """Load alert configuration from JSON file"""
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading configuration: {e}")
        sys.exit(1)

def save_alert(alert_dir, symbol, alert_type, message):
    """Save alert to a file"""
    today = datetime.now().strftime('%Y%m%d')
    alert_file = os.path.join(alert_dir, f"alert_{today}.log")
    
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    alert_text = f"[{timestamp}] {symbol} - {alert_type}: {message}\n"
    
    with open(alert_file, 'a') as f:
        f.write(alert_text)
    
    return alert_text

def send_email(email, subject, message):
    """Send email alert"""
    # This function should be implemented with your email configuration
    # For example, using Gmail SMTP or another email provider
    # For now, we just print that an email would be sent
    print(f"Would send email to {email} with subject: {subject}")
    print(f"Message: {message}")
    
    # Uncomment and configure this section to actually send emails
    """
    try:
        sender_email = "your_email@gmail.com"
        password = "your_app_password"  # Use app password for Gmail
        
        msg = MIMEMultipart()
        msg['From'] = sender_email
        msg['To'] = email
        msg['Subject'] = subject
        
        msg.attach(MIMEText(message, 'plain'))
        
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(sender_email, password)
        server.send_message(msg)
        server.quit()
        
        print(f"Email sent successfully to {email}")
        return True
    except Exception as e:
        print(f"Failed to send email: {e}")
        return False
    """
    return True

def check_price_alerts(symbols, config, alert_dir):
    """Check for significant price changes"""
    alerts = []
    threshold = config['thresholds']['price_change_percent']
    
    for symbol in symbols:
        try:
            ticker = yf.Ticker(symbol)
            hist = ticker.history(period='5d')
            
            if len(hist) < 2:
                continue
                
            current_price = hist['Close'].iloc[-1]
            prev_price = hist['Close'].iloc[-2]
            
            price_change = (current_price - prev_price) / prev_price * 100
            
            if abs(price_change) >= threshold:
                direction = "up" if price_change > 0 else "down"
                message = f"Price {direction} {abs(price_change):.2f}% to {current_price:.2f}"
                alert = save_alert(alert_dir, symbol, "PRICE_ALERT", message)
                alerts.append(alert)
                
                # Send email alert if configured
                if config['notification_methods']['email']:
                    subject = f"Stock Alert: {symbol} price {direction} {abs(price_change):.2f}%"
                    send_email(config['email'], subject, message)
        except Exception as e:
            print(f"Error checking price for {symbol}: {e}")
    
    return alerts

def check_analyst_ratings(symbols, config, alert_dir):
    """Check for analyst rating changes"""
    alerts = []
    min_analysts = config['thresholds']['minimum_analyst_count']
    
    for symbol in symbols:
        try:
            ticker = yf.Ticker(symbol)
            recommendations = ticker.recommendations
            
            if recommendations is None or len(recommendations) < min_analysts:
                continue
                
            # Get the most recent two distinct recommendations
            recent_ratings = recommendations.sort_index(ascending=False)
            
            if len(recent_ratings) >= 2:
                latest_date = recent_ratings.index[0]
                prev_date = None
                
                # Find the previous date with different ratings
                for date in recent_ratings.index[1:]:
                    if recent_ratings.loc[date].equals(recent_ratings.loc[latest_date]):
                        continue
                    prev_date = date
                    break
                
                if prev_date is not None:
                    latest = recent_ratings.loc[latest_date]
                    previous = recent_ratings.loc[prev_date]
                    
                    # Check if there's a meaningful change in ratings
                    if 'To Grade' in latest and 'To Grade' in previous and latest['To Grade'] != previous['To Grade']:
                        message = f"Rating changed from {previous['To Grade']} to {latest['To Grade']} by {latest['Firm']}"
                        alert = save_alert(alert_dir, symbol, "ANALYST_ALERT", message)
                        alerts.append(alert)
                        
                        if config['notification_methods']['email']:
                            subject = f"Stock Alert: {symbol} analyst rating change"
                            send_email(config['email'], subject, message)
        except Exception as e:
            print(f"Error checking analyst ratings for {symbol}: {e}")
    
    return alerts

def check_volume_alerts(symbols, config, alert_dir):
    """Check for unusual volume"""
    alerts = []
    threshold = config['thresholds']['volume_increase_percent']
    
    for symbol in symbols:
        try:
            ticker = yf.Ticker(symbol)
            hist = ticker.history(period='20d')
            
            if len(hist) < 20:
                continue
                
            current_volume = hist['Volume'].iloc[-1]
            avg_volume = hist['Volume'].iloc[-20:-1].mean()
            
            if avg_volume > 0:
                volume_increase = (current_volume - avg_volume) / avg_volume * 100
                
                if volume_increase >= threshold:
                    message = f"Unusual volume (+{volume_increase:.2f}%) - Current: {current_volume:,.0f}, Avg: {avg_volume:,.0f}"
                    alert = save_alert(alert_dir, symbol, "VOLUME_ALERT", message)
                    alerts.append(alert)
                    
                    if config['notification_methods']['email']:
                        subject = f"Stock Alert: {symbol} unusual trading volume"
                        send_email(config['email'], subject, message)
        except Exception as e:
            print(f"Error checking volume for {symbol}: {e}")
    
    return alerts

def check_dividend_announcements(symbols, config, alert_dir):
    """Check for dividend announcements"""
    alerts = []
    
    for symbol in symbols:
        try:
            ticker = yf.Ticker(symbol)
            calendar = ticker.calendar
            
            if calendar is None or calendar.empty:
                continue
            
            # Check if there's a dividend date in the next 7 days
            if 'Dividend Date' in calendar.columns:
                div_date = calendar['Dividend Date'].iloc[0]
                
                if pd.notnull(div_date):
                    div_date = pd.to_datetime(div_date)
                    today = datetime.now().date()
                    
                    days_until = (div_date.date() - today).days
                    
                    if 0 <= days_until <= 7:
                        message = f"Dividend date approaching: {div_date.strftime('%Y-%m-%d')}"
                        alert = save_alert(alert_dir, symbol, "DIVIDEND_ALERT", message)
                        alerts.append(alert)
                        
                        if config['notification_methods']['email']:
                            subject = f"Stock Alert: {symbol} dividend date approaching"
                            send_email(config['email'], subject, message)
            
            # Check for dividend announcements
            dividends = ticker.dividends
            
            if dividends is not None and len(dividends) > 0:
                latest_div = dividends.sort_index(ascending=False).iloc[0]
                latest_div_date = dividends.index[-1]
                
                # Check if the announcement was recent (within the last 7 days)
                if (datetime.now().date() - latest_div_date.date()).days <= 7:
                    message = f"Recent dividend announced: {latest_div:.2f} on {latest_div_date.strftime('%Y-%m-%d')}"
                    alert = save_alert(alert_dir, symbol, "DIVIDEND_ALERT", message)
                    alerts.append(alert)
                    
                    if config['notification_methods']['email']:
                        subject = f"Stock Alert: {symbol} dividend announcement"
                        send_email(config['email'], subject, message)
        except Exception as e:
            print(f"Error checking dividends for {symbol}: {e}")
    
    return alerts

def check_earnings_reports(symbols, config, alert_dir):
    """Check for upcoming earnings reports"""
    alerts = []
    
    for symbol in symbols:
        try:
            ticker = yf.Ticker(symbol)
            calendar = ticker.calendar
            
            if calendar is None or calendar.empty:
                continue
            
            # Check for upcoming earnings date
            if 'Earnings Date' in calendar.columns:
                earnings_date = calendar['Earnings Date'].iloc[0]
                
                if pd.notnull(earnings_date):
                    earnings_date = pd.to_datetime(earnings_date)
                    today = datetime.now().date()
                    
                    days_until = (earnings_date.date() - today).days
                    
                    if 0 <= days_until <= 7:
                        message = f"Earnings report upcoming: {earnings_date.strftime('%Y-%m-%d')}"
                        alert = save_alert(alert_dir, symbol, "EARNINGS_ALERT", message)
                        alerts.append(alert)
                        
                        if config['notification_methods']['email']:
                            subject = f"Stock Alert: {symbol} earnings report upcoming"
                            send_email(config['email'], subject, message)
        except Exception as e:
            print(f"Error checking earnings for {symbol}: {e}")
    
    return alerts

def scan_from_watchlist(config, alert_dir):
    """Scan stocks from watchlist"""
    symbols = config['watchlist']
    
    if not symbols:
        print("No symbols in watchlist. Add symbols to the config file.")
        return []
    
    alerts = []
    
    if config['alerts']['price_threshold']:
        alerts.extend(check_price_alerts(symbols, config, alert_dir))
    
    if config['alerts']['analyst_rating_change']:
        alerts.extend(check_analyst_ratings(symbols, config, alert_dir))
    
    if config['alerts']['unusual_volume']:
        alerts.extend(check_volume_alerts(symbols, config, alert_dir))
    
    if config['alerts']['dividend_announcement']:
        alerts.extend(check_dividend_announcements(symbols, config, alert_dir))
    
    if config['alerts']['earnings_report']:
        alerts.extend(check_earnings_reports(symbols, config, alert_dir))
    
    return alerts

def scan_from_file(filename, config, alert_dir):
    """Scan stocks from a file"""
    try:
        with open(filename, 'r') as f:
            symbols = [line.strip() for line in f if line.strip()]
        
        print(f"Loaded {len(symbols)} symbols from {filename}")
        
        # Temporarily replace watchlist with file symbols
        original_watchlist = config['watchlist']
        config['watchlist'] = symbols
        
        alerts = scan_from_watchlist(config, alert_dir)
        
        # Restore original watchlist
        config['watchlist'] = original_watchlist
        
        return alerts
    except Exception as e:
        print(f"Error loading symbols from file: {e}")
        return []

def main():
    parser = argparse.ArgumentParser(description='Stock Alert System')
    parser.add_argument('--config', default='/home/ganzfrisch/finance/stock_analyzer/config/alert_config.json',
                      help='Path to the alert configuration file')
    parser.add_argument('--alert-dir', default='/home/ganzfrisch/finance/stock_analyzer/reports/alerts',
                      help='Directory to store alerts')
    parser.add_argument('--from-file', 
                      help='Read symbols from a file instead of the watchlist')
    parser.add_argument('--add-to-watchlist', action='store_true',
                      help='Add symbols from --from-file to the watchlist')
    parser.add_argument('--symbol', 
                      help='Check a single symbol')
    parser.add_argument('--quiet', action='store_true',
                      help='Suppress terminal output')
    
    args = parser.parse_args()
    
    config = load_config(args.config)
    
    alerts = []
    
    if args.symbol:
        # Check a single symbol
        original_watchlist = config['watchlist']
        config['watchlist'] = [args.symbol]
        alerts = scan_from_watchlist(config, args.alert_dir)
        config['watchlist'] = original_watchlist
    elif args.from_file:
        # Check symbols from a file
        alerts = scan_from_file(args.from_file, config, args.alert_dir)
        
        # Add symbols to watchlist if requested
        if args.add_to_watchlist:
            try:
                with open(args.from_file, 'r') as f:
                    symbols = [line.strip() for line in f if line.strip()]
                
                # Add unique symbols to watchlist
                for symbol in symbols:
                    if symbol not in config['watchlist']:
                        config['watchlist'].append(symbol)
                
                # Save updated config
                with open(args.config, 'w') as f:
                    json.dump(config, f, indent=4)
                
                print(f"Added {len(symbols)} symbols to watchlist")
            except Exception as e:
                print(f"Error adding symbols to watchlist: {e}")
    else:
        # Check watchlist
        alerts = scan_from_watchlist(config, args.alert_dir)
    
    if not args.quiet and alerts:
        print("\nAlerts generated:")
        for alert in alerts:
            print(alert.strip())
    
    print(f"\nTotal alerts: {len(alerts)}")
    
    return len(alerts) > 0

if __name__ == "__main__":
    main()
EOL

    chmod +x "$ALERT_SCRIPT"
    echo "Alert-Skript erstellt: $ALERT_SCRIPT"
fi

# Haupt-Alert-Skript
cat > "${ALERT_DIR}/run_alerts.sh" << EOL
#!/bin/bash

# Alert Runner für Stock Analyzer

CONFIG_DIR="/home/ganzfrisch/finance/stock_analyzer/config"
ALERT_CONFIG="\${CONFIG_DIR}/alert_config.json"
ALERT_SCRIPT="\${CONFIG_DIR}/generate_alerts.py"
ALERT_DIR="/home/ganzfrisch/finance/stock_analyzer/reports/alerts"
SYMBOLS_FILE="/home/ganzfrisch/finance/stock_analyzer/stock_symbols.txt"

# Prüfen ob Python-Pakete installiert sind
echo "Prüfe notwendige Python-Pakete..."
pip install --quiet yfinance pandas || {
    echo "Fehler: Konnte notwendige Python-Pakete nicht installieren. Bitte installieren Sie manuell:"
    echo "pip install yfinance pandas"
    exit 1
}

# Überprüfen ob alle benötigten Dateien existieren
if [ ! -f "\$ALERT_CONFIG" ]; then
    echo "Fehler: Alert-Konfiguration nicht gefunden: \$ALERT_CONFIG"
    exit 1
fi

if [ ! -f "\$ALERT_SCRIPT" ]; then
    echo "Fehler: Alert-Skript nicht gefunden: \$ALERT_SCRIPT"
    exit 1
fi

# Kommandozeilen-Parameter verarbeiten
CONFIG_ONLY=false
ADD_TO_WATCHLIST=false
USE_FILE=false
SYMBOL=""
QUIET=false

while [[ \$# -gt 0 ]]; do
    key="\$1"
    case \$key in
        --config-only)
        CONFIG_ONLY=true
        shift
        ;;
        --add-watchlist)
        ADD_TO_WATCHLIST=true
        USE_FILE=true
        shift
        ;;
        --from-file)
        USE_FILE=true
        shift
        ;;
        --symbol)
        SYMBOL="\$2"
        shift
        shift
        ;;
        --quiet)
        QUIET=true
        shift
        ;;
        *)
        shift
        ;;
    esac
done

# Nur Konfiguration anzeigen
if [ "\$CONFIG_ONLY" = true ]; then
    echo "Aktuelle Alert-Konfiguration:"
    cat "\$ALERT_CONFIG" | python3 -m json.tool
    exit 0
fi

# Führe die Alert-Prüfung aus
echo "Starte Alert-Prüfung..."

if [ -n "\$SYMBOL" ]; then
    # Einzelne Aktie prüfen
    python3 "\$ALERT_SCRIPT" --symbol "\$SYMBOL" \$([ "\$QUIET" = true ] && echo "--quiet")
elif [ "\$USE_FILE" = true ]; then
    # Aktien aus Datei prüfen
    if [ -f "\$SYMBOLS_FILE" ]; then
        python3 "\$ALERT_SCRIPT" --from-file "\$SYMBOLS_FILE" \
            \$([ "\$ADD_TO_WATCHLIST" = true ] && echo "--add-to-watchlist") \
            \$([ "\$QUIET" = true ] && echo "--quiet")
    else
        echo "Fehler: Symbole-Datei nicht gefunden: \$SYMBOLS_FILE"
        exit 1
    fi
else
    # Watchlist prüfen
    python3 "\$ALERT_SCRIPT" \$([ "\$QUIET" = true ] && echo "--quiet")
fi

# Aktuelle Alerts anzeigen
today=\$(date +%Y%m%d)
alert_file="\$ALERT_DIR/alert_\${today}.log"

if [ -f "\$alert_file" ] && [ "\$QUIET" = false ]; then
    echo ""
    echo "Heutige Alerts:"
    cat "\$alert_file"
    
    alert_count=\$(wc -l < "\$alert_file")
    echo ""
    echo "Insgesamt \$alert_count Alerts heute"
fi

# Erinnerung zur Einrichtung der Email-Konfiguration
email_config=\$(grep -c "your_email@gmail.com" "\$ALERT_SCRIPT")
if [ \$email_config -gt 0 ]; then
    echo ""
    echo "HINWEIS: Die Email-Konfiguration wurde noch nicht eingerichtet."
    echo "Bitte konfigurieren Sie die Email-Einstellungen im Skript:"
    echo "\$ALERT_SCRIPT"
    echo "Suchen Sie nach 'your_email@gmail.com' und passen Sie die Werte an."
fi
EOL

chmod +x "${ALERT_DIR}/run_alerts.sh"
echo "Alert-Runner erstellt: ${ALERT_DIR}/run_alerts.sh"

# Beispiel-Watchlist erstellen
echo "Erstelle Beispiel-Watchlist..."
python3 -c '
import json
import os

config_file = "/home/ganzfrisch/finance/stock_analyzer/config/alert_config.json"

if os.path.exists(config_file):
    with open(config_file, "r") as f:
        config = json.load(f)
    
    # Füge Beispiel-Aktien hinzu, wenn die Watchlist leer ist
    if not config["watchlist"]:
        config["watchlist"] = [
            "AAPL", "MSFT", "GOOGL", "AMZN", "META",
            "SAP.DE", "ALV.DE", "BMW.DE", "BAS.DE", "BAYN.DE"
        ]
        
        with open(config_file, "w") as f:
            json.dump(config, f, indent=4)
        
        print("Beispiel-Aktien zur Watchlist hinzugefügt")
else:
    print("Konfigurations-Datei nicht gefunden")
' 2>/dev/null || echo "Konnte Beispiel-Aktien nicht hinzufügen"

echo ""
echo "Stock Alert System wurde eingerichtet!"
echo ""
echo "Verwendung:"
echo "  ${ALERT_DIR}/run_alerts.sh                # Prüfe die Aktien in der Watchlist"
echo "  ${ALERT_DIR}/run_alerts.sh --from-file    # Prüfe alle Aktien aus stock_symbols.txt"
echo "  ${ALERT_DIR}/run_alerts.sh --symbol AAPL  # Prüfe eine einzelne Aktie"
echo "  ${ALERT_DIR}/run_alerts.sh --config-only  # Zeige die aktuelle Konfiguration"
echo "  ${ALERT_DIR}/run_alerts.sh --add-watchlist # Füge Aktien aus stock_symbols.txt zur Watchlist hinzu"
echo ""
echo "Für automatisierte Ausführung können Sie einen Cron-Job einrichten:"
echo "  0 9,12,15,18 * * 1-5 ${ALERT_DIR}/run_alerts.sh --quiet"

# Überprüfe ob die Watchlist befüllt wurde
if [ -f "$ALERT_CONFIG" ]; then
    watchlist_count=$(python3 -c "import json; f=open('$ALERT_CONFIG'); config=json.load(f); print(len(config['watchlist']))" 2>/dev/null)
    
    if [ -z "$watchlist_count" ] || [ "$watchlist_count" -eq 0 ]; then
        echo ""
        echo "HINWEIS: Ihre Watchlist ist leer. Fügen Sie Aktien hinzu mit:"
        echo "  ${ALERT_DIR}/run_alerts.sh --add-watchlist"
    else
        echo ""
        echo "Ihre Watchlist enthält $watchlist_count Aktien."
    fi
fi
