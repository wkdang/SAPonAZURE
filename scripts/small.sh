#!/bin/bash
set -e

Uri=$1
HANAUSR=$2
HANAPWD=$3
HANASID=$4
HANANUMBER=$5
HANAVERS=$6
OS=$7
vmSize=$8

echo $1 >> /tmp/parameter.txt
echo $2 >> /tmp/parameter.txt
echo $3 >> /tmp/parameter.txt
echo $4 >> /tmp/parameter.txt
echo $5 >> /tmp/parameter.txt
echo $6 >> /tmp/parameter.txt
echo $7 >> /tmp/parameter.txt

sed -i -e "s/Defaults    requiretty/#Defaults    requiretty/g" /etc/sudoers

if [ "$7" == "RHEL" ]; then
	echo "Start REHL prerequisite" >> /tmp/parameter.txt
	yum -y groupinstall base
	yum -y install gtk2 libicu xulrunner sudo tcsh libssh2 expect cairo graphviz iptraf-ng 
	yum -y install compat-sap-c++-6
	sudo mkdir -p /hana/{data,log,shared,backup}
	sudo mkdir /usr/sap
	sudo mkdir -p /hana/data/{sapbitslocal,sapbits}
	sudo chmod 777 /hana/data/sapbits
	yum -y install tuned-profiles-sap-hana
	systemctl start tuned
	systemctl enable tuned
	tuned-adm profile sap-hana
	setenforce 0
	#sed -i 's/\(SELINUX=enforcing\|SELINUX=permissive\)/SELINUX=disabled/g' \ > /etc/selinux/config
	echo "start SELINUX" >> /tmp/parameter.txt
	sed -i -e "s/\(SELINUX=enforcing\|SELINUX=permissive\)/SELINUX=disabled/g" /etc/selinux/config
	echo "end SELINUX" >> /tmp/parameter.txt
	echo "kernel.numa_balancing = 0" > /etc/sysctl.d/sap_hana.conf
	ln -s /usr/lib64/libssl.so.1.0.1e /usr/lib64/libssl.so.1.0.1
	ln -s /usr/lib64/libcrypto.so.0.9.8e /usr/lib64/libcrypto.so.0.9.8
	ln -s /usr/lib64/libcrypto.so.1.0.1e /usr/lib64/libcrypto.so.1.0.1
	echo always > /sys/kernel/mm/transparent_hugepage/enabled
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
	echo "start Grub" >> /tmp/parameter.txt
	sedcmd="s/rootdelay=300/rootdelay=300 transparent_hugepage=never intel_idle.max_cstate=1 processor.max_cstate=1/g"
	sudo sed -i -e "$sedcmd" /etc/default/grub
	echo "start Grub2" >> /tmp/parameter.txt
	sudo grub2-mkconfig -o /boot/grub2/grub.cfg
	echo "End Grub" >> /tmp/parameter.txt
    echo "@sapsys         soft    nproc   unlimited" >> /etc/security/limits.d/99-sapsys.conf
	systemctl disable abrtd
	systemctl disable abrt-ccpp
	systemctl stop abrtd
	systemctl stop abrt-ccpp
	systemctl stop kdump.service
	systemctl disable kdump.service
	systemctl stop firewalld
	systemctl disable firewalld
	sudo mkdir -p /sources
	yum -y install cifs-utils
	# Install Unrar  
	echo "start RAR" >> /tmp/parameter.txt
	wget http://www.rarlab.com/rar/unrar-5.0-RHEL5x64.tar.gz 
	tar -zxvf unrar-5.0-RHEL5x64.tar.gz 
	cp unrar /usr/bin/ 
	chmod 755 /usr/bin/unrar 
	echo "End RAR" >> /tmp/parameter.txt
	echo "End REHL prerequisite" >> /tmp/parameter.txt
	
else
#install hana prereqs
	sudo zypper install -y glibc-2.22-51.6
	sudo zypper install -y systemd-228-142.1
	sudo zypper install -y unrar
	sudo zypper install -y sapconf
	sudo zypper install -y saptune
	sudo mkdir /etc/systemd/login.conf.d
	sudo mkdir -p /hana/{data,log,shared,backup}
	sudo mkdir /usr/sap
	sudo mkdir -p /hana/data/{sapbitslocal,sapbits}
	sudo chmod 777 /hana/data/sapbits


# Install .NET Core and AzCopy
	sudo zypper install -y libunwind
	sudo zypper install -y libicu
	curl -sSL -o dotnet.tar.gz https://go.microsoft.com/fwlink/?linkid=848824
	sudo mkdir -p /opt/dotnet && sudo tar zxf dotnet.tar.gz -C /opt/dotnet
	sudo ln -s /opt/dotnet/dotnet /usr/bin

	wget -O azcopy.tar.gz https://aka.ms/downloadazcopyprlinux
	tar -xf azcopy.tar.gz
	sudo ./install.sh

	sudo zypper se -t pattern
	sudo zypper --non-interactive in -t pattern sap-hana 
fi


# step2
echo $Uri >> /tmp/url.txt

