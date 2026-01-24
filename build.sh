#!/bin/bash
set -e
cd "$(dirname "$0")"
if [ -z "$THEOS" ]; then
  if [ -d "$HOME/theos" ]; then export THEOS="$HOME/theos";
  elif [ -d "/var/mobile/theos" ]; then export THEOS="/var/mobile/theos";
  else echo "[错误] 未找到 Theos，请设置 $THEOS 环境变量"; exit 1; fi
fi
echo "[清理]"; make clean || true
echo "[打包]"; make package
LATEST=$(ls -t ./packages/*.deb | head -n1 || true)
[ -n "$LATEST" ] && echo "[完成] 生成: $LATEST" || { echo "[错误] 未生成 deb"; exit 1; }
