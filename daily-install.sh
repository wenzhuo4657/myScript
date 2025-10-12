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


REQUIRED_CMDS=(git  node mvn nginx )
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
cd dailyWeb-Front/daily
npm install
npm run build


rm -rf /var/www/daily
mkdir -p /var/www/daily
cp -r $homefront/dailyWeb-Front/daily/dist/* /var/www/daily
chown -R www-data:www-data /var/www/daily



echo "server {
          listen       80;
          server_name  daily.wenzhuo4657.org;

          location /md-web/ {
              alias  /var/www/daily/;
              try_files $uri $uri/ /md-web/index.html;
          }
           location /api/ {
                      # 预检
          if ($request_method = OPTIONS) {
              add_header Access-Control-Allow-Origin "*" always;
              add_header Access-Control-Allow-Methods "GET,POST,PUT,DELETE,OPTIONS" always;
              add_header Access-Control-Allow-Headers "Content-Type,Authorization,X-Requested-With" always;
              add_header Access-Control-Max-Age 86400 always;
              add_header Content-Length 0;
              add_header Content-Type text/plain;
              return 204;
          }
                      proxy_pass http://127.0.0.1:8080;
                      add_header Access-Control-Allow-Origin "*" always;
                      add_header Vary "Origin" always;
              }

      }
" > /etc/nginx/conf.d/daily.conf


echo "前端部署完成"


systemctl restart nginx
