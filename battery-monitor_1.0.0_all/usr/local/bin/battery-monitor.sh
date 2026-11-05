#!/bin/bash

#Find the first avail battery path matching power supply class
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
fi

where_power="/sys/class/power_supply"

battery_paths=()

if [[ ! -d "$where_power" ]]; then
    echo "power_supply does NOT exist." >&2
fi

for batt_dir in $where_power/*; do
    if [[ ! -d "$batt_dir" ]]; then
        continue
    fi

    type_exist="$batt_dir/type"

    if [ -f "$type_exist" ]; then
        device_type="$(cat $type_exist)"

        if [ $device_type == "Battery" ]; then
            battery_paths+=("$batt_dir")
        fi
    fi
done


#double check battery exists
battery_count="${#battery_paths[@]}"

if (( battery_count == 0 )); then   
    echo "no battery detected"
    exit 1
fi

battery_optimums=()

for path in "${battery_paths[@]}"; do

    device_name="$(basename "$path")"
    charge_full="$path/charge_full_design"
    charge_curr="$path/charge_full"
    voltage="$path/voltage_now"
    capacity="$(cat $path/capacity)"

    stat="$path/status"
    status="$(cat $stat)"

    #check if capacity level exists and voltage before taking ratios
    if [[ ! -f "$charge_full" || ! -f "$voltage" ]]; then
        echo "can't find capacity level and voltage. optimum can't be calculated
        will default to 80% battery savings."
    fi

    
    #calculate optimum levels first
    charge="$(cat $charge_full)"
    curr_charge="$(cat $charge_curr)"
    volt="$(cat $voltage)"

    charge_wh=$(( (charge * volt) / 10**12 ))
    curr_charge_wh=$(( (curr_charge * volt) / 10**12 ))
    optimum=$(bc <<< "scale=0; $curr_charge_wh / $charge_wh * 100")

    battery_optimums+=("$optimum")

    if (( capacity >= optimum )); then
            #set desktop alert
            notify-send -u critical "Battery level is past or at optimum. Unplug now"
    fi
    
done
