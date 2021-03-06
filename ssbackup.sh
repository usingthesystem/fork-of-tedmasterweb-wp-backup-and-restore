#!/bin/sh

# Write a script that, when executed from the home directory of an account via the command line:
# Creates ~/SecretSourceBackups if it doesn't exist
# Creates a backup folder inside ~/SecretSourceBackups with the date and time as the name, e.g.: 2015-08-24_23-17-11
# Copies the web root to the backup folder
# Gets the MySQL credentials from wp-config and tests the db connection
# Dumps the database to the web folder
# Makes sure the database backup file is of a certain, minimum size and contains the minimum WP tables (do some minimum sanity checks)
# Compresses the backup folder to save space

# The above script will be called ss_backup.sh. It will take no parameters but must be run from the account home (a.k.a. ~/). It expects to find a web root called public_html. 
 
# set a bunch of variables
for FN in "$@"
do
	case "$FN" in
		'--migrate')
			shift
			DO_MIGRATION='true'
		;;
		'--documentroot')
			shift
			DOC_ROOT="${1:-public_html}"
		;;
		'--skip-uploads')
			shift
			SKIP_UPLOADS='true'
		;;
	esac
done

# set some environment variables
THIS_DIR=$( pwd )
BACKUP_DIR="$THIS_DIR/SecretSourceBackups"
PUBLIC_HTML="${DOC_ROOT:=public_html}"
mkdir -p "$BACKUP_DIR"
DATEFILE='%Y-%m-%d_%H%M%S'
BACKUP_NAME=$(echo "backup_"`date +$DATEFILE`)
WP_CONFIG="$THIS_DIR/$PUBLIC_HTML/wp-config.php"
DB_BACKUP_FILE="$THIS_DIR/$PUBLIC_HTML/$BACKUP_NAME.sql"
MYSQLDCOMMAND="$BACKUP_DIR/mysqldump.sh"

