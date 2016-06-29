#asterisk docker file for unraid 6
FROM phusion/baseimage:0.9.18
MAINTAINER marc brown <marc@22walker.co.uk> v0.4

# Set correct environment variables.
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive
ENV ASTERISKUSER asterisk
ENV ASTERISKVER 13.1
ENV FREEPBXVER 12.0.21
ENV ASTERISK_DB_PW pass123
ENV AUTOBUILD_UNIXTIME 1418234402

RUN rm -f /etc/service/sshd/down

# Regenerate SSH host keys. baseimage-docker does not contain any, so you
# have to do that yourself. You may also comment out this instruction; the
# init system will auto-generate one during boot.
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

## Install an SSH of your choice.
ADD your_key.pub /tmp/your_key.pub
RUN cat /tmp/your_key.pub >> /root/.ssh/authorized_keys && rm -f /tmp/your_key.pub

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Add VOLUME to allow backup of FREEPBX
VOLUME ["/etc/freepbxbackup"]

# open up ssh port
# open up ports needed by freepbx and asterisk 4569 udp iax2 5060 tcp sip reg 80 tcp web port 10000-20000 udp rtp stream  
EXPOSE 22
EXPOSE 4569/udp
EXPOSE 5060
EXPOSE 80
EXPOSE 8009
EXPOSE 10000-20000/udp

# Add start.sh
ADD start.sh /root/

#Install packets that are needed
RUN apt-get update && apt-get install -y aptitude build-essential curl libgtk2.0-dev linux-headers-4.4.0-24-generic openssh-server apache2 mysql-server mysql-client bison flex php5 php5-curl php5-cli php5-mysql php-pear php5-gd curl sox libncurses5-dev libssl-dev libmysqlclient-dev mpg123 libxml2-dev libnewt-dev sqlite3 libsqlite3-dev pkg-config automake libtool autoconf git unixodbc-dev uuid uuid-dev libasound2-dev libogg-dev libvorbis-dev libcurl4-openssl-dev libical-dev libneon27-dev libsrtp0-dev libspandsp-dev libmyodbc mpg123 lame libav-tools 1>/dev/null

# mpg123 lame ffmpeg

