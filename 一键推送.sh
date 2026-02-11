#!/bin/sh
set -e

# ====== [核心修改] 适配 Rootless 越狱环境 ======
if [ "$(id -u)" -eq 0 ]; then
    echo "⚠️  检测到当前是 root 用户"
    echo "🔄 正在修正目录权限并切换为 mobile 用户执行..."
    chown -R mobile:mobile /var/mobile/binglan
    SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    exec su mobile -c "sh '$SCRIPT_PATH' '$@'"
fi
# ===========================================

# ====== 配置区 ======
REPO_DIR="/var/mobile/binglan"
DEBS_FOLDER="debs"
OVERRIDE_FILE="override" # 定义覆盖文件名称

# ✅ [修改点1] 这里更新为你的新仓库地址
REMOTE_URL="https://github.com/bl809000/bl809000.github.io.git"

TOKEN_FILE="/var/mobile/.gh_token"
# ===================

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
    echo "错误：未安装 dpkg-scanpackages，请先安装 dpkg-dev 插件！"
    exit 1
fi

SRC_DIR="${1:-$(pwd)}"
SRC_DIR="$(realpath "$SRC_DIR")"

echo "[0/7] 准备仓库环境"
mkdir -p "$REPO_DIR/$DEBS_FOLDER"
cd "$REPO_DIR"
touch "$OVERRIDE_FILE" # 确保 override 文件存在

git config --global --add safe.directory "$REPO_DIR" 2>/dev/null || true
git config --global --add safe.directory "/private$REPO_DIR" 2>/dev/null || true

# ✅ 脚本会自动把本地仓库的“目的地”修正为新地址
git remote set-url origin "$REMOTE_URL"
git pull --rebase || true

echo "[1/7] 正在处理插件包..."
# 使用临时文件存储文件列表
TMP_LIST=$(mktemp)
find "$SRC_DIR" -maxdepth 1 -type f -name "*.deb" > "$TMP_LIST"

while IFS= read -r f; do
  [ -z "$f" ] && continue
  
  # 读取 deb 信息
  pkg_id="$(dpkg-deb -f "$f" Package 2>/dev/null || true)"
  ver="$(dpkg-deb -f "$f" Version 2>/dev/null || true)"
  arch="$(dpkg-deb -f "$f" Architecture 2>/dev/null || true)"
  orig_section="$(dpkg-deb -f "$f" Section 2>/dev/null || true)"

  if [ -z "$pkg_id" ] || [ -z "$ver" ]; then
    echo "  ! 跳过无效文件：$(basename "$f")"
    continue
  fi

  [ -z "$arch" ] && arch="iphoneos-arm"
  [ -z "$orig_section" ] && orig_section="Unknown"
  
  new_name="${pkg_id}_${ver}_${arch}.deb"
  dst="$REPO_DIR/$DEBS_FOLDER/$new_name"
  
  echo "------------------------------------------------"
  echo "📦 发现插件: $(basename "$f")"
  echo "🏷️  ID: $pkg_id"
  echo "📂 原始分类: $orig_section"
  echo "------------------------------------------------"
  echo "请选择要推送到哪个分类 (Sileo 显示):"
  echo "1) 插件 (Tweaks) - [默认]"
  echo "2) 微信插件 (WeChat)"
  echo "3) 系统美化 (System)"
  echo "4) 滑雪板 (Themes/SnowBoard)"
  echo "5) 调整 (Adjustments)"
  echo "6) 配置 (Configuration)"
  echo "7) 保留原始分类 ($orig_section)"
  echo "8) 手动输入新分类"
  
  printf "请输入序号 [1-8]: "
  read -r choice < /dev/tty

  TARGET_SECTION=""
  case "$choice" in
    2) TARGET_SECTION="微信插件" ;;
    3) TARGET_SECTION="系统美化" ;;
    4) TARGET_SECTION="滑雪板" ;;
    5) TARGET_SECTION="调整" ;;
    6) TARGET_SECTION="配置" ;;
    7) TARGET_SECTION="" ;;
    8) 
       printf "请输入分类名称: "
       read -r custom_sec < /dev/tty
       TARGET_SECTION="$custom_sec"
       ;;
    *) TARGET_SECTION="插件" ;;
  esac

  if [ -n "$TARGET_SECTION" ]; then
      echo "✅ 已设定分类为: $TARGET_SECTION"
      grep -v "^$pkg_id " "$OVERRIDE_FILE" > "${OVERRIDE_FILE}.tmp" && mv "${OVERRIDE_FILE}.tmp" "$OVERRIDE_FILE"
      echo "$pkg_id 0 $TARGET_SECTION" >> "$OVERRIDE_FILE"
  else
      echo "👌 保持原始分类: $orig_section"
      grep -v "^$pkg_id " "$OVERRIDE_FILE" > "${OVERRIDE_FILE}.tmp" && mv "${OVERRIDE_FILE}.tmp" "$OVERRIDE_FILE"
  fi

  echo "  + 复制到仓库..."
  cp -f "$f" "$dst"

done < "$TMP_LIST"
rm -f "$TMP_LIST"

echo "[2/7] 生成 Packages 索引 (带 Override)"
dpkg-scanpackages -m "./$DEBS_FOLDER" "$OVERRIDE_FILE" > Packages

echo "[3/7] 压缩索引文件"
rm -f Packages.gz Packages.bz2 Packages.xz Packages.zst
gzip -9c Packages > Packages.gz
bzip2 -9c Packages > Packages.bz2
if command -v zstd >/dev/null 2>&1; then
    zstd -q -19 -c Packages > Packages.zst
fi

echo "[4/7] 提交到 Git"
git add .
if ! git diff --cached --quiet; then
    git commit -m "Update: $(date '+%Y-%m-%d %H:%M')"
else
    echo "无文件变动，跳过提交。"
fi

echo "[5/7] 准备推送"
printf "是否推送到 GitHub？(y/n): "
read ans < /dev/tty
case "$ans" in
  y|Y)
    TOKEN=""
    [ -f "$TOKEN_FILE" ] && TOKEN="$(cat "$TOKEN_FILE" | tr -d '\r\n ')"
    
    if [ -z "$TOKEN" ]; then
      printf "请输入 GitHub Token: "
      stty -echo
      read TOKEN < /dev/tty
      stty echo
      echo
    fi

    if [ -z "$TOKEN" ]; then
      echo "错误：无 Token，退出。"
      exit 1
    fi

    echo "正在推送..."
    # ✅ [修改点2] 推送 URL 也同步更新为 bl809000
    PUSH_URL="https://bl809000:${TOKEN}@github.com/bl809000/bl809000.github.io.git"
    
    if git push "$PUSH_URL"; then
        echo "✅ 推送成功！"
    else
        echo "❌ 推送失败。"
    fi
    ;;
  *) echo "已取消推送。" ;;
esac

echo "脚本执行完毕。"
