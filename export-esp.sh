#!/bin/bash

TOKEN="aPuWIWWHB8fOjsU9Uugp"
HOST="mqtt.thingsboard.cloud"
PORT=8883
CAFILE="/etc/ssl/certs/ca-certificates.crt"

GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RED="\e[31m"
RESET="\e[0m"

CURRENT_VER="1.0.0"
SPINNER="/-\|"

# === Spinner ===
spinner() {
  local pid=$1
  local delay=0.1
  # simple spinner while pid is running
  while ps -p $pid > /dev/null 2>&1; do
    for c in / - \\ \|; do
      printf " [%c] " "$c"
      sleep $delay
      printf "\b\b\b\b\b"
    done
  done
}

# === - boot ESP (panjang ~35 detik total) ===
-_boot() {
  clear
  echo -e "${GREEN}[BOOT] Multicore bootloader${RESET}"
  # Phase 1: bootloader init (~6s)
  (sleep 20) & spinner $!; wait
  echo "boot: chip revision: v0.2"
  echo "boot.esp32s3: Boot SPI Speed : 40MHz"
  echo "boot.esp32s3: SPI Flash Size : 16MB"

  # Phase 2: partition scan (~6s)
  (sleep 20) & spinner $!; wait
  echo "boot: Partition Table:"
  echo "## Label    Usage   Type ST Offset Length"
  echo "  0 nvs     WiFi data 01 02 00009000 00006000"
  echo "  1 phy_init RF data  01 01 0000f000 00001000"
  echo "  2 factory  app      00 00 00010000 00100000"

  # Phase 3: load segments (~8s)
  (sleep 50) & spinner $!; wait
  echo "esp_image: segment 0 loaded..."
  echo "esp_image: segment 1 loaded..."
  echo "esp_image: segment 2 loaded..."
  echo "esp_image: segment 3 loaded..."
  echo "esp_image: segment 4 loaded..."
  echo "esp_image: segment 5 loaded..."
  echo "esp_image: segment 6 loaded..."
  echo "esp_image: segment 7 loaded..."
  echo "esp_image: segment 8 loaded..."
  echo "esp_image: segment 9 loaded..."
  echo "esp_image: segment 10 loaded..."
  echo "esp_image: segment 11 loaded..."
  echo "esp_image: segment 12 loaded..."
  echo "esp_image: segment 13 loaded..."
  echo "esp_image: segment 14 loaded..."
  echo "esp_image: segment 15 loaded..."
  echo "esp_image: segment 16 loaded..."
  echo "esp_image: segment 17 loaded..."
  echo "esp_image: segment 18 loaded..."
  echo "esp_image: segment 19 loaded..."
  echo "esp_image: segment 20 loaded..."
  echo "esp_image: segment 21 loaded..."
  echo "esp_image: segment 22 loaded..."
  echo "esp_image: segment 23 loaded..."

  # Phase 3: load segments (~8s)
  (sleep 30) & spinner $!; wait
  echo "esp_image: segment 24 loaded..."
  echo "esp_image: segment 25 loaded..."
  echo "esp_image: segment 26 loaded..."
  echo "esp_image: segment 27 loaded..."
  echo "esp_image: segment 28 loaded..."
  echo "esp_image: segment 29 loaded..."
  echo "esp_image: segment 30 loaded..."
  echo "esp_image: segment 31 loaded..."
  echo "esp_image: segment 32 loaded..."
  echo "esp_image: segment 33 loaded..."
  echo "esp_image: segment 34 loaded..."
  echo "esp_image: segment 35 loaded..."
  echo "esp_image: segment 36 loaded..."
  echo "esp_image: segment 37 loaded..."
  echo "esp_image: segment 38 loaded..."
  echo "esp_image: segment 39 loaded..."
  echo "esp_image: segment 40 loaded..."
  echo "esp_image: segment 41 loaded..."
  echo "esp_image: segment 42 loaded..."
  echo "esp_image: segment 43 loaded..."
  echo "esp_image: segment 44 loaded..."
  echo "esp_image: segment 45 loaded..."
  echo "esp_image: segment 46 loaded..."
  echo "esp_image: segment 47 loaded..."
  
  # Phase 4: core up & app init (~8s)
  (sleep 20) & spinner $!; wait
  echo "cpu_start: Pro cpu up."
  echo "cpu_start: App version: v$CURRENT_VER"

  # Final small wait and app message (~2s)
  (sleep 12) & spinner $!; wait
  echo "app_main: iot14"
  echo ""
}