# make sure wp-config.php actually exists before doing anything else
if [ -f "$WP_CONFIG" ]
then
	echo "Found the wp-config.php file. This is good!"
	# add prompts for migration
	if [ 'true' == "$DO_MIGRATION" ]
	then
		# get the new domain name
		read -p 'Please enter the new Home URL [ex.: http://www.mynewsite.com]. Be sure to include the trailing slash! : ' NEW_HOME_URL
		if [ "" == "$NEW_HOME_URL" ]
		then
			DO_MIGRATION='false'
			echo 'The Home URL cannot be blank. Proceeding without preparing for a migration.'
		else
			echo "You entered $NEW_HOME_URL. What is the new Site URL?"
			read -p "Please enter the new Site URL [$NEW_HOME_URL]: " NEW_SITE_URL
			if [ "" == "$NEW_SITE_URL" ]
			then
				NEW_SITE_URL="$NEW_HOME_URL"
				echo "Using the new Home URL ($NEW_HOME_URL) as the new Site URL."
			fi
			echo "The new Site URL is $NEW_SITE_URL."
			read -p "Please enter the new Site path. The current path is $THIS_DIR/$PUBLIC_HTML: " NEW_SITE_PATH
			if [ "" == "$NEW_SITE_PATH" ]
			then
				NEW_SITE_PATH="$THIS_DIR/$PUBLIC_HTML"
				echo "Using the current path ($THIS_DIR/$PUBLIC_HTML) as the new site path."
			fi
			if [ ! -d "$NEW_SITE_PATH" ]
			then
				echo "We're sorry. $NEW_SITE_PATH does not seem to be a valid path. Continuing anyway as the new path may be on a new server..."
			fi
			echo "The new site path is $NEW_SITE_PATH."
		fi
	fi
	
	# get the DB config from wp-config.php
	DB_NAME=$(grep -o -E '^\s*define.+?DB_NAME.+?,\s*.+?[a-zA-Z_][a-zA-Z_0-9\-]*' "$WP_CONFIG" | cut -d"'" -f 4)
	DB_USER=$(grep -o -E '^\s*define.+?DB_USER.+?,\s*.+?[a-zA-Z_][a-zA-Z_0-9\-]*' "$WP_CONFIG" | cut -d"'" -f 4)
	DB_PASS=$(grep -o -E '^\s*define.+?DB_PASSWORD.+' "$WP_CONFIG" | cut -d"'" -f 4)
	DB_HOST=$(grep -o -E '^\s*define.+?DB_HOST.+?,\s*.+?[0-9a-zA-Z_\.]*' "$WP_CONFIG" | cut -d"'" -f 4)
	DB_TABLE_PREFIX=$(grep -o -E '^\s*\$table_prefix\s*=\s*.*' "$WP_CONFIG" | cut -d"'" -f 2)
	BACKUP_NAME_TGZ="${DB_NAME}_$BACKUP_NAME.tar.gz"

	if [ 'true' == "$DO_MIGRATION" ]
	then
		read -p "Please enter the database username for the new site [$DB_USER]: " DB_USER_NEW
		if [ "" == "$DB_USER_NEW" ]
		then
			if [ "" == "$DB_USER" ]
			then
				echo "We're sorry but the database username cannot be left blank."
				echo "No action has been taken."
				exit 104
			else
				DB_USER_NEW="$DB_USER"
			fi
		fi
	else
		if [ "" == "$DB_USER" ]
		then
			echo "We're sorry but the database username cannot be left blank."
			echo "No action has been taken."
			exit 104
		fi
	fi
	
	
	if [ 'true' == "$DO_MIGRATION" ]
	then
		read -p "Please enter the password for this site [$DB_PASS]: " DB_PASS_NEW
		# if the password is empty, as could be the case for insecure servers, don't use the -p switch
		if [ "" == "$DB_PASS_NEW" ]
		then
			if [ "" == "$DB_PASS" ]
			then
				PASS_NEW=''
			else
				echo "The password is NOT empty, this is good!"
				PASS_NEW="$DB_PASS"
			fi
		else
			PASS_NEW="$DB_PASS_NEW"
		fi
	fi
	
	if [ "" == "$DB_PASS" ]
	then
		PASS=''
	else
		echo "The password is NOT empty, this is good!"
		PASS="-p'$DB_PASS'"
	fi
	
	if [ 'true' == "$DO_MIGRATION" ]
	then
		read -p "Please enter the database name for this site [$DB_NAME]: " DB_NAME_NEW
		if [ "" == "$DB_NAME_NEW" ]
		then
			if [ "" == "$DB_NAME" ]
			then
				echo "We're sorry but the database name cannot be left blank."
				echo "No action has been taken."
				exit 105
			else
				DB_NAME_NEW="$DB_NAME"
			fi
		fi
	else
		if [ "" == "$DB_NAME" ]
		then
			echo "We're sorry but the database name cannot be left blank."
			echo "No action has been taken."
			exit 105
		fi
	fi
	
	if [ 'true' == "$DO_MIGRATION" ]
	then
		read -p "Please enter the database host for this site [$DB_HOST]: " DB_HOST_NEW
		if [ "" == "$DB_HOST_NEW" ]
		then
			if [ "" == "$DB_HOST" ]
			then
				echo "We're sorry but the database host cannot be left blank."
				echo "No action has been taken."
				exit 106
			else
				DB_HOST_NEW="$DB_HOST"
			fi
		fi
	else
		if [ "" == "$DB_HOST" ]
		then
			echo "We're sorry but the database host cannot be left blank."
			echo "No action has been taken."
			exit 106
		fi
	fi
	
	HOST_HAS_PORT=$(echo $DB_HOST_NEW | grep -o ':')
	if [ ! "" == "$HOST_HAS_PORT" ]
	then
		DB_HOST_NEW=${DB_HOST_NEW/\:[0-9]*/}
	fi
	
	if [ "" == "$DB_TABLE_PREFIX" ]
	then
		echo "Either the table prefix is blank or we were unable to find it."
		read -p "Please enter the table prefix for this site and hit Enter: " DB_TABLE_PREFIX
		if [ "" == "$DB_TABLE_PREFIX" ]
		then
			echo "It's unusual for the table prefix to be completely blank, but not impossible."
			echo "We'll give it a whirl regardless. Proceeding..."
		fi
	fi
	
	# dump the db to a file inside the web root
	# there is some kind of bizzare issue porhibiting me from quoting the value of the password parameter
	# as a workaround, I'm going to try writing the command to an external file and executing it instead of trying to run it here
	echo '#!/bin/sh' > "$MYSQLDCOMMAND"
	echo "
	
	" >> "$MYSQLDCOMMAND"
	# not really sure how to capture a non-zero exit status from the command below
	echo "mysqldump --lock-tables -u '$DB_USER' $PASS -h $DB_HOST '$DB_NAME' > '$DB_BACKUP_FILE'" >> "$MYSQLDCOMMAND"
	. "$MYSQLDCOMMAND" 2>> "$BACKUP_DIR/backup_error.log"

	if [ -f "$DB_BACKUP_FILE" ]
	then
		echo "The backup file was created. Checking to see if it is valid."
		# do a sanity check
		#	make sure it is a minimum size
		DB_BACKUP_FILE_SIZE=$(du -k "$DB_BACKUP_FILE" | cut -f 1) 2>> "$BACKUP_DIR/backup_error.log"
		if [ "$DB_BACKUP_FILE_SIZE" -lt 84 ]
		then
			# file size is too small
			echo "The size of the database dump seems suspiciously small ($DB_BACKUP_FILE_SIZE). Please check the size and try again."
			exit 102
		else
			echo "The backup file seems to be large enough to be valid"
		fi
		#	make sure some key tables are defined
		# grep the backup file looking for definitions of default tables
		# if all the tables are there (as judged by the number of lines found, S/B 11) then proceed
		TABLES=$(grep -c -E 'CREATE TABLE `'${DB_TABLE_PREFIX}'(commentmeta|comments|links|options|postmeta|posts|term_relationships|term_taxonomy|termmeta|terms|usermeta|users)`' "$DB_BACKUP_FILE") 2>> "$BACKUP_DIR/backup_error.log"
		if [ $TABLES -lt 11 ]
		then
			echo "The backup seems to have failed. Specifically, we seem to be missing some core tables in the database backup. Please check the file and try again."
			echo "$DB_BACKUP_FILE"
			exit 103
		else
			echo "All required tables appear to be defined in the dump"
		fi
		echo "All tests have passed. Proceeding..."
		
		if [ 'true' == "$DO_MIGRATION" ]
		then
			echo "Preparing the database for migration to a new server."
			# get the old Site and Home URLs
			# (1,'siteurl','http://newmoneytree.local/~tedsr/isluk_v2/','yes'),
			# (33,'home','http://newmoneytree.local/~tedsr/isluk_v2/','yes'),
			OLD_SITE_URL=$(grep -o -E "\([0-9]+,'siteurl','.+?','(yes|no)'\)," "$DB_BACKUP_FILE" | cut -d"'" -f 4) 2>> "$BACKUP_DIR/backup_error.log"
			OLD_HOME_URL=$(grep -o -E "\([0-9]+,'home','.+?','(yes|no)'\)," "$DB_BACKUP_FILE" | cut -d"'" -f 4) 2>> "$BACKUP_DIR/backup_error.log"
			NEW_SQL=$(cat "$DB_BACKUP_FILE" | sed "s@$OLD_SITE_URL@$NEW_SITE_URL@g") 2>> "$BACKUP_DIR/backup_error.log"
			echo "$NEW_SQL" > "$DB_BACKUP_FILE" 2>> "$BACKUP_DIR/backup_error.log"
			NEW_SQL=$(cat "$DB_BACKUP_FILE" | sed "s@$OLD_HOME_URL@$NEW_HOME_URL@g") 2>> "$BACKUP_DIR/backup_error.log"
			echo "$NEW_SQL" > "$DB_BACKUP_FILE" 2>> "$BACKUP_DIR/backup_error.log"
			echo "Updated references to $OLD_SITE_URL and $OLD_HOME_URL to $NEW_SITE_URL and $NEW_HOME_URL."
			NEW_SQL=$(cat "$DB_BACKUP_FILE" | sed "s@$THIS_DIR/$PUBLIC_HTML@$NEW_SITE_PATH@g") 2>> "$BACKUP_DIR/backup_error.log"
			echo "$NEW_SQL" > "$DB_BACKUP_FILE" 2>> "$BACKUP_DIR/backup_error.log"
			
			# At this point all paths and URLs have been updated but if 
			# the theme contains options as serialized arrays or strings
			# the update will fail. So, we need to update the string 
			# lengths in the serialized arrays before we can proceed.
			# a:5:{s:3:"url";s:80:"http://localhost/~tedsr/rosa2test/wp-content/uploads/2014/06/logo-rosa-white.png";s:2:"id";s:3:"200";s:6:"height";s:2:"28";s:5:"width";s:2:"86";s:9:"thumbnail";s:80:"http://localhost/~tedsr/rosa2test/wp-content/uploads/2014/06/logo-rosa-white.png";}
			# 
			
			# first let's see if this is even necessary
			UPDATE_OPTS=$(grep -E 's:[0-9]+:"http(s)?://[^"]*?"' "$DB_BACKUP_FILE")
			if [ ! "$UPDATE_OPTS" == "" ]
			then
				echo "Updating theme and plugin options."
				# here the trick is to update a value in the replacement based on a value in the search... or something like that.
				
			else
				echo "Theme and plugin options do not appear to need updating."
			fi
			
			# replace references to utf8mb4 to just utf8
			# See this bug report for details: https://secretsource.atlassian.net/browse/SECRETSOUR-46
			NEW_SQL=$(cat "$DB_BACKUP_FILE" | sed 's/CHARACTER SET utf8mb4/CHARACTER SET utf8/g') 2>> "$BACKUP_DIR/backup_error.log"
			echo "$NEW_SQL" > "$DB_BACKUP_FILE" 2>> "$BACKUP_DIR/backup_error.log"
			NEW_SQL=$(cat "$DB_BACKUP_FILE" | sed 's/COLLATE utf8mb4_unicode_ci/COLLATE utf8_unicode_ci/g') 2>> "$BACKUP_DIR/backup_error.log"
			echo "$NEW_SQL" > "$DB_BACKUP_FILE" 2>> "$BACKUP_DIR/backup_error.log"
			NEW_SQL=$(cat "$DB_BACKUP_FILE" | sed 's/COLLATE=utf8mb4_unicode_ci/COLLATE=utf8_unicode_ci/g') 2>> "$BACKUP_DIR/backup_error.log"
			echo "$NEW_SQL" > "$DB_BACKUP_FILE" 2>> "$BACKUP_DIR/backup_error.log"
			NEW_SQL=$(cat "$DB_BACKUP_FILE" | sed 's/CHARSET=utf8mb4/CHARSET=utf8/g') 2>> "$BACKUP_DIR/backup_error.log"
			echo "$NEW_SQL" > "$DB_BACKUP_FILE" 2>> "$BACKUP_DIR/backup_error.log"
			
			echo "Updating wp-config.php to use the new values."
			mkdir -p "$BACKUP_DIR/temp"
			# make a backup of the existing wp-config so as not to overwrite
			cp "$THIS_DIR/$PUBLIC_HTML/wp-config.php" "$BACKUP_DIR/temp/wp-config.php"
			NEW_WP_CONFIG=$(cat "$WP_CONFIG")
			if [ ! "$DB_USER" == "$DB_USER_NEW" ]
			then
				NEW_WP_CONFIG=$(echo "$NEW_WP_CONFIG" | sed "s@^define *( *'DB_USER', *'$DB_USER'@define('DB_USER', '$DB_USER_NEW'@g") 2>> "$BACKUP_DIR/backup_error.log"
			fi
			if [ ! "$DB_PASS" == "$DB_PASS_NEW" ]
			then
				# this fails if the password contains an at symbol
				ESCAPED_DB_PASS=$(echo $DB_PASS | sed 's/[\/&]/\\&/g')
				ESCAPED_DB_PASS_NEW=$(echo $DB_PASS_NEW | sed 's/[]\/$*.^|[]/\\&/g')
				NEW_WP_CONFIG=$(echo "$NEW_WP_CONFIG" | sed "s/^define *( *'DB_PASSWORD', *'$ESCAPED_DB_PASS'/define('DB_PASSWORD', '$ESCAPED_DB_PASS_NEW'/g") 2>> "$BACKUP_DIR/backup_error.log"
			fi
			if [ ! "$DB_NAME" == "$DB_NAME_NEW" ]
			then
				NEW_WP_CONFIG=$(echo "$NEW_WP_CONFIG" | sed "s@^define *( *'DB_NAME', *'$DB_NAME'@define('DB_NAME', '$DB_NAME_NEW'@g") 2>> "$BACKUP_DIR/backup_error.log"
			fi
			if [ ! "$DB_HOST" == "$DB_HOST_NEW" ]
			then
				NEW_WP_CONFIG=$(echo "$NEW_WP_CONFIG" | sed "s@^define *( *'DB_HOST', *'$DB_NAME'@define('DB_HOST', '$DB_HOST_NEW'@g") 2>> "$BACKUP_DIR/backup_error.log"
			fi
			echo "$NEW_WP_CONFIG" > "$WP_CONFIG"
		fi
		
		# remove ennecessary readmes, licenses, and error_log files, fixddbb.php in addition to .DS_Store and ._filename files (usually invisible files on a mac)
		if [ 'true' == "$DO_MIGRATION" ]
		then
			for F in $(find -E . -iregex '$THIS_DIR/$PUBLIC_HTML/.*((readme|license)(\.(htm(l)?|txt))*|error_log|fixddbb\.php)$' -type f)
			do
				echo "Removing cruft: $F"
				rm -f "$F"
			done
		fi
		
		if [ 'true' == "$SKIP_UPLOADS" ]
		then
		    EXCLUDE="--exclude=./wp-content/uploads"
		else
		    EXCLUDE=""
		fi
		tar -czf "$BACKUP_DIR/$BACKUP_NAME_TGZ" -C "$THIS_DIR/$PUBLIC_HTML" "$EXCLUDE" . 2>> "$BACKUP_DIR/backup_error.log"

		echo "Cleaning up..."
		if [ 'true' == "$DO_MIGRATION" ]
		then
			cp "$BACKUP_DIR/temp/wp-config.php" "$THIS_DIR/$PUBLIC_HTML/wp-config.php" 2>> "$BACKUP_DIR/backup_error.log"
		fi
		rm -f "$MYSQLDCOMMAND" 2>> "$BACKUP_DIR/backup_error.log"
		rm -f "$DB_BACKUP_FILE" 2>> "$BACKUP_DIR/backup_error.log"
		echo "Done. The backup file is: "
		echo "$BACKUP_DIR/$BACKUP_NAME_TGZ"
	else
		echo "backup file doesn't exist"
	fi
else
	# echo an error message and quit
	echo "Uh, the wp-config.php file can't be found"
	echo "We're looking here for it: $WP_CONFIG"
	echo "Are you running this script from the right location? ~/"
	echo "Have gremlins eaten it?"
	exit 101
fi