cp -f /etc/waagent.conf /etc/waagent.conf.orig
sedcmd="s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g"
sedcmd2="s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=163840/g"
cat /etc/waagent.conf | sed $sedcmd | sed $sedcmd2 > /etc/waagent.conf.new
cp -f /etc/waagent.conf.new /etc/waagent.conf
#sed -i -e "s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g" -e "s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=163840/g" /etc/waagent.conf


number="$(lsscsi [*] 0 0 4| cut -c2)"

echo "logicalvols start" >> /tmp/parameter.txt
  hanavg1lun="$(lsscsi $number 0 0 3 | grep -o '.\{9\}$')"
  hanavg2lun="$(lsscsi $number 0 0 4 | grep -o '.\{9\}$')"
  pvcreate $hanavg1lun $hanavg2lun
  vgcreate hanavg $hanavg1lun $hanavg2lun
  lvcreate -l 80%FREE -n datalv hanavg
  lvcreate -l 20%VG -n loglv hanavg
  mkfs.xfs /dev/hanavg/datalv
  mkfs.xfs /dev/hanavg/loglv
echo "logicalvols end" >> /tmp/parameter.txt


echo "logicalvols2 start" >> /tmp/parameter.txt
  sharedvglun="$(lsscsi $number 0 0 0 | grep -o '.\{9\}$')"
  usrsapvglun="$(lsscsi $number 0 0 1 | grep -o '.\{9\}$')"
  backupvglun="$(lsscsi $number 0 0 2 | grep -o '.\{9\}$')"
  pvcreate $backupvglun $sharedvglun $usrsapvglun
  vgcreate backupvg $backupvglun
  vgcreate sharedvg $sharedvglun
  vgcreate usrsapvg $usrsapvglun 
  lvcreate -l 100%FREE -n sharedlv sharedvg 
  lvcreate -l 100%FREE -n backuplv backupvg 
  lvcreate -l 100%FREE -n usrsaplv usrsapvg 
  mkfs -t xfs /dev/sharedvg/sharedlv 
  mkfs -t xfs /dev/backupvg/backuplv 
  mkfs -t xfs /dev/usrsapvg/usrsaplv
echo "logicalvols2 end" >> /tmp/parameter.txt


echo "mounthanashared start" >> /tmp/parameter.txt

mount -t xfs /dev/sharedvg/sharedlv /hana/shared
mount -t xfs /dev/backupvg/backuplv /hana/backup 
mount -t xfs /dev/usrsapvg/usrsaplv /usr/sap
mount -t xfs /dev/hanavg/datalv /hana/data
mount -t xfs /dev/hanavg/loglv /hana/log 
mount -t cifs //saphanakit.file.core.windows.net/sapinstall/HANA1SP12/SAP_HANA_1.0_DSP_122.13 /hana/data/sapbitslocal/ -o vers=3.0,username=saphanakit,password=UVLxDAZmw937RVDNQBF+OetwlLYwitsbQPHH2tnEiTut/y+hRgx0YkBzUtEGI99mhDsT/KxgSxJ/h6HUu6JHoQ==,dir_mode=0777,file_mode=0777,sec=ntlmssp
mkdir -p /hana/data/sapbits
echo "mounthanashared end" >> /tmp/parameter.txt

echo "write to fstab start" >> /tmp/parameter.txt
echo "/dev/mapper/hanavg-datalv /hana/data xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/hanavg-loglv /hana/log xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/sharedvg-sharedlv /hana/shared xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/backupvg-backuplv /hana/backup xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/usrsapvg-usrsaplv /usr/sap xfs defaults 0 0" >> /etc/fstab
echo "//saphanakit.file.core.windows.net/sapinstall/HANA1SP12/SAP_HANA_1.0_DSP_122.13 /hana/data/sapbitslocal/ cifs vers=3.0,dir_mode=0777,file_mode=0777,username=saphanakit,password=UVLxDAZmw937RVDNQBF+OetwlLYwitsbQPHH2tnEiTut/y+hRgx0YkBzUtEGI99mhDsT/KxgSxJ/h6HUu6JHoQ==">> /etc/fstab
echo "write to fstab end" >> /tmp/parameter.txt

if [ ! -d "/hana/data/sapbits" ]; then
  mkdir -p "/hana/data/sapbits"
fi