# === Download firmware (spinner shown) ===
download_fw() {
  local url="$1"
  echo -e "${BLUE}Downloading firmware from $url...${RESET}"
  # Use curl silently in background and show spinner
  (curl -s -L -o /tmp/ota.bin "$url") &
  pid=$!
  spinner $pid
  wait $pid

  if [[ -f /tmp/ota.bin ]]; then
    local actual_size
    actual_size=$(stat -c%s /tmp/ota.bin)
    echo -e "${GREEN}Download OK: $(ls -lh /tmp/ota.bin | awk '{print $5}') (${actual_size} bytes)${RESET}"
  else
    echo -e "${RED}Download failed!${RESET}"
    return 1
  fi
  return 0
}

# === Flashing - + build step + memory report ===
flashing_fw() {
  local fw_size=$1   # in bytes (may be 0 if unknown)
  local version=$2

  # If fw_size not provided or zero, try to read actual file size
  if [[ -z "$fw_size" || "$fw_size" -le 0 ]]; then
    if [[ -f /tmp/ota.bin ]]; then
      fw_size=$(stat -c%s /tmp/ota.bin)
    else
      fw_size=0
    fi
  fi

  # - a "build" step to take some time (~12 seconds)
  echo -e "${YELLOW}Building firmware image...${RESET}"
  # we will break the build into small chunks so spinner appears active
  (sleep 12) & spinner $!; wait
  echo -e "${GREEN}Build finished.${RESET}"

  # -d flashing: choose block size and total blocks based on fw_size
  local block_size=16384
  # Ensure at least 1 block to avoid division by zero
  if [[ "$fw_size" -le 0 ]]; then
    # default to 600 KB if fw_size unknown
    fw_size=$((600 * 1024))
  fi

  local total=$(( (fw_size + block_size - 1) / block_size ))
  local written=0

  echo -e "${YELLOW}Writing firmware to flash...${RESET}"
  # Make flashing take noticeable time; each block ~0.06s -> total approx total*0.06
  for i in $(seq 1 $total); do
    written=$((i * block_size))
    if [[ $written -gt $fw_size ]]; then
      written=$fw_size
    fi
    percent=$(( i * 100 / total ))
    printf "\rWriting at 0x%08X... (%3d%%) %d bytes" \
      $((0x10000 + (i-1)*block_size)) $percent $written
    # - time per block with spinner
    (sleep 0.06) & spinner $!; wait
  done
  echo ""
  echo "Wrote $written bytes..."

  # Print SHA256 if file exists
  if [[ -f /tmp/ota.bin ]]; then
    sha256sum /tmp/ota.bin | awk '{print "SHA256:", $1}'
  fi

  # === Memory usage report ===
  local flash_total=$((16 * 1024 * 1024))     # 16 MB total flash
  local part_factory=$((1 * 1024 * 1024))     # 1 MB factory partition
  # Avoid division by zero
  local percent_part=0
  local percent_flash=0
  if [[ "$part_factory" -gt 0 ]]; then
    percent_part=$(( fw_size * 100 / part_factory ))
  fi
  if [[ "$flash_total" -gt 0 ]]; then
    percent_flash=$(( fw_size * 100 / flash_total ))
  fi

  # Compute human readable sizes
  hr_fw_kb=$(awk "BEGIN { printf \"%.2f\", $fw_size/1024 }")
  hr_fw_mb=$(awk "BEGIN { printf \"%.2f\", $fw_size/1024/1024 }")

  echo ""
  echo -e "${BLUE}--- Memory Usage Report ---${RESET}"
  printf "Firmware size     : %d bytes (%.2f KB, %.2f MB)\n" "$fw_size" "$hr_fw_kb" "$hr_fw_mb"
  printf "Partition factory : %d bytes (1 MB)\n" "$part_factory"
  printf "Flash total       : %d bytes (16 MB)\n" "$flash_total"
  printf "Usage in partition: %d%%\n" "$percent_part"
  printf "Usage in flash    : %d%%\n" "$percent_flash"
  echo ""

  echo -e "${GREEN}Flashing completed. Booting into $version...${RESET}"
  # - short pause before boot
  (sleep 2) & spinner $!; wait
  CURRENT_VER="$version"
  -_boot
}

