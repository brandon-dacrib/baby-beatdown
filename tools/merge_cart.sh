#!/bin/sh
# merge_cart.sh: build cart/merged_full.lua, the single Studio file (files run in creation order, so the merged
# file declares every table before the code that reads it): data, sprites, stage, engine, upload code.
cd "$(dirname "$0")/.." || exit 1
{
  cat cart/data.lua; echo
  cat cart/sprites.lua; echo
  cat cart/stage.lua; echo
  echo "-- ===== engine (cart/main.lua) ====="
  cat cart/main.lua; echo
  cat cart/upload.lua
} > cart/merged_full.lua
wc -c cart/merged_full.lua
