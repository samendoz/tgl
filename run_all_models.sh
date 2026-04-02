#!/usr/bin/env bash
# run_all_models.sh — run collect_results.sh for all model configs on a given dataset
#
# Usage:
#   bash run_all_models.sh --data WIKI [--models "TGAT TGN APAN"] [-- extra train.py args]
#
# Examples:
#   bash run_all_models.sh --data WIKI
#   bash run_all_models.sh --data REDDIT --models "TGAT TGN"
#   bash run_all_models.sh --data WIKI -- --eval_neg_samples 10

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
DATA=""
MODELS="TGAT TGN APAN"
EXTRA_ARGS=()

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --data)    DATA="$2";   shift 2 ;;
        --models)  MODELS="$2"; shift 2 ;;
        --)        shift; EXTRA_ARGS=("$@"); break ;;
        *)         echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [ -z "$DATA" ]; then
    echo "ERROR: --data is required."
    echo "Usage: bash run_all_models.sh --data WIKI [--models \"TGAT TGN APAN\"] [-- extra args]"
    exit 1
fi

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
echo "Dataset : $DATA"
echo "Models  : $MODELS"
echo "Extra   : ${EXTRA_ARGS[*]}"
echo "========================================"

FAILED=()
for MODEL in $MODELS; do
    CONFIG="$REPO_DIR/config/${MODEL}.yml"
    if [ ! -f "$CONFIG" ]; then
        echo "WARNING: config not found for $MODEL ($CONFIG) — skipping."
        continue
    fi

    echo ""
    echo ">>> Running $MODEL on $DATA..."
    echo "----------------------------------------"
    if bash "$REPO_DIR/collect_results.sh" \
            --data "$DATA" \
            --config "$CONFIG" \
            "${EXTRA_ARGS[@]}"; then
        echo "<<< $MODEL on $DATA: DONE"
    else
        echo "<<< $MODEL on $DATA: FAILED (exit $?)"
        FAILED+=("$MODEL")
    fi
done

echo ""
echo "========================================"
if [ ${#FAILED[@]} -eq 0 ]; then
    echo "All models completed successfully."
else
    echo "Failed models: ${FAILED[*]}"
    exit 1
fi
