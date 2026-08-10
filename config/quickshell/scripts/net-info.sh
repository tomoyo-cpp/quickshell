#!/bin/sh
# Emits one line of details about the default route's interface, for
# NetworkPanel.qml:
#
#   <iface> <ipv4/prefix> <gateway> <link_speed_mbit> <ssid> <freq_mhz>
#
# Fields that do not apply are emitted as "-" so the field count is fixed and
# the reader can split on whitespace without counting.

none() { [ -n "$1" ] && printf '%s' "$1" || printf '-'; }

# The interface carrying the default route is the one worth reporting; a
# laptop often has a docked ethernet and an idle wifi radio up at once.
iface=$(ip route show default 2>/dev/null | awk '/^default/ { print $5; exit }')
gw=$(ip route show default 2>/dev/null | awk '/^default/ { print $3; exit }')

if [ -z "$iface" ]; then
    echo "- - - - - -"
    exit 0
fi

addr=$(ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{ print $4; exit }')

# Wired links publish a negotiated speed; wireless ones report -1 or nothing.
speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null)
case "$speed" in
    '' | -1 | *[!0-9]*) speed='' ;;
esac

ssid=''
freq=''
if [ -d "/sys/class/net/$iface/wireless" ] || [ -e "/sys/class/net/$iface/phy80211" ]; then
    # nmcli rather than iw: NetworkManager is already a dependency here, and
    # iw is not installed. The active AP is the row flagged ACTIVE=yes.
    info=$(nmcli -t -f ACTIVE,SSID,RATE,FREQ dev wifi 2>/dev/null | awk -F: '/^yes:/ { print; exit }')
    ssid=$(printf '%s' "$info" | cut -d: -f2)
    # "1170 Mbit/s" and "5500 MHz" — keep the leading integer only.
    speed=$(printf '%s' "$info" | cut -d: -f3 | awk '{ print int($1) }')
    freq=$(printf '%s' "$info" | cut -d: -f4 | awk '{ print int($1) }')
    [ "$speed" = "0" ] && speed=''
    [ "$freq" = "0" ] && freq=''
fi

# Spaces in an SSID would break the field split.
ssid=$(printf '%s' "$ssid" | tr ' ' '\037')

printf '%s %s %s %s %s %s\n' \
    "$(none "$iface")" "$(none "$addr")" "$(none "$gw")" \
    "$(none "$speed")" "$(none "$ssid")" "$(none "$freq")"
