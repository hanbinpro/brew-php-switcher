#!/bin/bash
# Creator: Phil Cook
# Email: phil@phil-cook.com
# Twitter: @p_cook
brew_prefix=$(brew --prefix | sed 's#/#\\\/#g')

brew_array=("53","54","55","56","70","71","72")
php_array=("php53" "php54" "php55" "php56" "php70" "php71" "php72")
valet_support_php_version_array=("php56" "php70" "php71" "php72")
php_installed_array=()
php_version="php$1"
php_opt_path="$brew_prefix\/opt\/"

php5_module="php5_module"
apache_php5_lib_path="\/libexec\/apache2\/libphp5.so"
php7_module="php7_module"
apache_php7_lib_path="\/libexec\/apache2\/libphp7.so"
native_osx_php_apache_module="LoadModule php5_module libexec\/apache2\/libphp5.so"

php_module="$php5_module"
apache_php_lib_path="$apache_php5_lib_path"

# Has the user submitted a version required
if [[ -z "$1" ]]
then
	echo "usage: brew-php-switcher version [-s|-s=*] [-c=*]"; echo;
	echo "    version    one of:" ${brew_array[@]};
	echo "    -s         skip change of mod_php on apache";
	echo "    -s=*         skip change of mod_php on apache or valet restart i.e (apache|valet,apache|valet)";
	echo "    -c=*         switch a specific config (apache|valet,apache|valet"; echo;
	exit
fi

if [ $(echo "$php_version" | sed 's/^php//') -ge 70 ]; then
	php_module="$php7_module"
	apache_php_lib_path="$apache_php7_lib_path"
fi

apache_change=1
apache_conf_path="/etc/apache2/httpd.conf"
apache_php_mod_path="$php_opt_path$php_version$apache_php_lib_path"

valet_restart=0
# Check if valet is already install
hash valet 2>/dev/null && valet_installed=1 || valet_installed=0

POSITIONAL=()

# Check for skip & change flag
while [[ $# -gt 0 ]]; do
    key="$1"
    case "$key" in
        # This is a flag type option. Will catch either -s or --skip
        -s|-s=*|--skip=*)
        if  [[  "${1#*=}" == "-s" || "${1#*=}" == *"apache"* ]]; then
            apache_change=0
        elif [ "${1#*=}" == "valet" ]; then
            valet_restart=0
        fi
        ;;
        # This is a flag type option. Will catch either -c or --change
        -c=*|--change=*)
             [[ "$1" == *"apache"* ]] && apache_change=1 || apache_change=0
             [[ "$1" == *"valet"* ]] && valet_restart=1 || valet_restart=0
        ;;
        *)
        POSITIONAL+=("$1") # save it in an array for later
        ;;
    esac
    # Shift after checking all the cases to get the next option
    shift
done

# What versions of php are installed via brew
for i in ${php_array[*]}
	do
		if [[ -n "$(brew ls --versions "$i")" ]]
		then
			php_installed_array+=("$i")
		fi
done

# Check if php version support via valet
if [[ (" ${valet_support_php_version_array[*]} " != *"$php_version"*) && ($valet_restart -eq 1) ]]
then
    echo "Sorry, but $php_version is not support via valet";
    exit;
fi

# Check that the requested version is supported
if [[ " ${php_array[*]} " == *"$php_version"* ]]
then
	# Check that the requested version is installed
	if [[ " ${php_installed_array[*]} " == *"$php_version"* ]]
	then

	    # Stop valet service
		if [[ ($valet_installed -eq 1) && ($valet_restart -eq 1) ]]; then
		   echo "Stop Valet service";
		   valet stop;
		fi

		# Switch Shell
		echo "Switching to $php_version"
		echo "Switching your shell"
		for i in ${php_installed_array[@]}
		do
			if [[ -n $(brew ls --versions $i) ]]
			then
				brew unlink $i
			fi
		done
		brew link "$php_version"

		# Switch apache
		if [[ $apache_change -eq 1 ]]; then
			echo "You will need sudo power from now on"
			echo "Switching your apache conf"

			for j in ${php_installed_array[@]}
			do
				loop_php_module="$php5_module"
				loop_apache_php_lib_path="$apache_php5_lib_path"
				if [ $(echo "$j" | sed 's/^php//') -ge 70 ]; then
					loop_php_module="$php7_module"
					loop_apache_php_lib_path="$apache_php7_lib_path"
				fi
				apache_module_string="LoadModule $loop_php_module $php_opt_path$j$loop_apache_php_lib_path"
				comment_apache_module_string="#$apache_module_string"

				# If apache module string within apache conf
				if grep -q "$apache_module_string" "$apache_conf_path"; then
					# If apache module string not commented out already
					if ! grep -q "$comment_apache_module_string" "$apache_conf_path"; then
						sudo sed -i.bak "s/$apache_module_string/$comment_apache_module_string/g" $apache_conf_path
					fi
				# Else the string for the php module is not in the apache config then add it
	 			else
					sudo sed -i.bak "/$native_osx_php_apache_module/a\\
$comment_apache_module_string\\
" $apache_conf_path
				fi
			done
			sudo sed -i.bak "s/\#LoadModule $php_module $apache_php_mod_path/LoadModule $php_module $apache_php_mod_path/g" $apache_conf_path
			echo "Restarting apache"
			sudo apachectl restart
		fi


        # Switch valet
		if [[ $valet_restart -eq 1 ]]; then
		    if [[ valet_installed -eq 1 ]]; then
                valet restart
             else
               echo "valet doesn't installed in your system, will skip restarting valet service";
            fi
        fi

		echo "All done!"
	else
		echo "Sorry, but $php_version is not installed via brew. Install by running: brew install $php_version"
	fi
else
	echo "Unknown version of PHP. PHP Switcher can only handle arguments of:" ${brew_array[@]}
fi
