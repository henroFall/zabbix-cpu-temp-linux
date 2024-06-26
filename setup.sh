#!/bin/bash

# Script paths and names
SCRIPT_PATH="/etc/zabbix/scripts"
SCRIPT_NAME="cpu_temp_avg.sh"
AGENT_CONF_PATH="/etc/zabbix/zabbix_agentd.d"  # Directory for agent includes
CONFIG_FILE="$AGENT_CONF_PATH/check_temp.conf"  # Configuration file for temperature check

# Ensure the Zabbix agent include directory exists
mkdir -p $AGENT_CONF_PATH

# Create script directory if not exists
mkdir -p $SCRIPT_PATH

# Create or update the temperature monitoring script
cat > $SCRIPT_PATH/$SCRIPT_NAME <<EOF
#!/bin/bash

# Define the maximum number of thermal zone readings to process
MAX_ENTRIES=20

# Read temperatures from all available thermal zones
readarray -t temperatures < <(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n \$MAX_ENTRIES)

# Exit if no temperature data is found
if [ \${#temperatures[@]} -eq 0 ]; then
    echo "No temperature data available"
    exit 1
fi

# Initialize variable for sum of temperatures
sum_temp=0

# Sum temperatures
for temp in "\${temperatures[@]}"; do
    sum_temp=\$((\$sum_temp + \$temp))
done

# Calculate average temperature in milli-Celsius
average_temp_milliC=\$((\$sum_temp / \${#temperatures[@]}))

# Convert to Celsius
average_temp_c=\$((\$average_temp_milliC / 1000))

# Output the average temperature
echo \$average_temp_c
EOF

# Make the script executable
chmod +x $SCRIPT_PATH/$SCRIPT_NAME

# Add or update UserParameter in the configuration file
echo "UserParameter=system.cpu.temp,$SCRIPT_PATH/$SCRIPT_NAME" > $CONFIG_FILE

# Check which Zabbix agent service is active, then restart it
if systemctl is-active --quiet zabbix-agent2; then
    systemctl restart zabbix-agent2
elif systemctl is-active --quiet zabbix-agent; then
    systemctl restart zabbix-agent
else
    echo "Neither Zabbix Agent nor Zabbix Agent 2 are active. Please start the relevant service."
    exit 1
fi

echo "Setup complete. Zabbix configuration has been updated and agent restarted."
