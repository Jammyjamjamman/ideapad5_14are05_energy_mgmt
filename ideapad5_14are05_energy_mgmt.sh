#!/bin/bash

function get_bit()
{
	echo "\_SB.PCI0.LPC0.EC0.$1" > /proc/acpi/call
	local bit=$(cat /proc/acpi/call | cut -d '' -f1)
	if [ "$bit" == "0x1" ]; then
		echo "1"
	else
		echo "0"
	fi
}

function check_root()
{
	if [[ $(id -u) -ne 0 ]]; then
		echo "Must run with root priviledges";
		exit 1;
	fi
}

function check_acpi_call()
{
	if [[ ! -f /proc/acpi/call ]]; then
		echo "Could not find /proc/acpi/call";
		echo "Install acpi_call package";
		exit 1;
	fi
}

usage()
{
read -r -d '' HELP_STR << EOM
    Usage: $0 perf_mode [..params..]|rapid_charge [on|off]|batt_conserv [on|off]
	parameters for 'perf_mode':
		intel - switch to intelligent cooling mode
		perf - switch to extreme performance mode
		save - switch to battery save mode
		<empty> - return current mode (one of the above)
	parameters for 'rapid_charge':
		on - switch rapid charge on
		off - switch rapid charge off
		<empty> - return current state of rapid charge
	parameters for 'batt_conserv':
		on - switch battery conservation mode on (limits charge to 55-60%)
		off - switch battery conservation mode off
		<empty> - return current state of battery conservation mode
EOM
    echo "$HELP_STR"
}

perf_mode()
{
	if [ "$1" != "" ]; then
		local call_code=
		case $1 in
			intel ) call_code='0x000FB001'
				;;
			perf ) call_code='0x0012B001'
				;;
			save ) call_code='0x0013B001'
				;;
			* )	usage
				exit 1
		esac
		echo "\_SB.PCI0.LPC0.EC0.VPC0.DYTC $call_code" > /proc/acpi/call
	else
		#obtain current perf mode
		local stmd=$(get_bit STMD)
		local qtmd=$(get_bit QTMD)
		case "$stmd$qtmd" in
			"00" ) echo 'perf' 
				;;
			"01" ) echo 'save' 
				;;
			"10" ) echo 'intel' 
				;;
			"11" ) echo 'unk' 
				;;
			* ) echo 'how did we get here?'
				exit 2
		esac
	fi
}

rapid_charge()
{
	if [ "$1" != "" ]; then
		local call_code=
		case $1 in
			on ) call_code='0x07' 
			     battery_conservation off 
				;;
			off ) call_code='0x08'
				;;
			* )	usage
				exit 1
		esac
		echo "\_SB.PCI0.LPC0.EC0.VPC0.SBMC $call_code" > /proc/acpi/call
	else
		#obtain current rapid charge mode
		local fcgm=$(get_bit FCGM)
		case "$fcgm" in
			"0" ) echo 'off' 
				;;
			"1" ) echo 'on' 
				;;
			* ) echo 'unexpected bit value for rapid charge'
				exit 3
		esac
	fi
}

battery_conservation()
{
	if [ "$1" != "" ]; then
		local call_code=
		case $1 in
			on ) call_code='0x03'
			     rapid_charge off
				;;
			off ) call_code='0x05'
				;;
			* )	usage
				exit 1
		esac
		echo "\_SB.PCI0.LPC0.EC0.VPC0.SBMC $call_code" > /proc/acpi/call
	else
		#obtain current battery conservation mode
		local btsg=$(get_bit BTSG)
		case "$btsg" in
			"0" ) echo 'off' 
				;;
			"1" ) echo 'on' 
				;;
			* ) echo 'unexpected bit value for battery conservation'
				exit 3
		esac
	fi
}

########################################################################################

check_root
check_acpi_call

model_name=$(dmidecode | grep Version | sed -n '2p' | cut -d' ' -f2,3,4)
if [ "$model_name" != "IdeaPad 5 14ARE05" ]; then
	echo "Warning! This script was developed to run only on IdeaPad 5 14ARE05"
	echo "This machine:$model_name"
fi

case "$1" in
	"rapid_charge" ) rapid_charge $2
		;;
	"batt_conserv" ) battery_conservation $2
		;;
	"perf_mode" ) perf_mode $2
		;;
	* )	usage
		exit 1
esac
