sudo apt update && apt remove -y bsd-mailx && sudo apt install -y msmtp msmtp-mta s-nail
# todo 这里有一个bsd-mailx 和s-nail的区分，默认是bsd-mailx，自用的话直接移除就好了，



account default
host smtp.gmail.com
port    465
from  wenzhuo4657@gmail.com
user wenzhuo4657@gmail.com
password  rgtpeuydxysjebpc


auth           on
tls            on
tls_starttls   off
tls_certcheck  on

tls_trust_file /etc/ssl/certs/ca-certificates.crt
# todo 这个ca是系统自带的，待区分

