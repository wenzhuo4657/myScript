#!/bin/bash

# 1,设置安装目录，默认为~/snap/daiy


home_default="$HOME/snap/test"
home="$home_default"

echo "1) 设置安装目录，默认：$home_default"

read -r -p "是否使用默认目录？(Y/n): " ans


case "${ans:-y}"  in
	[Nn])
		read -r -p "请输入自定义安装目录: " input_home
		home="$input_home"
		;;
	*)
		home="$home_default"
		;;
esac

mkdir -p -- "$home"


echo "export DAILY_HOME=$home"  >> $HOME/.bashrc
source .bashrc
echo "最终安装目录为：$home,对应环境变量DAILY_HOME"



homeback="$home/daily-back"
homefront="$home/daily-front"
mkdir  -p $homeback
mkdir -p $homefront


REQUIRED_CMDS=(git screen node mvn nginx )
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
  echo
  echo "所有依赖已安装。"
fi



echo	"开始进行后端部署"
cd $homeback
git clone  https://github.com/wenzhuo4657/dailyWeb-back.git
cd dailyWeb-back/dailyWeb/

mvn clean package > /dev/null

nohup java  -Ddir.beifen=$home/beifen -jar  target/dailyWeb-1.0-SNAPSHOT.jar  &

echo "后端部署完成"

echo "开始进行前端部署"
cd $homefront
git clone    https://github.com/wenzhuo4657/dailyWeb-Front.git
npm run build

# TODO 这里要插入nginx的server，通过server_name进行区分，且注意，目录权限


echo "前端部署完成"
