#!/bin/bash

# 设置 JSON 文件存储的根目录
declare -a directories=(
  "/dashboards"
  "/dashboards_internal"
  "/dashboards_reports"
)

echo "Replace maptile api to $MAPTILE_API"

for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        # 遍历所有 JSON 文件
        find "$dir" -type f -name "*.json" | while read -r file; do
            echo "Processing $file..."
            # 替换占位符并覆盖文件
            sed -i -e "s|\${MAPTILE_API}|$MAPTILE_API|g" "$file"
        done
    fi
done

# 启动 Grafana
exec /run.sh