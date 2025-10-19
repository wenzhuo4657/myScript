#!/bin/bash

# 1,文件权限 2， 如何备份？
current_time=$(date "+%Y-%m-%d %H:%M:%S")
# 将包含时间的记录写入标准输出（stdout）
echo "[$current_time] 开始执行！！！"


echo "开始备份typecho博客数据"

DB_USER="root"
DB_PASSWORD="465700Aa." 
DB_NAME="typecho_blog"
BACKUP_PATH="$HOME/snap/beifen/blog"  

mkdir -p $BACKUP_PATH  #检查路径是否存在
BACKUP_DATE=$(date +%F)

BACKUP_FILE="$BACKUP_PATH/typecho_backup_$BACKUP_DATE.sql"

mysqldump -u $DB_USER -p$DB_PASSWORD $DB_NAME > $BACKUP_FILE


if [ $? -eq 0 ]; then
    echo "数据库备份成功！备份文件：$BACKUP_FILE"
else
    echo "数据库备份失败！"
fi



echo  "开始邮箱备份，备份邮箱: wenzhuo4657@gmail.com"
echo "备份"  | mailx -s "备份-typecho备份" -A  $BACKUP_FILE   wenzhuo4657@gmail.com


echo "邮箱备份完成"



echo "开始备份日程记录"
BACKUP_FILE="$BACKUP_PATH/mdWeb_backup_$BACKUP_DATE.md"
 
cp  $DAIL_HOME/beifen/beifen.db   $BACKUP_FILE
echo "备份"  | mailx -s "备份-daily备份" -A  $BACKUP_FILE   wenzhuo4657@gmail.com

#echo "备份"  | mailx -s "备份-typecho备份" -A  $BACKUP_FILE   wenzhuo4657@gmail.com