# === Handle OTA ===
handle_ota() {
  local json="$1"
  # parse fw_url fw_version fw_size from json string safely
  # Using grep -oP with escaped quotes to avoid breaking the script
  local fw_url
  local fw_version
  local fw_size

  fw_url=$(echo "$json" | grep -oP '(?<=\"fw_url\":\")[^\"]+' || true)
  fw_version=$(echo "$json" | grep -oP '(?<=\"fw_version\":\")[^\"]+' || true)
  fw_size=$(echo "$json" | grep -oP '(?<=\"fw_size\":)[0-9]+' || true)

  # If fw_size empty, fallback to 0 (will be replaced by actual file size)
  if [[ -z "$fw_size" ]]; then
    fw_size=0
  fi

  if [[ -n "$fw_url" ]]; then
    echo -e "${YELLOW}[OTA] Update available: version=${fw_version:-unknown}, size=$((fw_size/1024)) KB${RESET}"
    if download_fw "$fw_url"; then
      # if fw_size is zero, try reading from downloaded file
      if [[ "$fw_size" -le 0 && -f /tmp/ota.bin ]]; then
        fw_size=$(stat -c%s /tmp/ota.bin)
      fi
      flashing_fw "$fw_size" "${fw_version:-unknown}"
    else
      echo -e "${RED}[OTA] Download failed, aborting OTA${RESET}"
    fi
  fi
}

# === Boot awal (tampilkan boot panjang) ===
-_boot

# === Subscribe attributes from ThingsBoard (listen for ota and boot_pressed) ===
# run mosquitto_sub in background and process lines
mosquitto_sub -h "$HOST" -p "$PORT" -u "$TOKEN" \
  -t "v1/devices/me/attributes" \
  --cafile "$CAFILE" 2>/dev/null |
while read -r line; do
  # print raw attribute line
  echo -e "${YELLOW}[ATTR] $line${RESET}"
  # if attribute contains fw_url, handle ota (line likely contains JSON)
  if [[ "$line" == *"fw_url"* ]]; then
    handle_ota "$line"
  fi
  # if device publishes boot_pressed attribute (from firmware), - boot
  if [[ "$line" == *"boot_pressed"* ]]; then
    echo -e "${YELLOW}[ATTR] boot_pressed detected${RESET}"
    -_boot
  fi
done &

SUB_PID=$!

# === Key listener (optional) - keep for local manual testing; pressing 'b' triggers boot ===
(
  while true; do
    read -n1 key 2>/dev/null
    if [[ "$key" == "b" ]]; then
      echo -e "${YELLOW}[BUTTON] BOOT (local) pressed!${RESET}"
      -_boot
    fi
  done
) &

# === Telemetry loop (keep sending telemetry while script runs) ===
while true; do
  TEMP=$((20 + RANDOM % 10))
  HUM=$((50 + RANDOM % 20))

  mosquitto_pub -h "$HOST" -p "$PORT" -u "$TOKEN" \
    -t v1/devices/me/telemetry \
    -m "{\"temperature\":$TEMP, \"humidity\":$HUM}" \
    --cafile "$CAFILE" 2>/dev/null

  echo -e "${GREEN}[TELEMETRY] Sent temperature=$TEMP, humidity=$HUM${RESET}"
  sleep 5
done

trap "kill $SUB_PID 2>/dev/null" EXIT

