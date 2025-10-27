#!/bin/bash
# 检查依赖是否安装

REQUIRED_CMDS=()
for (( i = 1; i <= $#; i++ )); do
    REQUIRED_CMDS+=("${!i}")
done


echo "检查依赖安装安装： ${REQUIRED_CMDS[*]}"

missing=()

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "✔ %s 已安装：%s\n" "$cmd" "$(command -v "$cmd")"
  else
    printf "✘ %s 未安装\n" "$cmd"
    missing+=("$cmd")
  fi
}

for c in "${REQUIRED_CMDS[@]}"; do
  check_cmd "$c"
done

if ((${#missing[@]} > 0)); then
  echo
  echo "缺少的依赖：${missing[*]}"
  echo "请先安装后重试。"
  exit 1
else
  echo "所有依赖已安装。"
  exit 0
fi

