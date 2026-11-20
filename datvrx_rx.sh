#!/usr/bin/env bash
# datvrx_rx.sh - DATV-Empfang mit datvrx (HB9IIU DATVision, DVB-S/S2-Code von OnAir) fuer QO-100 (DG7NDV)
#
# Aufruf:  ./datvrx_rx.sh QUELLE FREQ_MHZ [SYMBOLRATE_KS] [Optionen]      -> Transportstrom auf stdout
#
#   QUELLE   rtl-sdr | hackrf | pluto | sdrplay | soapy
#   FREQ     Downlink in MHz (10491.5 ... 10499.5); Werte unter dem LO gelten als direkte Empfangsfrequenz (z.B. 437)
#   SR       Symbolrate in kS (125, 333, 500, 1000, 1500) - nur fuer die Wahl des Versatzes und mit --rs; 0 = unbekannt
#
# Optionen:
#   --lo MHZ        LNB-LO (Standard: lnb_lo aus ~/.leandvb-GUI/parameters.json, sonst 9540)
#   --rate MSPS     Abtastrate (Standard: rtl-sdr 2.4, ab ca. 1100 kS 2.88, sonst 4)
#   --gain DB       Verstaerkung (rtl-sdr/pluto/sdrplay/soapy; Standard 40)
#   --lna DB --vga DB --amp   HackRF-Stufen (Standard LNA 32, VGA 30)
#   --ppm N         Frequenzkorrektur RTL-Stick (Standard: ppm aus ~/.leandvb-GUI/parameters.json, sonst 0)
#   --index N       RTL-Stick Nummer (Standard 0)
#   --serial S      HackRF-Seriennummer
#   --host IP       PlutoSDR-Adresse (Standard 192.168.2.1)
#   --ant A|B|C     SDRplay-Antenne (A, B oder C = Hi-Z; Standard A)
#   --args "..."    SoapySDR-Geraeteargumente bei QUELLE soapy (z.B. "driver=lime")
#   --carrier KHZ   Versatz zur Station (Standard automatisch: 300 kHz, wenn das Signal daneben noch passt)
#   --rs            Symbolrate an datvrx vorgeben (sonst sucht datvrx sie selbst)
#   --cells N       Konstellation: die letzten N Symbole (max 2048) 4x/s als "datvrx cells"-Zeile (fuer MER-Messung)
#   --gui           zusaetzliche Statuszeilen fuer die GUI (Traegerversatz, --cells 1)
#   --dry           nur die Befehle anzeigen
#
# Beispiele:
#   cd ~/sdr/leandvb-GUI/DATVision && ./datvrx_rx.sh rtl-sdr 10499.25 125 | ffplay -
#   ./datvrx_rx.sh rtl-sdr 10491.5 1500 --gain 38 | vlc -
#   ./datvrx_rx.sh sdrplay 10497.75 333 --ant A | ffplay -
#
# Statuszeilen von datvrx (und Meldungen der Quelle mit "[quelle]" davor) gehen auf stderr.

set -u
export LC_ALL=C LC_NUMERIC=C      # Zahlen immer mit Punkt (auf deutsch eingestellten Systemen schreibt awk sonst 1,500 -> datvrx sucht mit 1.0 MS/s)
cd "$(dirname "$0")" || exit 1

if [ $# -lt 2 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "--hilfe" ]; then
    sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi

QUELLE=$1; FREQ=${2/,/.}; shift 2
SR=0
if [ $# -gt 0 ] && [[ $1 =~ ^[0-9]+$ ]]; then SR=$1; shift; fi

# Standardwerte LO/ppm aus der Konfiguration der leandvb-GUI (falls vorhanden)
read -r LO PPM < <(python3 - <<'PYX' 2>/dev/null || echo "9540 0"
import json, os
try:
    d = json.load(open(os.path.expanduser("~/.leandvb-GUI/parameters.json")))
except Exception:
    d = {}
print(d.get("lnb_lo") or 9540, int(d.get("ppm") or 0))
PYX
)
[ -n "${LO:-}" ] || LO=9540; [ -n "${PPM:-}" ] || PPM=0
RATE=""; GAIN=40; LNA=32; VGA=30; AMP=0; INDEX=0; SERIAL=""; HOST=192.168.2.1
ANT=A; ARGS=""; CARRIER=""; USE_RS=0; DRY=0; GUI=0; CELLS=0
while [ $# -gt 0 ]; do
    case "$1" in
        --lo) LO=${2/,/.}; shift ;;
        --rate) RATE=${2/,/.}; shift ;;
        --gain) GAIN=$2; shift ;;
        --lna) LNA=$2; shift ;;
        --vga) VGA=$2; shift ;;
        --amp) AMP=1 ;;
        --ppm) PPM=$2; shift ;;
        --index) INDEX=$2; shift ;;
        --serial) SERIAL=$2; shift ;;
        --host) HOST=$2; shift ;;
        --ant) ANT=$2; shift ;;
        --args) ARGS=$2; shift ;;
        --carrier) CARRIER=$2; shift ;;
        --rs) USE_RS=1 ;;
        --dry) DRY=1 ;;
        --gui) GUI=1 ;;
        --cells) CELLS=$2; shift ;;
        *) echo "datvrx_rx.sh: unbekannte Option $1" >&2; exit 1 ;;
    esac
    shift
