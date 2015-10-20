#! /bin/bash -e

# ---
# RightScript Name: RL10 Linux Setup Automatic Upgrade
# Description: Creates a cron job that performs a daily check to see if
#   an upgrade to RightLink is available and upgrades if there is.
# Inputs:
#   ENABLE_AUTO_UPGRADE:
#     Input Type: single
#     Category: RightScale
#     Description: Enables or disables automatic upgrade of RightLink10.
#     Default: text:true
#     Required: false
#     Advanced: true
#     Possible Values:
#       - text:true
#       - text:false
# ...
#

# Determine base directory of rightlink / rsc
[[ -e /usr/local/bin/rightlink ]] && bin_dir=/usr/local/bin || bin_dir=/opt/bin

# Add entry in /etc/cron.d/ to check and execute an upgrade for rightlink daily.
cron_file='/etc/cron.d/rightlink-upgrade'
exec_file="${bin_dir}/rightlink_check_upgrade"
# Add entry in /etc/systemd/system if system doesn't support cron
service_file='/etc/systemd/system/rightlink-upgrade.service'
timer_file='/etc/systemd/system/rightlink-upgrade.timer'

# Grab toggle option to enable
if [[ "$ENABLE_AUTO_UPGRADE" == "false" ]]; then
  if [[ -e ${cron_file} || -e ${service_file} ]]; then
    sudo rm -f ${cron_file}
    sudo rm -f ${timer_file}
    echo "Automatic upgrade disabled"
  else
    echo "Automatic upgrade never enabled - no action done"
  fi
else
  # If cron file already exists, will recreate it and update cron config with new random times.
  if [[ -e ${cron_file} || -e ${service_file} ]]; then
    echo "Recreating scheduled task"
  fi

  # Determine if running a rightscript or a recipe
  if [[ $(pwd) =~ scripts ]]; then
    rsc_command="schedule_right_script /api/right_net/scheduler/schedule_right_script right_script=\"RL10 Linux Upgrade\""
  else
    rsc_command="schedule_recipe /api/right_net/scheduler/schedule_recipe recipe=rll::upgrade"
  fi

  # Random hour 0-23
  scheduled_hour=$(( $RANDOM % 24 ))

  # Random minute 0-59
  scheduled_minute=$(( $RANDOM % 60 ))

  if [[ $(cat /etc/os-release) =~ CoreOS ]]; then
  # Generate service file to be executed by systemd timers
  sudo dd of="${service_file}" 2>/dev/null <<EOF
[Unit]
Description=Runs the RL10 Linux Upgrade script

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c '${bin_dir}/rsc --rl10 cm15 ${rsc_command}'
EOF

  # Generate timer file to determine when to run the upgrade script
  sudo dd of="${timer_file}" 2>/dev/null <<EOF
[Unit]
Description=Run rightlink-upgrade.service once daily

[Timer]
OnCalendar=*-*-* ${scheduled_hour}:${scheduled_minute}
EOF

  sudo systemctl daemon-reload
  else
  # Generate executable script to run by cron
  sudo dd of="${exec_file}" 2>/dev/null <<EOF
#! /bin/bash

# This file is autogenerated. Do not edit as changes will be overwritten.

${bin_dir}/rsc --rl10 cm15 ${rsc_command}
EOF

  sudo chown rightlink:rightlink ${exec_file}
  sudo chmod 0700 ${exec_file}

  sudo bash -c "umask 077 && echo '${scheduled_minute} ${scheduled_hour} * * * rightlink ${exec_file}' > ${cron_file}"

  # Set perms regardless of umask since the file could be overwritten with existing perms.
  sudo chmod 0600 ${cron_file}
  fi

  echo "Automatic upgrade enabled."
fi
