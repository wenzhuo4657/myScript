#!/bin/bash

# 设置错误处理
set -e

# 1,设置安装目录，默认为~/snap/daiy
home_default="$HOME/snap/test"
home="$home_default"

echo "1) 设置安装目录，默认：$home_default"

read -r -p "是否使用默认目录？(Y/n): " ans

case "${ans:-y}" in
    [Nn])
        read -r -p "请输入自定义安装目录: " input_home
        home="$input_home"
        ;;
    *)
        home="$home_default"
        ;;
esac

# 创建安装目录
mkdir -p -- "$home"

# 设置环境变量
echo "export DAILY_HOME=$home" >> "$HOME/.bashrc"
echo "最终安装目录为：$home,对应环境变量DAILY_HOME"

# 创建项目目录
homeback="$home/daily-back"
homefront="$home/daily-front"
mkdir -p "$homeback"
mkdir -p "$homefront"

# 安装依赖软件
echo "检查并安装依赖软件..."
if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/wenzhuo4657/myScript/refs/heads/main/detectAptSoftware.sh | bash -s -- git node mvn nginx
else
    echo "curl未安装，请先安装curl"
    exit 1
fi

if [ $? -ne 0 ]; then
    echo "安装失败，请检查网络连接或手动安装依赖软件"
    exit 1
fi

# 函数：下载并获取release信息
get_release_info() {
    local owner="$1"
    local repo="$2"
    local temp_script="/tmp/release_selector_$(date +%s).sh"

    # 下载release选择脚本
    curl -fsSL "https://raw.githubusercontent.com/wenzhuo4657/myScript/refs/heads/main/DailyNotes/curl-releases.sh" -o "$temp_script"
    chmod +x "$temp_script"

    # 运行脚本并获取结果
    local result
    result=$("$temp_script" "$owner" "$repo")

    # 清理临时文件
    rm -f "$temp_script"

    echo "$result"
}

# 获取后端release信息
echo "选择后端版本..."
back_release=$(get_release_info "wenzhuo" "dailyNotes-back")
if [[ -z "$back_release" || "$back_release" == *"ERROR"* ]]; then
    echo "获取后端release失败"
    exit 1
fi
SELECTED_TAG=$(echo "$back_release" | awk '{print $1}')
SELECTED_URL=$(echo "$back_release" | awk '{print $2}')
back="$SELECTED_URL"
echo "选择的后端版本: $SELECTED_TAG"

# 获取前端release信息
echo "选择前端版本..."
front_release=$(get_release_info "wenzhuo" "dailyNotes-Front")
if [[ -z "$front_release" || "$front_release" == *"ERROR"* ]]; then
    echo "获取前端release失败"
    exit 1
fi
SELECTED_TAG=$(echo "$front_release" | awk '{print $1}')
SELECTED_URL=$(echo "$front_release" | awk '{print $2}')
front="$SELECTED_URL"
echo "选择的前端版本: $SELECTED_TAG"

# 后端部署
echo "开始进行后端部署..."
cd "$homeback"

# 下载后端tar.gz包
echo "下载后端源码包..."
back_filename="daily-back-$(date +%s).tar.gz"
if ! curl -L -o "$back_filename" "$back"; then
    echo "下载后端源码包失败"
    exit 1
fi

echo "解压后端源码包..."
if ! tar -xzf "$back_filename"; then
    echo "解压后端源码包失败"
    exit 1
fi

# 进入项目目录（根据实际解压后的目录结构调整）
cd dailyWeb-back/dailyWeb/

# Maven构建
echo "开始Maven构建..."
mvn clean package -DskipTests

# 创建备份目录
mkdir -p "$home/beifen"

# 启动后端服务
echo "启动后端服务..."
nohup java -Ddir.beifen="$home/beifen" -jar target/dailyWeb-1.0-SNAPSHOT.jar > "$home/back.log" 2>&1 &
BACK_PID=$!
echo "后端服务已启动，PID: $BACK_PID"
echo "后端日志: $home/back.log"

# 等待后端服务启动
sleep 10

# 检查后端服务是否启动成功
if ! curl -s http://localhost:8080 >/dev/null 2>&1; then
    echo "警告：后端服务可能未正常启动，请检查日志: $home/back.log"
fi

echo "后端部署完成"

# 前端部署
echo "开始进行前端部署..."

cd "$homefront"

# 下载前端tar.gz包
echo "下载前端源码包..."
front_filename="daily-front-$(date +%s).tar.gz"
if ! curl -L -o "$front_filename" "$front"; then
    echo "下载前端源码包失败"
    exit 1
fi

echo "解压前端源码包..."
if ! tar -xzf "$front_filename"; then
    echo "解压前端源码包失败"
    exit 1
fi

# 进入项目目录（根据实际解压后的目录结构调整）
cd dailyWeb-Front/daily

# 域名设置
read -r -p "设置使用的域名（默认为localhost）: " domain
domain="${domain:-localhost}"

# 确定API URL
if [[ "$domain" == "localhost" ]]; then
    api_url="http://localhost:8080"
else
    api_url="https://$domain"
fi

# 设置前端环境变量
export VITE_API_BASE_URL="$api_url"
export VITE_BACKGROUND_URL="https://blog.wenzhuo4657.org/img/2025/10/a1a61cd9c40ef9634219fe41ea93706b.jpg"

# 安装依赖并构建
echo "安装前端依赖..."
npm install

echo "构建前端项目..."
npm run build

# 部署前端文件
echo "部署前端文件到nginx..."
if [ -d "/var/www/daily" ]; then
    sudo rm -rf /var/www/daily
fi
sudo mkdir -p /var/www/daily
sudo cp -r "$homefront/dailyWeb-Front/daily/dist/"* /var/www/daily/
sudo chown -R www-data:www-data /var/www/daily

# Nginx配置
echo "配置nginx..."
sudo cat > /etc/nginx/conf.d/daily.conf.tmpl <<'NGINX'
server {
    listen 80;
    server_name ${domain};

    # 前端静态文件
    location / {
        root /var/www/daily;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;

        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # API代理
    location /api {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # CORS配置
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
        add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
        add_header 'Access-Control-Max-Age' 1728000 always;

        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }
}
NGINX

# 替换模板变量
sudo envsubst '$domain' < /etc/nginx/conf.d/daily.conf.tmpl | sudo tee /etc/nginx/conf.d/daily.conf > /dev/null
sudo rm -f /etc/nginx/conf.d/daily.conf.tmpl

echo "前端部署完成"

# 重启nginx
echo "重启nginx服务..."
sudo systemctl restart nginx

# 检查nginx状态
if sudo systemctl is-active --quiet nginx; then
    echo "nginx重启成功"
else
    echo "nginx重启失败，请检查配置"
    sudo nginx -t
fi

# 清理下载的压缩包
echo "清理临时文件..."
rm -f "$homeback/$back_filename"
rm -f "$homefront/$front_filename"

echo ""
echo "======================================"
echo "🎉 部署完成！"
echo "======================================"
echo "安装目录: $home"
echo "后端服务: http://localhost:8080"
echo "前端服务: http://$domain"
echo "后端日志: $home/back.log"
echo "后端进程ID: $BACK_PID"
echo ""
echo "使用以下命令查看服务状态："
echo "  ps aux | grep dailyWeb"
echo "  tail -f $home/back.log"
echo ""
echo "使用以下命令停止服务："
echo "  kill $BACK_PID"
echo "======================================"
