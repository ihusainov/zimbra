#!/bin/bash -x
##############################################
# This script searches for accounts with mail#
# attribute in AD and creates mailbox for it.#
# If email is exist in zimbra, but not in AD,#
# it set locked
# Синхронизация учёток из AD и генерация 
# почтовых подписей сотрудников.
# Скрипт был разработан изначально Михаилом Смирновым
# Maintainer: 
# Email: 
##############################################

# Variables:
# ldap link to domain controller
LDAPLINK='ldaps://dc.domain.local:636'
# BASE DN Where stored users
BASEDNALL='ou=Users,dc=domain,dc=local'
BASEDNUSR='ou=Users,dc=domain,dc=local'
BASEDNSVC='ou=Services,dc=domain,dc=local'
# User and password for LDAP Bind
BINDUSER="cn=zimbrasync,ou=Services,dc=domain,dc=local"
PWD='P@ssword'
# mail domain e.g. admin@domain.com
DOMAIN='domain.com'
# export locale for description attributes
export LC_ALL='ru_RU.UTF-8'
# Determining script dir
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

## Deleting all txt files from it
#rm -rf $SCRIPT_DIR/*.txt

## Check if LDAP is available
#if ! curl -k -m 5 $LDAPLINK; then
#exit 1
#fi

# Check AD for locked accounts and block mailbox (проверка на выключенные учётки в AD)
ldapsearch -LLL -w $PWD -x -D $BINDUSER -H $LDAPLINK -b "$BASEDNALL" "(&(objectClass=person)(mail=*$DOMAIN)(userAccountControl:1.2.840.113556.1.4.803:=2))" mail -S mail | grep -v "requesting"| grep "mail:" | awk '{print $2}' > $SCRIPT_DIR/ad_bl.txt
for i in $( cat $SCRIPT_DIR/ad_bl.txt)
do
/opt/zimbra/bin/zmprov ma $i zimbraAccountStatus locked
done
# Check if user mail existing in AD, existing on Zimbra either (Сравнение учёток в AD и Zimbra)
ldapsearch -w $PWD -x -D $BINDUSER -H $LDAPLINK -b "$BASEDNUSR" "(&(objectClass=person)(mail=*$DOMAIN))" mail -S mail | grep -v "requesting"| grep "mail:" | awk '{print $2}' > $SCRIPT_DIR/ad_mail.txt
ldapsearch -w $PWD -x -D $BINDUSER -H $LDAPLINK -b "$BASEDNSVC" "(&(objectClass=person)(mail=*$DOMAIN))" mail -S mail | grep -v "requesting"| grep "mail:" | awk '{print $2}' >> $SCRIPT_DIR/ad_mail.txt
sort -o $SCRIPT_DIR/ad_mail.txt $SCRIPT_DIR/ad_mail.txt
/opt/zimbra/bin/zmprov -l gaa $DOMAIN | tail -n +6 | sort > $SCRIPT_DIR/zm_mail.txt
comm -23 $SCRIPT_DIR/ad_mail.txt $SCRIPT_DIR/zm_mail.txt
# for every found mail in AD we create mail in zimbra (Создаём почтовые ящики для из AD в Zimbra)
for i in $(comm -23 $SCRIPT_DIR/ad_mail.txt $SCRIPT_DIR/zm_mail.txt)
do
/opt/zimbra/bin/zmprov ca $i ''
USERPRINCIPALNAME=$( ldapsearch -LLL -w $PWD -x -D $BINDUSER -o ldif-wrap=no -H $LDAPLINK -b $BASEDNUSR "(&(objectClass=person)(mail=$i))" userPrincipalName -S userPrincipalName | grep -v "requesting"| grep "userPrincipalName:" | awk '{print $2}' )
DISPLAYNAME=$( ldapsearch -LLL -w $PWD -x -D $BINDUSER -o ldif-wrap=no -H $LDAPLINK -b $BASEDNUSR "(&(objectClass=person)(mail=$i))" displayName -S displayName | grep -v "requesting"| grep "displayName:" | awk '{print $2}' | base64 --decode )
SN=$( ldapsearch -LLL -w $PWD -x -D $BINDUSER -H $LDAPLINK -o ldif-wrap=no -b $BASEDNUSR "(&(objectClass=person)(mail=$i))" sn -S sn | grep -v "requesting"| grep "sn:" | awk '{print $2}' | base64 --decode )
gn=$( ldapsearch -LLL -w $PWD -x -D $BINDUSER -H $LDAPLINK -o ldif-wrap=no -b $BASEDNUSR "(&(objectClass=person)(mail=$i))" givenName -S givenName | grep -v "requesting"| grep "givenName:" | awk '{print $2}' | base64 --decode )

# Hide in GAL (Скрыть учётки в GAL)
#/opt/zimbra/bin/zmprov ma $i ZimbraHideInGal TRUE zimbraAuthLdapExternalDn "$USERPRINCIPALNAME" displayName "$DISPLAYNAME" sn "$SN" gn "$gn"

# Add GAL folders to new mailbox (Добавить новым учёткам контакты)
/opt/zimbra/bin/zmmailbox -z -m $i createMountpoint /galsync galsync@domain.com /_zimbra

# Add folder Шаблоны for templates (Добавить каталог Шаблоны)
/opt/zimbra/bin/zmmailbox -z -m $i cf -c 9 /Шаблоны

