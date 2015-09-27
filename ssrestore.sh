#!/bin/sh

# Gets the names of the available backup files and lists them for the user
# Asks the user which file should be used for restoring via a prompt
# Takes the name of a gzipped backup file and uncompresses it
# Gets the MySQL credentials from wp-config and tests the db connection
# Makes sure the backup db file exists and that it is a minimum size and has the basic WP tables in it
# Backs up the existing site and DB file to a file called failed_update_[date] inside the SecretSourceBackups folder and compresses it
# Restores live database from backup
# Deletes files from web root
# Copies backup files to web root
# Deletes .sql found inside web root produced by script above

echo "Starting a restore procedure."
THIS_DIR=$( pwd )
BACKUP_DIR="$THIS_DIR/SecretSourceBackups"
TEMP_DIR="$BACKUP_DIR/temp"
DATEFILE='%Y-%m-%d_%H%M%S'
FAILED_UPDATE_NAME=$(echo "failed_update_"`date +$DATEFILE`)
WP_CONFIG="$THIS_DIR/public_html/wp-config.php"
MYSQLDCOMMAND="$BACKUP_DIR/mysqldump.sh"

# Optional, save the "old" STDERR
# exec 3>&2
# Redirect any output to STDERR to an error log file instead 
# exec 2> "$BACKUP_DIR/backup_error.log"

BACKUPS_EXIST=$(find "$BACKUP_DIR" -iname "*_backup_20*.tar.gz" | wc -l)
if [ $BACKUPS_EXIST -gt 0 ]
then
	if [ -f "$WP_CONFIG" ]
	then
		echo "Found the wp-config.php file. This is good!"
		# get the DB config from wp-config.php
		DB_NAME=$(grep -o -E '^\s*define.+?DB_NAME.+?,\s*.+?[a-zA-Z_][a-zA-Z_0-9]*' "$WP_CONFIG" | cut -d"'" -f 4)
		DB_USER=$(grep -o -E '^\s*define.+?DB_USER.+?,\s*.+?[a-zA-Z_][a-zA-Z_0-9]*' "$WP_CONFIG" | cut -d"'" -f 4)
		DB_PASS=$(grep -o -E '^\s*define.+?DB_PASSWORD.+' "$WP_CONFIG" | cut -d"'" -f 4)
		DB_HOST=$(grep -o -E '^\s*define.+?DB_HOST.+?,\s*.+?[0-9a-zA-Z_\.]*' "$WP_CONFIG" | cut -d"'" -f 4)
		if [ "" == "$DB_PASS" ]
		then
			PASS=''
		else
			echo "The password is NOT empty, this is good!"
			PASS="-p'$DB_PASS'"
		fi
		FAILED_UPDATE_NAME_TGZ="${DB_NAME}_$FAILED_UPDATE_NAME.tar.gz"
		OFS=$IFS
		IFS="
	"
		directorylist=$(for i in $BACKUP_DIR/${DB_NAME}_backup_20*; do [ -f "$i" ] && basename "$i"; done)
		PS3='Restore a site from backup: '
		until [ "$directory" == "Finished" ]; do
			printf "%b" "\a\n\nPlease type the number of the archive you would like to restore from:\n" >&2 
			select directory in $directorylist; do
				# User types a number which is stored in $REPLY, but select 
				# returns the value of the entry
				if [ "$directory" == "Finished" ]; then
					echo "Finished processing directories."
					break
				elif [ -n "$directory" ]; then
					echo "You chose number $REPLY, processing $directory..."
					# make a backup of the failed update
					echo "Making a backup of the failed update."
					# this line needs to be updated when in production as it
					# will no longer source it, but rather run it as a command
					ssbackup.sh
					# get the most recently created file and rename it
					F=$(find "$BACKUP_DIR" -iname *.tar.gz -type f | sort | tail -n 1)
					NF=$(basename "$F")
					mv "$F" "$BACKUP_DIR/$FAILED_UPDATE_NAME_TGZ"
				
					echo "Uncompressing the selected backup file."
					# uncompress the desired backup
					mkdir -p "$TEMP_DIR"
					tar -zxf "$BACKUP_DIR/$directory" -C "$TEMP_DIR"
				
					# get the name of the restore database
					DB_RESTORE_NAME=$(echo $directory | cut -d'.' -f 1 | cut -d'_' -f 2-4)
					echo "Restoring from $DB_RESTORE_NAME.sql"
				
					echo "Restoring the database."
					# put WP into maintenace mode, if possible
					# drop and reimport the database
					echo '#!/bin/sh' > "$BACKUP_DIR/mysql_restore.sh"
					echo "
				
					" >> "$BACKUP_DIR/mysql_restore.sh"
					echo "mysql -u $DB_USER $PASS -h $DB_HOST -e 'DROP DATABASE IF EXISTS $DB_NAME'" >> "$BACKUP_DIR/mysql_restore.sh"
					echo "mysql -u $DB_USER $PASS -h $DB_HOST -e 'CREATE DATABASE IF NOT EXISTS $DB_NAME'" >> "$BACKUP_DIR/mysql_restore.sh"
					echo "mysql -u $DB_USER $PASS -h $DB_HOST '$DB_NAME' < '$TEMP_DIR/$DB_RESTORE_NAME.sql'" >> "$BACKUP_DIR/mysql_restore.sh"
					. "$BACKUP_DIR/mysql_restore.sh"
				
					echo "Restoring the WP files and all uploaded content."
					# delete everything in public_html
					rm -Rf "$THIS_DIR/public_html/*"
				
					# move contents of restore folder to public_html
					cp -R "$TEMP_DIR/" "$THIS_DIR/public_html/"
				
					echo "Removing temporary files."
					# delete uncompressed folder (house cleaning)
					rm -Rf "$TEMP_DIR"
					rm -f "$BACKUP_DIR/mysql_restore.sh"
					rm -f "$THIS_DIR/public_html/$DB_RESTORE_NAME.sql"
					echo "Done! The site has been restored."
					exit 0
					break
				else
					echo "Invalid selection!"
				fi # end of handle user's selection
			done # end of select a directory 
		done # end of until dir == finished
		IFS=$OFS
	else
		echo "Damn! Can't find the wp-config.php file!"
	fi
else
	echo "Sorry. There don't appear to be any backup files available for restoring."
	echo "Did you run ssbackup.sh before running this RESTORE command?"
fi
# Turn off redirect by reverting STDERR and closing FH3 
# exec 2>&3-