done

case "$QUELLE" in
    rtl-sdr|rtl_sdr|rtl) QUELLE=rtl-sdr; FMT=cu8
        # ohne --rate: breite Signale (z.B. 1500 kS) bekommen 2.88 MS/s, damit der Versatz noch passt
        if [ -z "$RATE" ]; then
            RATE=$(awk -v sr="$SR" 'BEGIN{ need = (sr > 0 ? sr : 1000) * 0.675 + 360;
                                           print (need < 1200 ? "2.4" : "2.88") }')
        fi ;;
    hackrf) FMT=cs8; : "${RATE:=4}" ;;
    pluto|sdrplay|soapy) FMT=cs16; : "${RATE:=4}" ;;
    *) echo "datvrx_rx.sh: unbekannte Quelle '$QUELLE' (rtl-sdr, hackrf, pluto, sdrplay, soapy)" >&2; exit 1 ;;
esac
[ -n "$RATE" ] || RATE=2.4

# Empfangsfrequenz (Hz): Downlink - LO; unter dem LO = direkte Frequenz
RF_HZ=$(awk -v f="$FREQ" -v lo="$LO" 'BEGIN{ if (f > lo) f = f - lo; printf "%d", f * 1000000 + 0.5 }')
# Versatz: Station 300 kHz neben die Mitte (Gleichspannungsspitze), wenn das Signal (Breite ~1,35 x SR) noch hineinpasst
if [ -z "$CARRIER" ]; then
    CARRIER=$(awk -v sr="$SR" -v r="$RATE" 'BEGIN{ half = r * 500; need = (sr > 0 ? sr : 1000) * 0.675 + 300 + 60;
                                            print (need < half ? 300 : 0) }')
fi
TUNE_HZ=$(( RF_HZ - CARRIER * 1000 ))
RATE_HZ=$(awk -v r="$RATE" 'BEGIN{ printf "%d", r * 1000000 }')

case "$QUELLE" in
    rtl-sdr)
        SRC=(rtl_sdr -d "$INDEX" -f "$TUNE_HZ" -s "$RATE_HZ" -g "$GAIN" -p "$PPM" -) ;;
    hackrf)
        SRC=(hackrf_transfer -r - -f "$TUNE_HZ" -s "$RATE_HZ" -l "$LNA" -g "$VGA" -a "$AMP")
        [ -n "$SERIAL" ] && SRC+=(-d "$SERIAL") ;;
    pluto)
        SRC=(rx_sdr -d "driver=plutosdr,hostname=$HOST" -f "$TUNE_HZ" -s "$RATE_HZ" -g "$GAIN" -F CS16 -) ;;
    sdrplay)
        SRC=(rx_sdr -d "driver=sdrplay" -a "Antenna $ANT" -f "$TUNE_HZ" -s "$RATE_HZ" -g "$GAIN" -F CS16 -) ;;
    soapy)
        SRC=(rx_sdr -d "$ARGS" -f "$TUNE_HZ" -s "$RATE_HZ" -g "$GAIN" -F CS16 -) ;;
esac

DVX=(./datvrx - --rate "$RATE" --format "$FMT" --std 0)
if [ "$CELLS" -gt 0 ]; then DVX+=(--cells "$CELLS"); elif [ "$GUI" = 1 ]; then DVX+=(--cells 1); fi
[ "$CARRIER" != "0" ] && DVX+=(--carrier "$CARRIER")
if [ "$USE_RS" = 1 ] && [ "$SR" -gt 0 ]; then
    DVX+=(--rs "$(awk -v s="$SR" 'BEGIN{ printf "%.3f", s / 1000 }')")
fi

echo "datvrx_rx: $QUELLE $FREQ MHz (LO $LO, ppm $PPM) -> Empfang $RF_HZ Hz, Stick auf $TUNE_HZ Hz (Versatz ${CARRIER} kHz), ${RATE} MS/s $FMT" >&2
echo "datvrx_rx: ${SRC[*]} | ${DVX[*]}" >&2
[ "$DRY" = 1 ] && exit 0

if ! command -v "${SRC[0]}" >/dev/null 2>&1; then
    echo "datvrx_rx: FEHLER ${SRC[0]} nicht gefunden" >&2
    exit 2
fi
[ -x ./datvrx ] || { echo "datvrx_rx: FEHLER ./datvrx fehlt in $(pwd)" >&2; exit 2; }

"${SRC[@]}" 2> >(sed -u 's/^/[quelle] /' >&2) | exec "${DVX[@]}"
