#!/bin/bash

################################
##### Upgrade php packages #####
################################

# Clear the screen
clear

# Check whether script has been started as a root/sudo.
if [ $EUID -ne 0 ]
then
	printf "You have to run this script as a root/sudo.\n" &&
	exit
# Check whether a php version has been provided for us on the command line.
elif [ $# -eq 0 ]
then
	printf "Usage: $0 <php version to which the system should be upgraded to e.g. 70 for 7.0>\n" &&
	exit
else
	PHP_VER=$1
fi
# Check whether we run on CentOS 7
clear
if [ $(grep -c "CentOS Linux release 7" /etc/system-release) -ne 0 ]
then
        printf "\n##### PHP upgrade #####\n\n"
        sleep 2
else
        printf "\n##### Sorry, this script works only on CentOS 7 #####\n\n"
        exit 1
fi


# Install Webtatic repositories.
printf "\nInstalling Webtatic repositories...\n"
REPO_INSTALLED=''
if [ "$(yum repolist | grep -c "Webtatic Repository")" -eq 0 ]
then
	REPO_INSTALLED=0
	if ! rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm &> /dev/null
	then
		printf "Could not install Webtatic repositories\n"
		exit 1
	else
		printf "Success\n"
	fi
else
	printf "Already installed\n"
	REPO_INSTALLED=1
fi

# Check which packages are already installed and save the results.
if [ $REPO_INSTALLED -eq 0 ]
# Our repository with additional php packages is not installed. We have to assume that php has been installed from standard system repository.
then
	i=0
	# We have to assume a certain pattern in packages name to match and extract "raw" name of each package.
	for pkg in $(rpm -qa | grep -i php | sed -e 's/\.x86_64//' -e 's/[0-9]//g' -e 's/el//g' -e 's/\.//g' -e 's/\_//g' -e 's/\-//g' -e "s/php/php${PHP_VER}w-/" -e 's/-$//' -e 's/$/.x86_64/')
	do
		pkg_list[$i]=$pkg
		((i++))
	done
elif [ $REPO_INSTALLED -eq 1 ]
# Our repository with additional php packages is already installed. We have to assume that php has been installed from this repository.
then
	i=0
	# We have to assume a certain pattern in packages name to match and extract "raw" name of each package.
	for pkg in $(rpm -qa | grep -i php | sed -e 's/\.x86_64//' -e 's/[0-9]//g' -e 's/w\?//g' -e 's/\.//g' -e 's/\_//g' -e 's/\-//g' -e "s/php/php${PHP_VER}w-/" -e 's/-$//' -e 's/$/.x86_64/')
	do
		pkg_list[$i]=$pkg
		((i++))
	done
else
	printf "Oops. Something went wrong. Exiting..\n"
	exit 1
fi

# Remove old php packages
printf "\nRemoving old php packages...\n"
if ! rpm --nodeps -e $(rpm -qa | grep php.*\.x86_64) &> /dev/null
then
	printf "Could not remove old php packages"
	exit 1
else
	printf "Success\n"
fi

# Upgrade the php packages.
printf "\nInstalling new php packages...\n"
#if ! yum -y install php${PHP_VER}w php${PHP_VER}w-common php${PHP_VER}w-fpm php${PHP_VER}w-process php${PHP_VER}w-cli php${PHP_VER}w-mysql php${PHP_VER}w-xml php${PHP_VER}w-gd php${PHP_VER}w-pdo php${PHP_VER}w-odbc php-pear &> /dev/null
# We install all the previously saved packages.
if ! yum -y install ${pkg_list[*]} &> /dev/null
then
	printf "Could not install new php packages\n"
	exit 1
else
	printf "Success\n"
fi

# Prepare php-fpm service
printf "\nPreparing php-fpm service...\n"
if ! systemctl enable php-fpm.service &> /dev/null
then
	printf "Could not enable php-fpm.service\n"
	exit 1
else
	STATUS=1
fi
if ! systemctl start php-fpm.service &> /dev/null
then
	printf "Could not start php-fpm.service\n"
	exit 1
else
	((STATUS++))
fi
if [ $STATUS -eq 2 ]
then
	printf "Success\n"
fi

# Restart Apache (httpd)
printf "\nReloading HTTPD server...\n"
if ! systemctl reload httpd.service &> /dev/null
then
	printf "Could not restart Apache\n"
else
	printf "Success\n\n"
fi