# Get all signatures, create array and delete all signatures for create new corparate sign (Удалить все подписи у сотрудников в почте, что бы пересоздать в корпоративном стиле)
#GSIGN=$(/opt/zimbra/bin/zmprov gsig $i | grep zimbraSignatureId  | awk '{print $2}');
#for sign in ${GSIGN[@]}; do  delsign=$(/opt/zimbra/bin/zmprov dsig $i $sign 2>/dev/null); done

# Add signature (Создать подписи в почте по данным из AD)
#TITLE=$( ldapsearch -LLL -w $PWD -x -D $BINDUSER -H $LDAPLINK -o ldif-wrap=no -b $BASEDNUSR "(&(objectClass=person)(mail=$i))" title -S title | grep -v "requesting"| grep "title:" | awk '{print $2}' | base64 --decode )
#PHONE=$( ldapsearch -LLL -w $PWD -x -D $BINDUSER -H $LDAPLINK -o ldif-wrap=no -b $BASEDNUSR "(&(objectClass=person)(mail=$i))" telephoneNumber -S telephoneNumber | grep -v "requesting"| grep "telephoneNumber:" | awk '{print $2}' )
#DEPARTMENT=$( ldapsearch -LLL -w $PWD -x -D $BINDUSER -o ldif-wrap=no -H $LDAPLINK -b $BASEDNUSR "(&(objectClass=person)(mail=$i))" department -S department | grep -v "requesting"| grep "department:" | awk '{print $2}' | base64 --decode )
DESCRIPTION=$( ldapsearch -LLL -w $PWD -x -D "$BINDUSER" -o ldif-wrap=no -H $LDAPLINK -b "$BASEDNUSR" "(&(objectClass=person)(mail=$i))" description -S description | grep -v "requesting"| grep "description:" | awk '{print $2}' | base64 --decode )

OFFICE=$( ldapsearch -LLL -w $PWD -x -D "$BINDUSER" -o ldif-wrap=no -H $LDAPLINK -b "$BASEDNUSR" "(&(objectClass=person)(mail=$i))" physicalDeliveryOfficeName -S physicalDeliveryOfficeName | grep -v "requesting"| grep "physicalDeliveryOfficeName:" | awk '{print $2}')

# Create signature (Создание подписи на два разных офиса)
if [[ "$OFFICE" !=  "Izhevsk"  ]]; then
/opt/zimbra/bin/zmsoap -z -type account -m $i CreateSignatureRequest/signature @name="Корпоративная Москва" content="<html><div><span style=\"color: #1c1e3e; font-family: 'trebuchet ms' , sans-serif; font-size: 10pt;\">С уважением,</span></div><div><span style=\"font-family: 'trebuchet ms' , sans-serif; font-size: 12pt; color: #ff5959;\"><strong>$DISPLAYNAME</strong></span></div><div><span style=\"color: #898989; font-family: 'trebuchet ms' , sans-serif; font-size: 8pt;\">$DESCRIPTION</span></div><div><span style=\"color: #898989; font-family: 'trebuchet ms' , sans-serif; font-size: 8pt;\">Москва, ул. Мира, 1, офис 10</span></div><div><span style=\"color: #1c1e3e;\">Тел.<span style=\"font-size: 10pt;\"><strong>+7 (495) 123 45 67</strong></span></span></div><div><a href=\"https://www.your-site.com\" rel=\"noopener nofollow  noreferrer\" target=\"_blank\"><img src=\"https://www.your-site.com/images/logo.png\" width=\"233\" height=\"46\" /></a></div></html>" @type="text/html"
else
/opt/zimbra/bin/zmsoap -z -type account -m $i CreateSignatureRequest/signature @name="Корпоративная Ижевск" content="<html><div><span style=\"color: #1c1e3e; font-family: 'trebuchet ms' , sans-serif; font-size: 10pt;\">С уважением,</span></div><div><span style=\"font-family: 'trebuchet ms' , sans-serif; font-size: 12pt; color: #ff5959;\"><strong>$DISPLAYNAME</strong></span></div><div><span style=\"color: #898989; font-family: 'trebuchet ms' , sans-serif; font-size: 8pt;\">$DESCRIPTION</span></div><div><span style=\"color: #898989; font-family: 'trebuchet ms' , sans-serif; font-size: 8pt;\">426077, г. Ижевск, ул. Мира, 1, офис 10</span></div><div><span style=\"color: #1c1e3e;\">Тел.<span style=\"font-size: 10pt;\"><strong>+7 (3412) 10 11 12</strong></span></span></div><div><a href=\"https://www.your-site.com\" rel=\"noopener nofollow  noreferrer\" target=\"_blank\"><img src=\"https://www.your-site.com/images/logo.png\" width=\"233\" height=\"46\" /></a></div></html>" @type="text/html"
fi

# Get signature ID (Получаем ID подписи)
SIGNID=$( /opt/zimbra/bin/zmprov ga $i zimbraSignatureId | sed -n '2p' | cut -d : -f 2 | sed 's/^\ //g')

# Make signtaure ID main (Выбираем новую подпись как основную)
/opt/zimbra/bin/zmprov ma $i zimbraPrefMailSignatureEnabled TRUE
/opt/zimbra/bin/zmprov ma $i zimbraPrefDefaultSignatureId $SIGNID
#/opt/zimbra/bin/zmprov ma $i zimbraPrefForwardReplySignatureId $SIGNID
# Copy Welcome mail to new account (it is stored in eml format)
#/opt/zimbra/bin/zmmailbox -z -m $i addmessage -F u "/Inbox" "/opt/zimbra/scripts/syncmailbox/email"
done
