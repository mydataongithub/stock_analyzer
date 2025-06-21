#!/bin/bash

# HTML Report Generator für Stock Analyzer
# Generiert interaktive HTML-Reports aus den Analyseergebnissen

OUTPUT_DIR="/home/ganzfrisch/finance/stock_analyzer/reports"
HTML_DIR="$OUTPUT_DIR/html"

# Überprüfen ob Argument übergeben wurde (Zeitstempel)
if [ $# -eq 0 ]; then
    echo "Bitte Zeitstempel als Argument übergeben, z.B.:"
    echo "$0 20250621_120000"
    echo "Oder 'latest' für die neuesten Dateien."
    exit 1
fi

TIMESTAMP="$1"

# Bei "latest" den neuesten Zeitstempel finden
if [ "$TIMESTAMP" == "latest" ]; then
    # Versuche zuerst die neuere Namenskonvention (Zusammenfassungsdateien)
    TIMESTAMP=$(ls -1t "$OUTPUT_DIR"/stock_analysis_summary_*.txt 2>/dev/null | head -1 | sed -E 's/.*stock_analysis_summary_([0-9]+_[0-9]+)\.txt/\1/')
    
    if [ -z "$TIMESTAMP" ]; then
        # Versuche ältere Namenskonvention
        TIMESTAMP=$(ls -1t "$OUTPUT_DIR"/stock_analysis_*_batch1.txt 2>/dev/null | head -1 | sed -E 's/.*stock_analysis_([0-9]+_[0-9]+)_batch1\.txt/\1/')
    fi
    
    if [ -z "$TIMESTAMP" ]; then
        echo "Keine Analysedateien gefunden"
        exit 1
    fi
    
    echo "Neuester Zeitstempel gefunden: $TIMESTAMP"
fi

# Prüfen ob Dateien existieren
SUMMARY_FILE="$OUTPUT_DIR/stock_analysis_summary_${TIMESTAMP}.txt"
BUY_FILE="$OUTPUT_DIR/buy_recommendations_${TIMESTAMP}.txt"
SELL_FILE="$OUTPUT_DIR/sell_recommendations_${TIMESTAMP}.txt"
# Für neuere Version der analyse_stock.py mit Symbolen im Dateinamen
if [ -d "$OUTPUT_DIR/analysis_$TIMESTAMP" ]; then
    # Berücksichtige auch leicht abweichende Zeitstempel in den Dateinamen
    TIMESTAMP_PREFIX=${TIMESTAMP:0:11} # Nimm die ersten 11 Zeichen (YYYYmmdd_HH)
    BATCH_FILES=("$OUTPUT_DIR/analysis_$TIMESTAMP/stock_analysis_"*"_$TIMESTAMP_PREFIX"*.txt)
else
    # Für ältere Version, die Batch-Nummern im Namen hat
    BATCH_FILES=("$OUTPUT_DIR/stock_analysis_${TIMESTAMP}_"*.txt)
fi

if [ ! -f "$SUMMARY_FILE" ] || [ ! -f "$BUY_FILE" ] || [ ! -f "$SELL_FILE" ]; then
    echo "Fehler: Eine oder mehrere zusammenfassende Dateien wurden nicht gefunden für Zeitstempel $TIMESTAMP"
    exit 1
fi

# Überprüfe Batch-Dateien
if [ ${#BATCH_FILES[@]} -eq 0 ] || [ ! -e "${BATCH_FILES[0]}" ]; then
    echo "Warnung: Keine Analyse-Dateien gefunden für das Format: ${BATCH_FILES[0]}"
    # Versuche das alternative Format mit flexiblerem Zeitstempel-Matching
    if [ -d "$OUTPUT_DIR/analysis_$TIMESTAMP" ]; then
        # Nimm die ersten 11 Zeichen des Zeitstempels (YYYYmmdd_HH) für flexibles Matching
        TIMESTAMP_PREFIX=${TIMESTAMP:0:11}
        BATCH_FILES=("$OUTPUT_DIR/analysis_$TIMESTAMP/"stock_analysis_*"_$TIMESTAMP_PREFIX"*.txt)
        if [ ${#BATCH_FILES[@]} -eq 0 ] || [ ! -e "${BATCH_FILES[0]}" ]; then
            # Ein letzter Versuch - alle Dateien im Verzeichnis verwenden
            BATCH_FILES=("$OUTPUT_DIR/analysis_$TIMESTAMP/"stock_analysis_*.txt)
            if [ ${#BATCH_FILES[@]} -eq 0 ] || [ ! -e "${BATCH_FILES[0]}" ]; then
                echo "Fehler: Keine Analyse-Dateien gefunden im Verzeichnis $OUTPUT_DIR/analysis_$TIMESTAMP"
                exit 1
            fi
        fi
    else
        echo "Fehler: Keine Analyse-Dateien gefunden für Zeitstempel $TIMESTAMP"
        exit 1
    fi
fi

# HTML-Verzeichnis erstellen
mkdir -p "$HTML_DIR"

# Hauptbericht HTML-Datei
HTML_MAIN="$HTML_DIR/report_${TIMESTAMP}.html"

# CSS für besseres Styling
CSS=$(cat <<'ENDCSS'
<style>
    body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        line-height: 1.6;
        color: #333;
        max-width: 1200px;
        margin: 0 auto;
        padding: 20px;
        background: #f5f5f5;
    }
    h1, h2, h3 {
        color: #2c3e50;
    }
    .container {
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        margin-bottom: 20px;
    }
    table {
        width: 100%;
        border-collapse: collapse;
        margin: 20px 0;
    }
    th, td {
        padding: 12px 15px;
        text-align: left;
        border-bottom: 1px solid #ddd;
    }
    th {
        background-color: #f2f2f2;
        font-weight: bold;
        cursor: pointer;
    }
    tr:hover {
        background-color: #f5f5f5;
    }
    .buy {
        color: #27ae60;
        font-weight: bold;
    }
    .sell {
        color: #e74c3c;
        font-weight: bold;
    }
    .neutral {
        color: #3498db;
    }
    .stock-card {
        border: 1px solid #ddd;
        border-radius: 4px;
        padding: 15px;
        margin-bottom: 15px;
        background: white;
    }
    .stock-card h3 {
        margin-top: 0;
        border-bottom: 1px solid #eee;
        padding-bottom: 10px;
    }
    .filters {
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        margin-bottom: 20px;
    }
    .filters select, .filters input {
        padding: 8px;
        border: 1px solid #ddd;
        border-radius: 4px;
    }
    .tab {
        overflow: hidden;
        border: 1px solid #ccc;
        background-color: #f1f1f1;
        border-radius: 8px 8px 0 0;
    }
    .tab button {
        background-color: inherit;
        float: left;
        border: none;
        outline: none;
        cursor: pointer;
        padding: 14px 16px;
        transition: 0.3s;
        font-size: 17px;
    }
    .tab button:hover {
        background-color: #ddd;
    }
    .tab button.active {
        background-color: #fff;
        border-bottom: 2px solid #2c3e50;
    }
    .tabcontent {
        display: none;
        padding: 20px;
        border: 1px solid #ccc;
        border-top: none;
        border-radius: 0 0 8px 8px;
        background-color: white;
    }
    .show {
        display: block;
    }
</style>
ENDCSS
)

# JavaScript für Interaktivität
JS=$(cat <<'ENDJS'
<script>
    // Tabellensortierung
    function sortTable(tableId, n) {
        var table, rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;
        table = document.getElementById(tableId);
        switching = true;
        dir = "asc";
        
        while (switching) {
            switching = false;
            rows = table.rows;
            
            for (i = 1; i < (rows.length - 1); i++) {
                shouldSwitch = false;
                x = rows[i].getElementsByTagName("TD")[n];
                y = rows[i + 1].getElementsByTagName("TD")[n];
                
                // Numerischer Vergleich für Zahlen
                if (!isNaN(parseFloat(x.innerHTML)) && !isNaN(parseFloat(y.innerHTML))) {
                    if (dir == "asc") {
                        if (parseFloat(x.innerHTML) > parseFloat(y.innerHTML)) {
                            shouldSwitch = true;
                            break;
                        }
                    } else if (dir == "desc") {
                        if (parseFloat(x.innerHTML) < parseFloat(y.innerHTML)) {
                            shouldSwitch = true;
                            break;
                        }
                    }
                } else {
                    // Textvergleich
                    if (dir == "asc") {
                        if (x.innerHTML.toLowerCase() > y.innerHTML.toLowerCase()) {
                            shouldSwitch = true;
                            break;
                        }
                    } else if (dir == "desc") {
                        if (x.innerHTML.toLowerCase() < y.innerHTML.toLowerCase()) {
                            shouldSwitch = true;
                            break;
                        }
                    }
                }
            }
            
            if (shouldSwitch) {
                rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
                switching = true;
                switchcount++;
            } else {
                if (switchcount == 0 && dir == "asc") {
                    dir = "desc";
                    switching = true;
                }
            }
        }
    }

    // Filterung der Tabelle
    function filterTable() {
        var input, filter, table, tr, td, i, j, txtValue;
        input = document.getElementById("searchInput");
        filter = input.value.toUpperCase();
        table = document.getElementById("summaryTable");
        tr = table.getElementsByTagName("tr");
        
        for (i = 1; i < tr.length; i++) {
            var display = false;
            for (j = 0; j < tr[i].cells.length; j++) {
                td = tr[i].cells[j];
                if (td) {
                    txtValue = td.textContent || td.innerText;
                    if (txtValue.toUpperCase().indexOf(filter) > -1) {
                        display = true;
                    }
                }
            }
            tr[i].style.display = display ? "" : "none";
        }
    }

    // Tab-Wechsel
    function openTab(evt, tabName) {
        var i, tabcontent, tablinks;
        tabcontent = document.getElementsByClassName("tabcontent");
        for (i = 0; i < tabcontent.length; i++) {
            tabcontent[i].style.display = "none";
        }
        tablinks = document.getElementsByClassName("tablinks");
        for (i = 0; i < tablinks.length; i++) {
            tablinks[i].className = tablinks[i].className.replace(" active", "");
        }
        document.getElementById(tabName).style.display = "block";
        evt.currentTarget.className += " active";
    }

    // Beim Laden der Seite den ersten Tab öffnen
    document.addEventListener('DOMContentLoaded', function() {
        document.getElementsByClassName("tablinks")[0].click();
    });
</script>
ENDJS
)

# HTML-Header erstellen
cat > "$HTML_MAIN" << EOL
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Stock Analysis Report - ${TIMESTAMP}</title>
    ${CSS}
</head>
<body>
    <div class="container">
        <h1>Stock Analysis Report</h1>
        <p><strong>Datum:</strong> $(date -d "${TIMESTAMP:0:8}" "+%d.%m.%Y") $(echo ${TIMESTAMP:9:2}:${TIMESTAMP:11:2})</p>
    </div>
    
    <div class="tab">
        <button class="tablinks" onclick="openTab(event, 'Summary')">Zusammenfassung</button>
        <button class="tablinks" onclick="openTab(event, 'Buy')">Kaufempfehlungen</button>
        <button class="tablinks" onclick="openTab(event, 'Sell')">Verkaufsempfehlungen</button>
        <button class="tablinks" onclick="openTab(event, 'Details')">Detailanalysen</button>
    </div>
    
    <div id="Summary" class="tabcontent">
        <h2>Zusammenfassung</h2>
        <div class="filters">
            <input type="text" id="searchInput" onkeyup="filterTable()" placeholder="Suche...">
        </div>
        <table id="summaryTable">
            <tr>
                <th onclick="sortTable('summaryTable', 0)">Symbol</th>
                <th onclick="sortTable('summaryTable', 1)">Unternehmen</th>
                <th onclick="sortTable('summaryTable', 2)">Aktueller Kurs</th>
                <th onclick="sortTable('summaryTable', 3)">Kursziel</th>
                <th onclick="sortTable('summaryTable', 4)">Upside</th>
                <th onclick="sortTable('summaryTable', 5)">Empfehlung</th>
            </tr>
EOL

# Extrahiere Informationen aus den Batch-Dateien für die Zusammenfassung
for output_file in "${BATCH_FILES[@]}"; do
    # Extrahiere Symbol aus dem Dateinamen
    if [[ "$output_file" =~ stock_analysis_([A-Za-z0-9\.]+)_ ]]; then
        symbol=${BASH_REMATCH[1]}
    else
        # Versuche Symbol aus dem Dateiinhalt zu extrahieren
        while IFS= read -r line; do
            if [[ "$line" == *"AKTIENANALYSE:"* ]]; then
                symbol=$(echo "$line" | cut -d ":" -f 2 | tr -d ' ')
                break
            fi
        done < "$output_file"
    fi
    
    if [[ -z "$symbol" ]]; then
        echo "Warnung: Kein Symbol gefunden für Datei $output_file"
        continue
    fi
    
    # Extrahiere weitere Infos
    company=$(grep -A 3 "Unternehmen" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
    current_price=$(grep -A 2 "Aktueller Kurs" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
    target_price=$(grep -A 2 "Analysten-Kursziel" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
    upside=$(grep -A 2 "Upside-Potenzial" "$output_file" | head -n 1 | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
    
    # Empfehlung bestimmen
    if grep -q "Gesamtempfehlung.*Kaufen" "$output_file"; then
        recommendation="<span class=\"buy\">Kaufen</span>"
    elif grep -q "Gesamtempfehlung.*Verkaufen" "$output_file"; then
        recommendation="<span class=\"sell\">Verkaufen</span>"
    elif grep -q "Gesamtempfehlung.*Halten" "$output_file"; then
        recommendation="<span class=\"neutral\">Halten</span>"
    else
        recommendation="N/A"
    fi
    
    # Zur Tabelle hinzufügen
    echo "<tr>" >> "$HTML_MAIN"
    echo "<td>$symbol</td>" >> "$HTML_MAIN"
    echo "<td>$company</td>" >> "$HTML_MAIN"
    echo "<td>$current_price</td>" >> "$HTML_MAIN"
    echo "<td>$target_price</td>" >> "$HTML_MAIN"
    echo "<td>$upside</td>" >> "$HTML_MAIN"
    echo "<td>$recommendation</td>" >> "$HTML_MAIN"
    echo "</tr>" >> "$HTML_MAIN"
done

# Kaufempfehlungen Tab
cat >> "$HTML_MAIN" << EOL
        </table>
    </div>
    
    <div id="Buy" class="tabcontent">
        <h2>Kaufempfehlungen</h2>
EOL

# Versuche Kaufempfehlungen aus der Datei einzulesen
buy_recommendations=$(grep -A 20 "Symbol:" "$BUY_FILE" | sed -e 's/--*/\n/g')

if [ -n "$buy_recommendations" ]; then
    # Konvertiere das Textformat in HTML-Karten
    echo "$buy_recommendations" | while IFS= read -r block; do
        if [[ "$block" == *"Symbol"* ]]; then
            symbol=$(echo "$block" | grep "Symbol:" | sed 's/Symbol: \(.*\)/\1/')
            company=$(echo "$block" | grep "Unternehmen:" | sed 's/Unternehmen: \(.*\)/\1/')
            current=$(echo "$block" | grep "Aktueller Kurs:" | sed 's/Aktueller Kurs: \(.*\)/\1/')
            target=$(echo "$block" | grep "Kursziel:" | sed 's/Kursziel: \(.*\)/\1/')
            upside=$(echo "$block" | grep "Upside:" | sed 's/Upside: \(.*\)/\1/')
            dcf=$(echo "$block" | grep "DCF-Wert:" | sed 's/DCF-Wert: \(.*\)/\1/')
            strengths=$(echo "$block" | grep "Stärken:" | sed 's/Stärken: \(.*\)/\1/')
            weaknesses=$(echo "$block" | grep "Schwächen:" | sed 's/Schwächen: \(.*\)/\1/')
            
            cat >> "$HTML_MAIN" << EOL
            <div class="stock-card">
                <h3>${company} (${symbol})</h3>
                <p><strong>Aktueller Kurs:</strong> ${current}</p>
                <p><strong>Kursziel:</strong> ${target}</p>
                <p><strong>Upside-Potenzial:</strong> ${upside}</p>
EOL
            
            if [ -n "$dcf" ]; then
                echo "<p><strong>DCF-Wert:</strong> ${dcf}</p>" >> "$HTML_MAIN"
            fi
            
            cat >> "$HTML_MAIN" << EOL
                <p><strong>Stärken:</strong> ${strengths}</p>
                <p><strong>Schwächen/Risiken:</strong> ${weaknesses}</p>
            </div>
EOL
        fi
    done
else
    echo "<p>Keine Kaufempfehlungen gefunden</p>" >> "$HTML_MAIN"
fi

# Verkaufsempfehlungen Tab
cat >> "$HTML_MAIN" << EOL
    </div>
    
    <div id="Sell" class="tabcontent">
        <h2>Verkaufsempfehlungen</h2>
EOL

# Versuche Verkaufsempfehlungen aus der Datei einzulesen
sell_recommendations=$(grep -A 20 "Symbol:" "$SELL_FILE" | sed -e 's/--*/\n/g')

if [ -n "$sell_recommendations" ]; then
    # Konvertiere das Textformat in HTML-Karten
    echo "$sell_recommendations" | while IFS= read -r block; do
        if [[ "$block" == *"Symbol"* ]]; then
            symbol=$(echo "$block" | grep "Symbol:" | sed 's/Symbol: \(.*\)/\1/')
            company=$(echo "$block" | grep "Unternehmen:" | sed 's/Unternehmen: \(.*\)/\1/')
            current=$(echo "$block" | grep "Aktueller Kurs:" | sed 's/Aktueller Kurs: \(.*\)/\1/')
            target=$(echo "$block" | grep "Kursziel:" | sed 's/Kursziel: \(.*\)/\1/')
            upside=$(echo "$block" | grep "Upside/Downside:" | sed 's/Upside\/Downside: \(.*\)/\1/')
            dcf=$(echo "$block" | grep "DCF-Wert:" | sed 's/DCF-Wert: \(.*\)/\1/')
            strengths=$(echo "$block" | grep "Stärken:" | sed 's/Stärken: \(.*\)/\1/')
            risks=$(echo "$block" | grep "Risiken:" | sed 's/Risiken: \(.*\)/\1/')
            
            cat >> "$HTML_MAIN" << EOL
            <div class="stock-card">
                <h3>${company} (${symbol})</h3>
                <p><strong>Aktueller Kurs:</strong> ${current}</p>
                <p><strong>Kursziel:</strong> ${target}</p>
                <p><strong>Upside/Downside:</strong> ${upside}</p>
EOL
            
            if [ -n "$dcf" ]; then
                echo "<p><strong>DCF-Wert:</strong> ${dcf}</p>" >> "$HTML_MAIN"
            fi
            
            cat >> "$HTML_MAIN" << EOL
                <p><strong>Stärken:</strong> ${strengths}</p>
                <p><strong>Risiken:</strong> ${risks}</p>
            </div>
EOL
        fi
    done
else
    echo "<p>Keine Verkaufsempfehlungen gefunden</p>" >> "$HTML_MAIN"
fi

# Details Tab mit Links zu einzelnen Analysen
cat >> "$HTML_MAIN" << EOL
    </div>
    
    <div id="Details" class="tabcontent">
        <h2>Detailanalysen</h2>
        <ul>
EOL

for output_file in "${BATCH_FILES[@]}"; do
    # Erstelle für jede Batch-Datei eine eigene HTML-Datei
    batch_name=$(basename "$output_file")
    html_batch_file="$HTML_DIR/${batch_name%.txt}.html"
    
    # Konvertiere die Batch-Datei in HTML
    {
        echo "<!DOCTYPE html>"
        echo "<html lang=\"de\">"
        echo "<head>"
        echo "    <meta charset=\"UTF-8\">"
        echo "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
        echo "    <title>Detailanalyse - ${batch_name}</title>"
        echo "    ${CSS}"
        echo "</head>"
        echo "<body>"
        echo "    <div class=\"container\">"
        echo "        <h1>Detailanalyse</h1>"
        echo "        <p><a href=\"report_${TIMESTAMP}.html\">Zurück zur Übersicht</a></p>"
        echo "        <pre>"
        cat "$output_file" | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g'  # HTML-Escape
        echo "        </pre>"
        echo "    </div>"
        echo "</body>"
        echo "</html>"
    } > "$html_batch_file"
    
    # Füge Link zur Hauptdatei hinzu
    echo "<li><a href=\"${batch_name%.txt}.html\" target=\"_blank\">Batch ${batch_name##*_batch}</a></li>" >> "$HTML_MAIN"
done

# HTML-Footer
cat >> "$HTML_MAIN" << EOL
        </ul>
    </div>
    
    ${JS}
</body>
</html>
EOL

# Fertigstellungsmeldung
echo "HTML-Report wurde erstellt:"
echo "$HTML_MAIN"
echo ""
echo "Öffnen Sie die Datei in einem Browser, um den interaktiven Report zu sehen."
