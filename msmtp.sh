apt install -y msmtp


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

