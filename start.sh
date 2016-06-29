#!/bin/bash

# start ssh
service ssh start
# start apache
service apache2 start
# start mysql
/etc/init.d/mysql start
# start asterisk
service asterisk start
# start amp
fwconsole reload

