#!/bin/bash

# Dynamiczne pobranie nazwy aktualnego użytkownika i jego katalogu domowego
USER_HOME=$HOME
CURRENT_USER=$(whoami)
SCRIPT_PATH="$USER_HOME/klipper_restart_uart.sh"

echo "===================================================="
echo " Instalator automatycznego restartu UART dla Klippera"
echo " Użytkownik: $CURRENT_USER | Katalog: $USER_HOME"
echo "===================================================="

# 1. Tworzenie skryptu monitorującego
echo "[1/4] Tworzenie skryptu monitorującego w $SCRIPT_PATH..."

cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash
while true; do
    # Pobranie statusu drukarki z API Moonrakera
    STATUS=$(curl -s http://localhost:7125/printer/info | grep -o '"state":"[^"]*' | grep -o '[^"]*$')
    
    # Jeśli Klipper zgłasza błąd komunikacji (shutdown/error), wymuś restart firmware
    if [ "$STATUS" = "shutdown" ] || [ "$STATUS" = "error" ]; then
        curl -s -X POST http://localhost:7125/printer/firmware_restart > /dev/null
    fi
    sleep 5
done
EOF

# 2. Nadawanie uprawnień do uruchamiania
echo "[2/4] Nadawanie uprawnień wykonywania dla skryptu..."
chmod +x "$SCRIPT_PATH"

# 3. Dodawanie do crontab (zabezpieczenie przed duplikatami)
echo "[3/4] Konfiguracja autostartu w cron (@reboot)..."
CRON_JOB="@reboot $SCRIPT_PATH &"

# Sprawdzenie czy wpis już istnieje w crontab
(crontab -l 2>/dev/null | grep -F "$SCRIPT_PATH") >/dev/null
if [ $? -eq 0 ]; then
    echo " -> Wpis w cron już istnieje. Pomijam dopisywanie."
else
    # Bezpieczne dopisanie nowej linijki do istniejącego crontaba
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo " -> Pomyślnie dodano skrypt do autostartu (cron)."
fi

# 4. Pierwsze uruchomienie w tle
echo "[4/4] Uruchamianie skryptu w tle po raz pierwszy..."
# Zabij stary proces jeśli istniał, aby nie dublować pętli
pkill -f "$SCRIPT_PATH" 2>/dev/null
nohup "$SCRIPT_PATH" > /dev/null 2>&1 &

echo "===================================================="
echo " INSTALACJA ZAKOŃCZONA SUKCESEM!"
echo " Skrypt działa w tle. Przeprowadź test:"
echo " Wyłącz i włącz drukarkę włącznikiem."
echo " Klipper powinien automatycznie wstać po ok. 5 sek."
echo "===================================================="
