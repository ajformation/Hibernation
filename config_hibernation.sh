#!/bin/bash

SWAPFILE=/swap.img

function usage() {
    echo ""
    echo "$0"
    echo ""
    echo "Config all system to enable hibernation"
    echo "must be launch by root"
    echo ""
}

source /etc/os-release
apt-get -qy install bc > /dev/null
case $NAME in

    "Ubuntu")
        ver=$(echo "$VERSION_ID < 20.04" | bc)
        if [[ $ver -eq 1 ]]
        then
            echo "Take care ! Your $NAME version is lower than 24.04"
            echo "Things may not work properly"
        fi
        ;;
    *)
        echo "Take care ! $NAME hasn't been tested yet"
        echo "Things may not work properly"
        ;;

esac

if [[ $UID -ne 0 ]]
then
    usage
    exit 0
fi

export myTEMP=$(mktemp)

myBS=$(cat /proc/meminfo | awk '/MemTotal/ {print $2}')
mySWAP=$(du -s ${SWAPFILE} | awk '{print $1}')

if (( $myBS > $mySWAP )) # If memory is greater than swapfile, must increase swapfile
then 
    echo "Change Size of the swap file (may take time)"
    swapoff ${SWAPFILE}
    dd if=/dev/zero of=${SWAPFILE} bs=${myBS} count=1024 conv=notrunc
    mkswap ${SWAPFILE}
    swapon ${SWAPFILE}
fi

# Get UUID and Offset
export myUUID=$(findmnt -no UUID -T ${SWAPFILE})
export myOFFSET=$(filefrag -v ${SWAPFILE} | awk '/ 0:/{gsub("\.","",$4); print $4}')

# Manage Grub LINUX CMDLINE
echo "- Manage Grub"
source /etc/default/grub
myNEWCMD=""
for i in $GRUB_CMDLINE_LINUX_DEFAULT
do
    case "$i" in
        quiet)
            myNEWCMD=$myNEWCMD"quiet "
            ;;
        splash)
            myNEWCMD=$myNEWCMD"splash "
            ;;
        resume*)
            ;;
        *)
            echo "  > Warning! Take account argument >>$i<< in GRUB_CMDLINE_LINUX_DEFAULT variable in /etc/default/grub <"
            ;;
    esac
    echo "$myNEWCMD" > $myTEMP
done
myNEWCMD=$(cat $myTEMP)
myNEWCMD=$myNEWCMD"resume=UUID=${myUUID} "
myNEWCMD=$myNEWCMD"resume_offset=${myOFFSET}"
GRUBCONF=/etc/default/grub
sed -i "s/^\(GRUB_CMDLINE_LINUX_DEFAULT=.*\)/# $(date -Is) - \1\n\1/" $GRUBCONF
sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"${myNEWCMD}\"/" $GRUBCONF
update-grub > /dev/null 2>&1

# Manage INITRAMFS
echo "- Manage InitRAMFS"
INITRESUME=/etc/initramfs-tools/conf.d/resume
sed -i "s/^\(RESUME=.*\)/# $(date -Is) - \1\n\1/" $INITRESUME
myLINE="RESUME=$SWAPFILE resume_offset=$myOFFSET"
sed -i "s|^RESUME=.*|$myLINE|" $INITRESUME
update-initramfs -c -k all > /dev/null

# Remove Temp file
rm $myTEMP

# Give admin info
echo ""
echo "########### Informations"
echo ""
echo "Now you can try with :"
echo ""
echo "  sudo systemctl hibernate"
echo """

For Gnome UI hibernation button :

apt install gnome-shell-extensions chrome-gnome-shell
<then reboot>
Launch Firefox
Get to https://addons.mozilla.org/en-US/firefox/addon/gnome-shell-integration/ and install
<then logout or reboot>
Get to https://extensions.gnome.org/extension/755/hibernate-status-button/ and install

Now you have different hibernation/suspend/sleep options in the Gnome shutdown menu.
"""
