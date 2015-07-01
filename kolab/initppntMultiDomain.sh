#!/bin/bash

SCRIPTSPATH=`dirname ${BASH_SOURCE[0]}`
source $SCRIPTSPATH/lib.sh

DetermineOS
InstallWgetAndPatch
DeterminePythonPath

#####################################################################################
# ldap entries not needed anymore
#####################################################################################
cp -f /etc/imapd.conf /etc/imapd.conf.beforeMultiDomain
#sed -i "/^ldap/d" /etc/imapd.conf


echo "ldap_domain_base_dn: cn=kolab,cn=config
ldap_domain_filter: (&(objectclass=domainrelatedobject)(associateddomain=%s))
ldap_domain_name_attribute: associatedDomain
ldap_domain_scope: sub
ldap_domain_result_attribute: inetdomainbasedn" >> /etc/imapd.conf

service cyrus-imapd restart

#####################################################################################
#Update Postfix LDAP Lookup Tables
# support subdomains too, search_base = dc=%3,dc=%2,dc=%1
# see https://lists.kolab.org/pipermail/users/2013-January/014233.html
#####################################################################################

cp -Rf /etc/postfix/ldap /etc/postfix/ldap.beforeMultiDomain
rm -f /etc/postfix/ldap/*_3.cf
for f in `find /etc/postfix/ldap/ -type f -name "*.cf"`;
do
  f3=${f/.cf/_3.cf}
  cp $f $f3
  if [[ "/etc/postfix/ldap/mydestination.cf" == "$f" ]]
  then
    sed -r -i -e 's/^query_filter = .*$/query_filter = (\&(associateddomain=%s)(associateddomain=*.*.*))/g' $f3
  else
    sed -r -i -e 's/^search_base = .*$/search_base = dc=%2,dc=%1/g' $f
    sed -r -i -e 's/^search_base = .*$/search_base = dc=%3,dc=%2,dc=%1/g' $f3
    sed -r -i -e 's#^domain = .*$#domain = ldap:/etc/postfix/ldap/mydestination_3.cf#g' $f3
  fi
done

cp -f /etc/postfix/main.cf /etc/postfix/main.cf.beforeMultiDomain
sed -r -i -e 's#transport_maps.cf#transport_maps.cf, ldap:/etc/postfix/ldap/transport_maps_3.cf#g' /etc/postfix/main.cf
sed -i -e 's#virtual_alias_maps.cf#virtual_alias_maps.cf, ldap:/etc/postfix/ldap/virtual_alias_maps_3.cf, ldap:/etc/postfix/ldap/mailenabled_distgroups_3.cf, ldap:/etc/postfix/ldap/mailenabled_dynamic_distgroups_3.cf, ldap:/etc/postfix/ldap/virtual_alias_maps_sharedfolders_3.cf#' /etc/postfix/main.cf
sed -r -i -e 's#local_recipient_maps.cf#local_recipient_maps.cf, ldap:/etc/postfix/ldap/local_recipient_maps_3.cf#g' /etc/postfix/main.cf

# create a file that can be manipulated manually to allow aliases across domains;
# eg. user mymailbox@test.de gets emails that are sent to myalias@test2.de;
# You can also enable aliases for domains here to receive emails properly, eg. @test2.de @test.de;
# You need to run postmap on the file after manually changing it!
postfix_virtual_file=/etc/postfix/virtual_alias_maps_manual.cf
if [ ! -f $postfix_virtual_file ]
then
    echo "# you can manually set aliases, across domains. " > $postfix_virtual_file
    echo "# for example: " >> $postfix_virtual_file
    echo "#myalias@test2.de mymailbox@test.de" >> $postfix_virtual_file
    echo "#@test4.de @test.de" >> $postfix_virtual_file
    echo "#@pokorra.it timotheus.pokorra@test1.de" >> $postfix_virtual_file
fi
sed -i -e "s#virtual_alias_maps.cf#virtual_alias_maps.cf, hash:$postfix_virtual_file#" /etc/postfix/main.cf
postmap $postfix_virtual_file

service postfix restart


#####################################################################################
#kolab_auth conf roundcube: http://kodira.de/2014/11/kolab-3-3-multi-domain-setup-centos-7/
# Fix Global Address Book in Multi Domain environment
#####################################################################################
cp -a /etc/roundcubemail/password.inc.php /etc/roundcubemail/password.inc.php.beforeMultiDomain
cp -a /etc/roundcubemail/config.inc.php /etc/roundcubemail/config.inc.php.beforeMultiDomain
cp -a /etc/roundcubemail/calendar.inc.php /etc/roundcubemail/calendar.inc.php.beforeMultiDomain
cp -a /etc/roundcubemail/kolab_auth.inc.php /etc/roundcubemail/kolab_auth.inc.php.beforeMultiDomain
cp -a /etc/roundcubemail/kolab_addressbook.inc.php /etc/roundcubemail/kolab_addressbook.inc.php.beforeMultiDomain

sed -i "s/'ou=People,.*'/'ou=People,%dc'/; \
	s/'ou=Groups,.*'/'ou=Groups,%dc'/; \
	s/'ou=Resources,.*'/'ou=Resources,%dc'/;" \
/etc/roundcubemail/password.inc.php \
/etc/roundcubemail/calendar.inc.php \
/etc/roundcubemail/config.inc.php \
/etc/roundcubemail/kolab_auth.inc.php \
/etc/roundcubemail/kolab_addressbook.inc.php


sed -r -i -e "s#=> 389,#=> 389,\n        'domain_base_dn'            => 'cn=kolab,cn=config',\n        'domain_filter'             => '(\&(objectclass=domainrelatedobject)(associateddomain=%s))',\n        'domain_name_attr'          => 'associateddomain',#g" /etc/roundcubemail/kolab_auth.inc.php


#####################################################################################
#fix a bug https://issues.kolab.org/show_bug.cgi?id=2673 
#so that changing the password works in Roundcube for multiple domains
#####################################################################################
sed -r -i -e "s#config\['password_driver'\] = 'ldap'#config['password_driver'] = 'ldap_simple'#g" /etc/roundcubemail/password.inc.php

#####################################################################################
#enable freebusy for all domains
#####################################################################################
sed -r -i -e "s#base_dn = .*#base_dn = %dc#g" /usr/share/kolab-freebusy/config/config.ini

#####################################################################################
#fix a bug for freebusy (see https://issues.kolab.org/show_bug.cgi?id=2524, missing quotes)
#####################################################################################
sed -r -i -e 's#bind_dn = (.*)#bind_dn = "\1"#g' /usr/share/kolab-freebusy/config/config.ini

#####################################################################################
#auto created folders: do not use an extra partition for the archive folder. 
#see https://issues.kolab.org/show_bug.cgi?id=3210
#####################################################################################
sed -r -i -e "s#'quota': 0,##g" /etc/kolab/kolab.conf
sed -r -i -e "s#'partition': 'archive'##g" /etc/kolab/kolab.conf

#####################################################################################
#set primary_mail value in kolab section, so that new users in a different domain will have a proper primary email address, even without changing kolab.conf for each domain
#####################################################################################
sed -r -i -e "s/primary_mail = .*/primary_mail = %(givenname)s.%(surname)s@%(domain)s/g" /etc/kolab/kolab.conf