if [ "$6" == "2.0" ]; then
  cd /hana/data/sapbits
  echo "hana 2.0 download start" >> /tmp/parameter.txt
  /usr/bin/wget --quiet $Uri/SapBits/md5sums
  /usr/bin/wget --quiet $Uri/SapBits/51052325_part1.exe
  /usr/bin/wget --quiet $Uri/SapBits/51052325_part2.rar
  /usr/bin/wget --quiet $Uri/SapBits/51052325_part3.rar
  /usr/bin/wget --quiet $Uri/SapBits/51052325_part4.rar
  /usr/bin/wget --quiet "https://raw.githubusercontent.com/wkdang/SAPonAzure/master/hdbinst1.cfg"
  echo "hana 2.0 download end" >> /tmp/parameter.txt

  date >> /tmp/testdate
  cd /hana/data/sapbits

  echo "hana 2.0 unrar start" >> /tmp/parameter.txt
  cd /hana/data/sapbits
  unrar x 51052325_part1.exe
  echo "hana 2.0 unrar end" >> /tmp/parameter.txt

  echo "hana 2.0 prepare start" >> /tmp/parameter.txt
  cd /hana/data/sapbits

  cd /hana/data/sapbits
  myhost=`hostname`
  sedcmd="s/REPLACE-WITH-HOSTNAME/$myhost/g"
  sedcmd2="s/\/hana\/shared\/sapbits\/51052325/\/hana\/data\/sapbits\/51052325/g"
  sedcmd3="s/root_user=root/root_user=$HANAUSR/g"
  #sedcmd4="s/root_password=AweS0me@PW/root_password=$HANAPWD/g"
  sedcmd4="s/password=AweS0me@PW/password=$HANAPWD/g"
  sedcmd5="s/sid=H10/sid=$HANASID/g"
  sedcmd6="s/number=00/number=$HANANUMBER/g"
  #cat hdbinst1.cfg | sed $sedcmd | sed $sedcmd2 | sed $sedcmd3 | sed $sedcmd4 | sed $sedcmd5 | sed $sedcmd6 > hdbinst-local.cfg
  cp -f /hana/data/sapbits/hdbinst1.cfg /hana/data/sapbits/hdbinst-local.cfg
  sed -i -e $sedcmd -e $sedcmd2 -e $sedcmd3 -e $sedcmd4 -e $sedcmd5 -e $sedcmd6 /hana/data/sapbits/hdbinst-local.cfg
  echo "hana 2.0 prepare end" >> /tmp/parameter.txt

  echo "install hana 2.0 start" >> /tmp/parameter.txt
  cd /hana/data/sapbits/51052325/DATA_UNITS/HDB_LCM_LINUX_X86_64
  /hana/data/sapbits/51052325/DATA_UNITS/HDB_LCM_LINUX_X86_64/hdblcm -b --configfile /hana/data/sapbits/hdbinst-local.cfg
  echo "Log file written to '/var/tmp/hdb_H10_hdblcm_install_xxx/hdblcm.log' on host 'saphanaarm'." >> /tmp/parameter.txt
  echo "install hana 2.0 end" >> /tmp/parameter.txt

else
  cd /hana/data/sapbits
echo "hana 1.0 download start" >> /tmp/parameter.txt
/usr/bin/wget --quiet $Uri/SapBits/md5sums
/usr/bin/wget --quiet $Uri/SapBits/51052383_part1.exe
/usr/bin/wget --quiet $Uri/SapBits/51052383_part2.rar
/usr/bin/wget --quiet $Uri/SapBits/51052383_part3.rar
/usr/bin/wget --quiet "https://raw.githubusercontent.com/wkdang/SAPonAzure/master/hdbinst.cfg"
echo "hana 1.0 download end" >> /tmp/parameter.txt

date >> /tmp/testdate
cd /hana/data/sapbits

echo "hana 1.0 unrar start" >> /tmp/parameter.txt
cd /hana/data/sapbits
unrar x 51052383_part1.exe
echo "hana 1.0 unrar end" >> /tmp/parameter.txt

echo "hana 1.0 prepare start" >> /tmp/parameter.txt
cd /hana/data/sapbits

cd /hana/data/sapbits
myhost=`hostname`
sedcmd="s/REPLACE-WITH-HOSTNAME/$myhost/g"
sedcmd2="s/\/hana\/shared\/sapbits\/51052325/\/hana\/data\/sapbits\/51052383/g"
sedcmd3="s/root_user=root/root_user=$HANAUSR/g"
sedcmd4="s/password=AweS0me@PW/password=$HANAPWD/g"
sedcmd5="s/sid=H10/sid=$HANASID/g"
sedcmd6="s/number=00/number=$HANANUMBER/g"
#cat hdbinst.cfg | sed $sedcmd | sed $sedcmd2 | sed $sedcmd3 | sed $sedcmd4 | sed $sedcmd5 | sed $sedcmd6 > hdbinst-local.cfg
cp -f /hana/data/sapbits/hdbinst.cfg /hana/data/sapbits/hdbinst-local.cfg
sed -i -e $sedcmd -e $sedcmd2 -e $sedcmd3 -e $sedcmd4 -e $sedcmd5 -e $sedcmd6 /hana/data/sapbits/hdbinst-local.cfg
echo "hana 1.0 prepare end" >> /tmp/parameter.txt

echo "install hana 1.0 start" >> /tmp/parameter.txt
cd /hana/data/sapbits/51052383/DATA_UNITS/HDB_LCM_LINUX_X86_64
/hana/data/sapbits/51052383/DATA_UNITS/HDB_LCM_LINUX_X86_64/hdblcm -b --configfile /hana/data/sapbits/hdbinst-local.cfg
echo "Log file written to '/var/tmp/hdb_H10_hdblcm_install_xxx/hdblcm.log' on host 'saphanaarm'." >> /tmp/parameter.txt
echo "install hana 1.0 end" >> /tmp/parameter.txt


fi
shutdown -r 1
