#!/bin/bash

echo 'Start of ecosystem monitoring startup script'

# just as a back up schedule a reboot for 24 hours (in case something goes wrong before scheduling the 2am reboot)
(sudo shutdown -r +1440) &

# Change to correct folder
cd /home/pi/rpi-eco-monitoring

### TASKS TO RUN EVERY BOOT UP

# Restart udev to simulate hotplugging of 3G dongle
bash ./bash_restart_udev.sh

# Sleep until internet connection is up, or we've been trying for 1 minute
tries=0
while true; do
	ping -c 1 -W 1 www.google.com
	ping_resp=$?
	if [[ $ping_resp -eq 0 ]] ;then
		dongle_page=$(ping -c 1 -W 1 www.google.com | grep -qi 'hi.link')
		if [[ $dongle_page -eq 1 ]] ;then
			break
		fi
	fi

	echo 'Waiting for internet connection before continuing (10 tries max)'
	sleep 1

	let tries=tries+1
	if [[ $tries -eq 10 ]] ;then
		break
	fi
done

# Update time from internet
sudo bash ./bash_update_time.sh

# Start ssh-agent so password not required
eval $(ssh-agent -s)

# Pull latest code from repo
last_sha=$(git rev-parse HEAD)
#git pull
git fetch origin
git reset --hard origin/master
echo 'Pulled from github'
now_sha=$(git rev-parse HEAD)

# Check if this file has changed - reboot if so
changed_files="$(git diff-tree -r --name-only --no-commit-id $last_sha $now_sha)"
echo "$changed_files" | grep --quiet "recorder_startup_script" && sudo reboot

# Add in current date and time to log files
currentDate=$(date +"%Y-%m-%d_%H.%M")
sed -i '1s/^/NEW BOOT TIME: '$currentDate'\n\n/' *_log.txt

# Move old log files to upload folder, create new log filename
sudo mkdir -p ./continuous_monitoring_data/logs/
sudo mv *_log.txt ./continuous_monitoring_data/logs/
piId=$(cat /proc/cpuinfo | grep Serial | cut -d ' '  -f 2)
logFileName="$piId""_""$currentDate"_log.txt

# Start recording script
echo 'End of startup script'
sudo python -u python_record.py |& tee $logFileName