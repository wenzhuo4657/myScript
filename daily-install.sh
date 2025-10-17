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

mvn clean package

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

read -r -p "设置使用的域名，默认为80端口 "  domain

cat > /etc/nginx/conf.d/daily.conf.tmpl <<'NGINX'
server {
    listen 80;
    server_name ${domain};

    location /md-web/ {
        alias /var/www/daily/;
    }

    location /api/md {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        add_header Access-Control-Allow-Origin "*" always;
        add_header Vary "Origin" always;

        if ($request_method = OPTIONS) {
            return 204;
        }
    }
}
NGINX

envsubst '$domain' < /etc/nginx/conf.d/daily.conf.tmpl > /etc/nginx/conf.d/daily.conf


echo "前端部署完成"


systemctl restart nginx
