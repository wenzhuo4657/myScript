#!/bin/bash

set -e

# 1) Choose install directory (default: ~/snap/test)
home_default="$HOME/snap/test"
home="$home_default"

echo "1) Install directory default: $home_default"
read -r -p "Use default directory? (Y/n): " ans
case "${ans:-y}" in
  [Nn])
    read -r -p "Enter custom install directory: " input_home
    home="$input_home"
    ;;
  *)
    home="$home_default"
    ;;
esac

# Ensure install directory exists
mkdir -p -- "$home"

# Export env var for future shells
echo "export DAILY_HOME=$home" >> "$HOME/.bashrc"
echo "Using install directory: $home (exported DAILY_HOME)"

# Prepare working directories
homeback="$home/daily-back"
homefront="$home/daily-front"
mkdir -p "$homeback" "$homefront"

# Dependencies check
echo "Checking required dependencies..."
if command -v curl >/dev/null 2>&1; then
  # Check presence of tools (script only checks; it does not install)
  curl -fsSL https://raw.githubusercontent.com/wenzhuo4657/myScript/main/detectAptSoftware.sh \
    | bash -s -- git node npm mvn nginx jq
else
  echo "curl is not installed. Please install curl first."
  exit 1
fi

if [ $? -ne 0 ]; then
  echo "Dependency check failed. Please install the missing tools and retry."
  exit 1
fi

# Helper: interactively select a GitHub release and return "<tag> <url>"
get_release_info() {
  local owner="$1"
  local repo="$2"
  local temp_script="/tmp/release_selector_$(date +%s).sh"

  # Download the selector script (correct raw URL)
  curl -fsSL "https://raw.githubusercontent.com/wenzhuo4657/myScript/main/DailyNotes/curl-releases.sh" -o "$temp_script"
  chmod +x "$temp_script"

  # Run it in current shell to capture exported vars, while keeping its UI visible
  local tag url
  if [ -t 1 ]; then
    # Preserve user prompts/output to terminal; only our final echo is captured
    exec 3>&1
    # shellcheck disable=SC1090
    source "$temp_script" "$owner" "$repo" 1>&3
    exec 3>&-
  else
    # shellcheck disable=SC1090
    source "$temp_script" "$owner" "$repo"
  fi

  tag="${SELECTED_TAG:-}"
  url="${SELECTED_URL:-}"

  rm -f "$temp_script"

  if [[ -z "$tag" || -z "$url" ]]; then
    echo "ERROR: failed to get release info" >&2
    return 1
  fi

  echo "$tag $url"
}

# Choose backend release
echo "Select backend version..."
back_release=$(get_release_info "wenzhuo" "dailyNotes-back")
if [[ -z "$back_release" || "$back_release" == *"ERROR"* ]]; then
  echo "Failed to get backend release info"
  exit 1
fi
SELECTED_TAG=$(echo "$back_release" | awk '{print $1}')
SELECTED_URL=$(echo "$back_release" | awk '{print $2}')
back="$SELECTED_URL"
echo "Selected backend tag: $SELECTED_TAG"

# Choose frontend release
echo "Select frontend version..."
front_release=$(get_release_info "wenzhuo" "dailyNotes-Front")
if [[ -z "$front_release" || "$front_release" == *"ERROR"* ]]; then
  echo "Failed to get frontend release info"
  exit 1
fi
SELECTED_TAG=$(echo "$front_release" | awk '{print $1}')
SELECTED_URL=$(echo "$front_release" | awk '{print $2}')
front="$SELECTED_URL"
echo "Selected frontend tag: $SELECTED_TAG"

# Backend setup
echo "Starting backend setup..."
cd "$homeback"

echo "Downloading backend source..."
back_filename="daily-back-$(date +%s).tar.gz"
if ! curl -L -o "$back_filename" "$back"; then
  echo "Failed to download backend source"
  exit 1
fi

echo "Extracting backend source..."
if ! tar -xzf "$back_filename"; then
  echo "Failed to extract backend source"
  exit 1
fi

# The extracted structure is expected like dailyWeb-back/dailyWeb
cd dailyWeb-back/dailyWeb/

echo "Building backend with Maven..."
mvn clean package -DskipTests

# Prepare data dir
mkdir -p "$home/beifen"

echo "Launching backend service..."
nohup java -Ddir.beifen="$home/beifen" -jar target/dailyWeb-1.0-SNAPSHOT.jar > "$home/back.log" 2>&1 &
BACK_PID=$!
echo "Backend started with PID: $BACK_PID"
echo "Backend logs: $home/back.log"

sleep 10
if ! curl -s http://localhost:8080 >/dev/null 2>&1; then
  echo "Warning: backend may not be up yet. Check logs: $home/back.log"
fi
echo "Backend setup complete"

# Frontend setup
echo "Starting frontend setup..."
cd "$homefront"

echo "Downloading frontend source..."
front_filename="daily-front-$(date +%s).tar.gz"
if ! curl -L -o "$front_filename" "$front"; then
  echo "Failed to download frontend source"
  exit 1
fi

echo "Extracting frontend source..."
if ! tar -xzf "$front_filename"; then
  echo "Failed to extract frontend source"
  exit 1
fi

# The extracted structure is expected like dailyWeb-Front/daily
cd dailyWeb-Front/daily

read -r -p "Domain to use (default: localhost): " domain
domain="${domain:-localhost}"

if [[ "$domain" == "localhost" ]]; then
  api_url="http://localhost:8080"
else
  api_url="https://$domain"
fi

export VITE_API_BASE_URL="$api_url"
export VITE_BACKGROUND_URL="https://blog.wenzhuo4657.org/img/2025/10/a1a61cd9c40ef9634219fe41ea93706b.jpg"

echo "Installing frontend deps..."
npm install

echo "Building frontend..."
npm run build

echo "Publishing frontend to nginx..."
if [ -d "/var/www/daily" ]; then
  sudo rm -rf /var/www/daily
fi
sudo mkdir -p /var/www/daily
sudo cp -r "$homefront/dailyWeb-Front/daily/dist/"* /var/www/daily/
sudo chown -R www-data:www-data /var/www/daily

echo "Configuring nginx..."
sudo cat > /etc/nginx/conf.d/daily.conf.tmpl <<'NGINX'
server {
    listen 80;
    server_name ${domain};

    location / {
        root /var/www/daily;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;

        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    location /api {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

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

# Substitute domain into template
sudo envsubst '$domain' < /etc/nginx/conf.d/daily.conf.tmpl | sudo tee /etc/nginx/conf.d/daily.conf > /dev/null
sudo rm -f /etc/nginx/conf.d/daily.conf.tmpl

echo "Frontend setup complete"

echo "Restarting nginx..."
sudo systemctl restart nginx

if sudo systemctl is-active --quiet nginx; then
  echo "nginx restarted successfully"
else
  echo "nginx restart failed; see nginx -t output"
  sudo nginx -t || true
fi

echo "Cleaning temporary archives..."
rm -f "$homeback/$back_filename" "$homefront/$front_filename"

echo ""
echo "======================================"
echo "Install completed"
echo "======================================"
echo "Install dir: $home"
echo "Backend URL: http://localhost:8080"
echo "Frontend URL: http://$domain"
echo "Backend log: $home/back.log"
echo "Backend PID: $BACK_PID"
echo ""
echo "Useful commands:"
echo "  ps aux | grep dailyWeb"
echo "  tail -f $home/back.log"
echo "  kill $BACK_PID"
echo "======================================"

