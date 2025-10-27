#!/bin/bash
# 获取指定仓库的tag的下载链接

# 设置仓库所有者和名称
OWNER=$1
REPO=$2

# API端点获取所有releases
API_URL="https://api.github.com/repos/$OWNER/$REPO/releases"

echo "正在获取仓库 $OWNER/$REPO 的所有releases..."
echo "=========================================="

# 使用curl获取releases数据
response=$(curl -s "$API_URL")

# 检查是否成功获取数据
if [[ $? -ne 0 ]]; then
    echo "错误：无法获取releases数据"
    exit 1
fi

# 解析JSON数据并提取信息
declare -i sum=$(echo "$response" | jq '. |  length')
tagList=()
urlList=()

for (( i = 0; i < sum; i++ )); do
       tag_name=$(echo "$response" | jq -r ".[$i].tag_name")
       tarball_url=$(echo "$response" | jq -r ".[$i].tarball_url")

       # 添加到数组
       tagList+=("$tag_name")
       urlList+=("$tarball_url")
done

echo "找到的releases数量: $sum"
echo "=========================================="

# 输出结果
for (( i = 0; i < sum; i++ )); do
    echo "Tag: ${tagList[$i]}"
    echo "URL: ${urlList[$i]}"
    echo "------------------------------------------"
done

# 选择tag
echo "请选择要下载的tag:"
select tag in "${tagList[@]}"; do
    if [[ -n "$tag" ]]; then
        echo "你选择了: $tag"
        break
    else
        echo "无效选择，请重新选择"
    fi
done

# 找到对应的URL
selected_url=""
for (( i = 0; i < sum; i++ )); do
    if [[ "${tagList[$i]}" == "$tag" ]]; then
        selected_url="${urlList[$i]}"
        break
    fi
done

# 导出变量供调用脚本使用
export SELECTED_URL="$selected_url"
export SELECTED_TAG="$tag"

echo "selected URL: $selected_url"

