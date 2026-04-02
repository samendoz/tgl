#!/usr/bin/env bash
# collect_results.sh — run train.py and capture all output to a structured log
#
# Usage:
#   bash collect_results.sh --data WIKI --config config/TGN.yml [any other train.py args]
#
# Output:
#   results/WIKI_TGN_<timestamp>.log   — full stdout/stderr
#   results/WIKI_TGN_<timestamp>.csv   — parsed per-epoch metrics + final test

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$REPO_DIR/results"
mkdir -p "$RESULTS_DIR"

# ---------------------------------------------------------------------------
# Extract --data and --config from args to build a meaningful filename
# ---------------------------------------------------------------------------
DATA=""
CONFIG=""
ARGS=("$@")
for i in "${!ARGS[@]}"; do
    case "${ARGS[$i]}" in
        --data)   DATA="${ARGS[$((i+1))]}" ;;
        --config) CONFIG="${ARGS[$((i+1))]}" ;;
    esac
done

MODEL=$(basename "${CONFIG%.*}")          # e.g. TGN from config/TGN.yml
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
STEM="${DATA}_${MODEL}_${TIMESTAMP}"
LOG_FILE="$RESULTS_DIR/${STEM}.log"
CSV_FILE="$RESULTS_DIR/${STEM}.csv"

echo "Logging to: $LOG_FILE"
echo "CSV will be written to: $CSV_FILE"
echo "---"

# ---------------------------------------------------------------------------
# Run training — tee to log file, output still visible in terminal
# ---------------------------------------------------------------------------
python "$REPO_DIR/train.py" "$@" 2>&1 | tee "$LOG_FILE"

# ---------------------------------------------------------------------------
# Parse log into CSV (runs after training completes, zero training overhead)
# ---------------------------------------------------------------------------
python3 - "$LOG_FILE" "$CSV_FILE" << 'PYEOF'
import sys, re, csv

log_path = sys.argv[1]
csv_path = sys.argv[2]

epoch_re   = re.compile(r'Epoch\s+(\d+)')
metrics_re = re.compile(r'train loss:([\d.]+)\s+val ap:([\d.]+)\s+val auc:([\d.]+)')
timing_re  = re.compile(r'total time:([\d.]+)s\s+sample time:([\d.]+)s\s+prep time:([\d.]+)s')
test_re    = re.compile(r'test AP:([\d.]+)\s+test (?:AUC|MRR):([\d.]+)')

rows = []
current = {}

with open(log_path) as f:
    for line in f:
        line = line.strip()
        m = epoch_re.search(line)
        if m:
            current = {'epoch': m.group(1)}
            continue
        m = metrics_re.search(line)
        if m and current:
            current.update({'train_loss': m.group(1), 'val_ap': m.group(2), 'val_auc': m.group(3)})
            continue
        m = timing_re.search(line)
        if m and current:
            current.update({'time_total': m.group(1), 'time_sample': m.group(2), 'time_prep': m.group(3)})
            rows.append(current)
            current = {}
            continue
        m = test_re.search(line)
        if m:
            rows.append({'epoch': 'test', 'val_ap': m.group(1), 'val_auc': m.group(2)})

if not rows:
    print("No metrics found in log — CSV not written.")
    sys.exit(0)

fieldnames = ['epoch', 'train_loss', 'val_ap', 'val_auc', 'time_total', 'time_sample', 'time_prep']
with open(csv_path, 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction='ignore')
    w.writeheader()
    w.writerows(rows)

print(f"Metrics saved to {csv_path} ({len(rows)} rows)")
PYEOF
