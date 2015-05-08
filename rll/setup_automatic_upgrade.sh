#! /bin/bash

# Add entry in /etc/cron.d/ to daily check and excute an upgrade for rightlink.

# -e will immediatly exit out of script at point of error
set -e

cron_file='/etc/cron.d/rightlink-upgrade'
exec_file='/usr/local/bin/rightlink_check_upgrade'

# Grab toggle option to enable
if [[ "$ENABLE_AUTO_UPGRADE" == "false" ]]; then
  if [[ -e ${cron_file} ]]; then
    sudo rm -f ${cron_file}
    echo "Automatic upgrade disabled"
  else
    echo "Automatic upgrade never enabled - no action done"
  fi
else
  # If cron file already exists, will recreate it and update cron config with new random times.
  if [[ -e ${cron_file} ]]; then
    echo "Recreating cron entry"
  fi

  # Generate executable script to run by cron
  sudo dd of="${exec_file}" <<EOF
#! /bin/bash

# This file is autogenerated. Do not edit as changes will be overwritten.

rsc --rl10 cm15 schedule_recipe /api/right_net/scheduler/schedule_recipe recipe=rll::upgrade
EOF

  sudo chown root:root ${exec_file}
  sudo chmod 0700 ${exec_file}

  # Random hour 0-23
  cron_hour=$(( $RANDOM % 24 ))

  # Random minute 0-59
  cron_minute=$(( $RANDOM % 60 ))

  sudo bash -c "umask 077 && echo '${cron_minute} ${cron_hour} * * * root ${exec_file}' > ${cron_file}"

  # Set perms regardless of umask since the file could be overwritten with existing perms.
  sudo chmod 0600 ${cron_file}

  echo "Automatic upgrade enabled."
fi
