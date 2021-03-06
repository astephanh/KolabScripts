#!/bin/bash
# this script will remove Kolab, and DELETE all YOUR data!!!
# it will reinstall Kolab, from Kolab 3.4 Updates and Kolab Development and the nightly builds
# you can optionally install the patches from TBits, see bottom of script

SCRIPTSPATH=`dirname ${BASH_SOURCE[0]}`
source $SCRIPTSPATH/lib.sh

DetermineOS

if [ -z $OS ]
then
  echo Your Operating System is currently not supported
  exit 1
elif [[ $OS == CentOS_6 ]]
then
  ./reinstallCentOS.sh $OS
elif [[ $OS == CentOS_* ]]
then
  ./reinstallCentOS7.sh $OS
elif [[ $OS == Fedora_* ]]
then
  ./reinstallCentOS7.sh $OS
elif [[ $OS == Ubuntu_* ]]
then
  ./reinstallDebianUbuntu.sh $OS
elif [[ $OS == Debian_* ]]
then
  ./reinstallDebianUbuntu.sh $OS
fi

if [ $? -ne 0 ]
then
  exit 1
fi

echo "for the TBits patches for multi domain and ISP setup, please run "
echo "   ./initSetupKolabPatches.sh"
echo "   setup-kolab"
ZONE="Europe/Brussels"
if [ -f /etc/sysconfig/clock ]
then
  # CentOS
  . /etc/sysconfig/clock
fi
if [ -f /etc/timezone ]
then
    # Debian
    ZONE=`cat /etc/timezone`
fi
echo "    or unattended: setup-kolab --default --mysqlserver=new --timezone=$ZONE --directory-manager-pwd=test"
h=`hostname`
echo "   ./initHttpTunnel.sh"
#echo "   ./initIMAPProxy.sh"
echo "   ./initSSL.sh "${h:`expr index $h .`}
#echo "   ./initRoundcubePlugins.sh"
echo "   ./initMultiDomain.sh"
echo "   ./initMailForward.sh"
echo "   ./initMailCatchall.sh"
echo "   ./initTBitsISP.sh"
echo ""
echo "  also have a look at initTBitsCustomizationsDE.sh, perhaps there are some useful customizations for you as well"
echo "  for running the pySeleniumTests, run initSleepTimesForTest.sh to increase the speed of domain and email account creation"