#####################################################################################
#make sure that for alias domains, the emails will actually arrive, by checking the postfix file
#see https://issues.kolab.org/show_bug.cgi?id=2658
#####################################################################################
sed -r -i -e "s#\[kolab\]#[kolab]\npostfix_virtual_file = $postfix_virtual_file#g" /etc/kolab/kolab.conf

#####################################################################################
#avoid a couple of warnings by setting default values
#####################################################################################
sed -r -i -e "s#\[ldap\]#[ldap]\nmodifytimestamp_format = %%Y%%m%%d%%H%%M%%SZ#g" /etc/kolab/kolab.conf
sed -r -i -e "s/\[cyrus-imap\]/[imap]\nvirtual_domains = userid\n\n[cyrus-imap]/g" /etc/kolab/kolab.conf

#####################################################################################
# install memcache to improve WAP login speed if many domains are present
#####################################################################################
if [[ $OS == CentOS* || $OS == Fedora* ]]
then
  yum -y install php-pecl-memcache memcached
  systemctl start memcached
  systemctl enable memcached
elif [[ $OS == Debian* || $OS == Ubuntu* ]]
then
  apt-get -y install php5-memcache memcached
  service memcached restart
fi

sed -r -i -e "s#\[kolab_wap\]#[kolab_wap]\nmemcache_hosts = 127.0.0.1:11211\nmemcache_pconnect = true#g" /etc/kolab/kolab.conf

#####################################################################################
# apply a couple of patches, see related kolab bugzilla number in filename, eg. https://issues.kolab.org/show_bug.cgi?id=1869
#####################################################################################

if [ ! -d patches ]
then
  mkdir -p patches
  echo Downloading patch validateAliasDomainPostfixVirtualFileBug2658.patch
  wget $patchesurl/validateAliasDomainPostfixVirtualFileBug2658.patch -O patches/validateAliasDomainPostfixVirtualFileBug2658.patch
fi

patch -p1 -i `pwd`/patches/validateAliasDomainPostfixVirtualFileBug2658.patch -d /usr/share/kolab-webadmin || exit -1

service kolab-saslauthd restart

# shorter sync time
sed -i 's/sync_interval = 300/sync_interval = 30/ ; s/domain_sync_interval = 600/domain_sync_interval = 60/' /etc/kolab/kolab.conf

# remove empty Theme
[ -d /usr/share/roundcubemail/skins/kolab ] && rmdir /usr/share/roundcubemail/skins/kolab

KolabService restart