# add asterisk user
RUN groupadd -r $ASTERISKUSER \
  && useradd -r -g $ASTERISKUSER $ASTERISKUSER \
  && mkdir /var/lib/asterisk \
  && chown $ASTERISKUSER:$ASTERISKUSER /var/lib/asterisk \
  && usermod --home /var/lib/asterisk $ASTERISKUSER \
  && rm -rf /var/lib/apt/lists/* \
#  && curl -o /usr/local/bin/gosu -SL 'https://github.com/tianon/gosu/releases/download/1.1/gosu' \
#  && chmod +x /usr/local/bin/gosu \
  && apt-get purge -y \

  && pear install Console_Getopt

#Install Pear DB
#  && pear uninstall db 1>/dev/null \
#  && pear install db-1.7.14 1>/dev/null

# Install Dependencies for Google Voice (if required)
# You may skip this section if you do not require Google Voice support.
# Install iksemel
WORKDIR /temp/src/
RUN curl -sf -o /tmp/iksemel-1.4.tar.gz https://iksemel.googlecode.com/files/iksemel-1.4.tar.gz \
  && mkdir /tmp/iksemel \
  && tar -xzf /tmp/iksemel-1.4.tar.gz -C /tmp/iksemel \
  && cd /tmp/iksemel/iksemel-* \
  && ./configure \
  && make \
  && make install

#build pj project
WORKDIR /temp/src/
RUN git clone https://github.com/asterisk/pjproject.git 1>/dev/null
RUN cd /temp/src/pjproject \
  && CFLAGS='-DPJ_HAS_IPV6=1' 1>/dev/null \
  && ./configure --enable-shared --disable-sound --disable-resample --disable-video --disable-opencore-amr 1>/dev/null \
  && make dep 1>/dev/null \
  && make 1>/dev/null \
  && make install 1>/dev/null

#build jansson
WORKDIR /temp/src/
RUN git clone https://github.com/akheron/jansson.git 1>/dev/null 
RUN cd /temp/src/jansson \
  && autoreconf -i 1>/dev/null \
  && ./configure 1>/dev/null \
  && make 1>/dev/null \
  && make install 1>/dev/null
  
# Download asterisk.
# Currently Certified Asterisk 13.1.
WORKDIR /temp/src/
RUN curl -sf -o /tmp/asterisk.tar.gz -L http://downloads.asterisk.org/pub/telephony/certified-asterisk/asterisk-certified-13.1-current.tar.gz 1>/dev/null \

# gunzip asterisk
  && mkdir /tmp/asterisk \
  && tar -xzf /tmp/asterisk.tar.gz -C /tmp/asterisk --strip-components=1 1>/dev/null

  WORKDIR /tmp/asterisk
# make asterisk.
# ENV rebuild_date 2015-01-29
RUN mkdir /etc/asterisk \
# Configure
  && contrib/scripts/install_prereq install 1> /dev/null \
  && ./configure --with-ssl=/opt/local --with-crypto=/opt/local 1> /dev/null \
# Remove the native build option
  && make menuselect.makeopts 1>/dev/null \
#  && sed -i "s/BUILD_NATIVE//" menuselect.makeopts 1>/dev/null \
  && menuselect/menuselect --disable BUILD_NATIVE  --enable CORE-SOUNDS-EN-WAV --enable CORE-SOUNDS-EN-SLN16 --enable MOH-OPSOUND-WAV --enable MOH-OPSOUND-SLN16 menuselect.makeopts 1>/dev/null \
# Continue with a standard make.
  && make 1> /dev/null \
  && make install 1> /dev/null \
  && make config 1>/dev/null \
  && ldconfig \
  && update-rc.d -f asterisk remove

# Asterisk Sounds
RUN cd /var/lib/asterisk/sounds \
  && curl -sf -o /var/lib/asterisk/sounds/asterisk-core-sounds-en-wav-current.tar.gz http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-wav-current.tar.gz 1>/dev/null \
  && curl -sf -o /var/lib/asterisk/sounds/asterisk-extra-sounds-en-wav-current.tar.gz http://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-wav-current.tar.gz 1>/dev/null \
  && tar xfz asterisk-core-sounds-en-wav-current.tar.gz 1>/dev/null \
  && rm -f asterisk-core-sounds-en-wav-current.tar.gz 1>/dev/null \
  && tar xfz asterisk-extra-sounds-en-wav-current.tar.gz 1>/dev/null \
  && rm -f asterisk-extra-sounds-en-wav-current.tar.gz 1>/dev/null \
  && curl -sf -o /var/lib/asterisk/sounds/asterisk-core-sounds-en-g722-current.tar.gz http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-g722-current.tar.gz 1>/dev/null \
  && curl -sf -o /var/lib/asterisk/sounds/asterisk-extra-sounds-en-g722-current.tar.gz http://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-g722-current.tar.gz 1>/dev/null \
  && tar xfz asterisk-core-sounds-en-g722-current.tar.gz 1>/dev/null \
  && rm -f asterisk-core-sounds-en-g722-current.tar.gz 1>/dev/null \
  && tar xfz asterisk-extra-sounds-en-g722-current.tar.gz 1>/dev/null \
  && rm -f asterisk-extra-sounds-en-g722-current.tar.gz 1>/dev/null

  COPY conf/asterisk.conf /etc/asterisk/asterisk.conf
  
RUN chown $ASRERISKUSER. /var/run/asterisk \
  && chown -R $ASTERISKUSER. /etc/asterisk \
  && chown -R $ASTERISKUSER. /var/lib/asterisk \
  && chown -R $ASTERISKUSER. /var/www/ \
  && chown -R $ASTERISKUSER. /var/www/* \
  && chown -R $ASTERISKUSER. /var/log/asterisk \
  && chown -R $ASTERISKUSER. /var/spool/asterisk \
  && chown -R $ASTERISKUSER. /var/run/asterisk \
  && chown -R $ASTERISKUSER. /var/lib/asterisk \
  && chown $ASTERISKUSER:$ASTERISKUSER /etc/freepbxbackup \
  && rm -rf /var/www/html

  RUN echo " \n\
[MySQL] \n\
Description = ODBC for MySQL \n\
Driver = /usr/lib/x86_64-linux-gnu/odbc/libmyodbc.so \n\
Setup = /usr/lib/x86_64-linux-gnu/odbc/libodbcmyS.so \n\
FileUsage = 1 \n\
\n\
" >> /etc/odbcinst.ini

RUN echo " \n\
[MySQL-asteriskcdrdb] \n\
Description=MySQL connection to 'asteriskcdrdb' database \n\
driver=MySQL \n\
server=localhost \n\
database=asteriskcdrdb \n\
Port=3306 \n\
Socket=/var/run/mysqld/mysqld.sock \n\
option=3 \n\
 \n\  
" >> /etc/odbc.ini

#mod to apache
#Setup mysql
RUN sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php5/apache2/php.ini \
  && cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig \
  && sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf \
  && sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
  # RUN ed -s /etc/apache2/apache2.conf  <<< $'/Options Indexes FollowSymLinks/+1s/AllowOverride None/AllowOverride ALL/g\nw'

RUN service apache2 restart 1>/dev/null \
  && /etc/init.d/mysql start 1>/dev/null \
  && mysqladmin -u root create asterisk \
  && mysqladmin -u root create asteriskcdrdb \
  && mysql -u root -e "GRANT ALL PRIVILEGES ON asterisk.* TO $ASTERISKUSER@localhost IDENTIFIED BY '$ASTERISK_DB_PW';" \
  && mysql -u root -e "GRANT ALL PRIVILEGES ON asteriskcdrdb.* TO $ASTERISKUSER@localhost IDENTIFIED BY '$ASTERISK_DB_PW';" \
  && mysql -u root -e "flush privileges;"

WORKDIR /tmp
RUN curl -sf -o /tmp/freepbx-13.0-latest.tgz http://mirror.freepbx.org/modules/packages/freepbx/freepbx-13.0-latest.tgz 1>/dev/null 2>/dev/null \
  && ln -s /var/lib/asterisk/moh /var/lib/asterisk/mohmp3 \
  && tar vxfz freepbx-13.0-latest.tgz 1>/dev/null

WORKDIR /tmp/freepbx 
RUN mkdir /var/www/html 1>/dev/null \
  && service apache2 restart 1>/dev/null \
  && /etc/init.d/mysql start 1>/dev/null \
  && /etc/init.d/asterisk start \
  && sleep 10 1>/dev/null \
  && ./install -n \
  && sed -i '/^$engineinfo = engine_getinfo();$/a $engineinfo['engine']="asterisk";\n$engineinfo['version']="13.1";' /var/lib/asterisk/bin/retrieve_conf \
  && chown -R $ASTERISKUSER. /var/lib/asterisk/bin/retrieve_conf \
  && fwconsole chown \
  && fwconsole reload \
  && asterisk -rx "core restart now" \
  && fwconsole chown \
  && fwconsole reload 1>/dev/null \
  && asterisk -rx "core restart now" \
  && fwconsole ma refreshsignatures 1>/dev/null \
  && fwconsole chown \
  && fwconsole reload \
  && asterisk -rx "core restart now"

#clean up
RUN find /temp -mindepth 1 -delete \
  && apt-get purge -y \
  && apt-get --yes autoremove \
  && apt-get clean all \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
   
CMD bash -C '/root/start.sh';'bash'
