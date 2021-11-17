#!/bin/sh
#################################################
#  EPJAMS                                       #
#  EPJ -  Archlinux Minimal Setup              #
#      -  RTFM   Archlinux Handbook Scripted    #
#      -     date      :         15-Nov-2021    #
#      -     version   :                v1.0    #
#################################################
###      https://github.com/eugenepauljean     ##
###      https://discord.gg/RETZdJfpYZ         ##
#################################################
prepare_setup () {
        pacman -Sy --noconfirm --needed dialog pacman-contrib ncurses
}
ask_select_mirrors () {
        if (dialog --clear --title "EPJ Archlinux Minimal Server" --yesno "\nThis script aims to minimize Archlinux installation steps, while respecting the handbook\n\n\nIt is recommended to check the fastest mirrors near your worldwide location...\n\n---Download the latest 50 up-to-date mirrors\n---Perform and sort the best for your location\n\n\nEstimated time : 45 seconds" 30 80)
        then
            reflector > /etc/pacman.d/mirrorlist.latestupdate
            sed -i 50q /etc/pacman.d/mirrorlist.latestupdate
            echo -e "\033[31;5mMirrorlist test in progress...waiting 45 seconds....\033[0m"
            rankmirrors -n 10 /etc/pacman.d/mirrorlist.latestupdate > /etc/pacman.d/mirrorlist
        else
            echo "You have chosen the Russian roulette Mirrors option !"
        fi
}
check_bootmode () {
        if [[ -d "/sys/firmware/efi/efivars" ]]
        then
            bootvar=gpt
        else
            bootvar=msdos
        fi
}
update_systemclock () {
        timedatectl set-ntp true
        hwclock --systohc
}
ask_check_diskname () {
        let i=0
        diskselection=()
        while read -r line; do
            let i=$i+1
            diskselection+=($line)
        done < <( lsblk -n --output TYPE,KNAME,SIZE | grep "disk" |  awk '{print $2} {print $3}' )
        disknametarget=$(dialog --clear --stdout --title "SELECT DISK TARGET" --menu "\nList Diskname - Size :" 30 80 0 ${diskselection[@]})
}
ask_erase_disk () {
        if (dialog --title "WIPE AND PREPARE AUTO PARTITION" --yesno "\nWARNING\n\n\nDO YOU ACCEPT TO WIPE, AUTOPARTITION, FORMAT\n\n\nDISKNAME : $disknametarget\nBOOTMODE : $bootvar\n" 20 60)
        then
            wipefs -a /dev/$disknametarget
        else
            echo "You have chosen to cancel the installation"
            exit 0
        fi
}
ask_encrypted_choice () {
        if (dialog --clear --title "LUKS ENCRYPTION" --yesno "\n\nLUKS ENCRYPTION\n\nENABLE DISK ENCRYPTION ?" 30 80)
        then
            encrypteddisk=yes
            create_partition_encrypted
        else
            encrypteddisk=no
            create_partition
        fi
}
create_partition_encrypted () {
        if [[ $bootvar == "gpt" ]] ; then
            parted -s /dev/$disknametarget mklabel gpt
            parted -s /dev/$disknametarget mkpart fat32 1MiB 150MiB
            parted -s /dev/$disknametarget set 1 esp
            parted -s /dev/$disknametarget mkpart ext4 150MiB 300MiB
            parted -s /dev/$disknametarget mkpart ext4 300MiB 100%
            cryptsetup luksFormat /dev/${disknametarget}${part3}
            cryptsetup open /dev/${disknametarget}${part3} cryptroot
            mkfs.vfat /dev/${disknametarget}${part1}
            mkfs.ext4 /dev/${disknametarget}${part2}
            mkfs.ext4 -L root /dev/mapper/cryptroot
            mount /dev/mapper/cryptroot /mnt
            mkdir -p /mnt/boot
            mount /dev/${disknametarget}${part2} /mnt/boot
            mkdir /mnt/boot/efi
            mount /dev/${disknametarget}${part1} /mnt/boot/efi
        elif [[ $bootvar == "msdos" ]] ; then
            parted -s /dev/$disknametarget mklabel msdos
            parted -s /dev/$disknametarget mkpart primary ext4 1MiB 150MiB
            parted -s /dev/$disknametarget set 1 boot on
            parted -s /dev/$disknametarget mkpart primary ext4 150Mib 100%
            cryptsetup luksFormat /dev/${disknametarget}${part2}
            cryptsetup open /dev/${disknametarget}${part2} cryptroot
            mkfs.vfat /dev/${disknametarget}${part1}
            mkfs.ext4 -L root /dev/mapper/cryptroot
            mount /dev/mapper/cryptroot /mnt
            mkdir -p /mnt/boot
            mount /dev/${disknametarget}${part1} /mnt/boot
        fi
}
create_partition () {
        if [[ $bootvar == "gpt" ]] ; then
            parted -s /dev/$disknametarget mklabel gpt
            parted -s /dev/$disknametarget mkpart fat32 1MiB 150MiB
            parted -s /dev/$disknametarget set 1 esp
            parted -s /dev/$disknametarget mkpart ext4 150MiB 100%
            mkfs.vfat /dev/${disknametarget}${part1}
            mkfs.ext4 /dev/${disknametarget}${part2}
            mount /dev/${disknametarget}${part2} /mnt
            mkdir -p /mnt/boot/efi
            mount /dev/${disknametarget}${part1} /mnt/boot/efi
        elif [[ $bootvar == "msdos" ]] ; then
            parted -s /dev/$disknametarget mklabel msdos
            parted -s /dev/$disknametarget mkpart primary ext4 1MiB 150MiB
            parted -s /dev/$disknametarget set 1 boot on
            parted -s /dev/$disknametarget mkpart primary ext4 150MiB 100%
            mkfs.ext4 /dev/${disknametarget}${part1}
            mkfs.ext4 /dev/${disknametarget}${part2}
            mount /dev/${disknametarget}${part2} /mnt
            mkdir -p /mnt/boot
            mount /dev/${disknametarget}${part1} /mnt/boot
        fi
}
essential_packages () {
        pacstrap /mnt base linux linux-firmware grub nano dhcpcd
        arch-chroot /mnt bash -c "systemctl enable dhcpcd.service"
        cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
}
detect_cpu () {
        varcpu="`grep -m 1 'model name' /proc/cpuinfo | grep -oh "Intel"`"
        if [[ $varcpu == "Intel" ]] ; then
            pacstrap /mnt intel-ucode
        else
            pacstrap /mnt amd-ucode
        fi
}
generate_fstab () {
        genfstab -U /mnt >> /mnt/etc/fstab
}
ask_set_timezone_region () {
        let i=0
        selectedtzr=()
        while read -r line; do
            let i=$i+1
            selectedtzr+=($line $i)
        done < <( ls -1 /usr/share/zoneinfo/ )
        tzregion=$(dialog --clear --stdout --title "SET TIMEZONE - REGION" --menu "Select REGION" 30 80 0 ${selectedtzr[@]})
}
ask_set_timezone_city () {
        let i=0
        selectedtzc=()
        while read -r line; do
            let i=$i+1
            selectedtzc+=($line $i)
        done < <( ls -1 /usr/share/zoneinfo/$tzregion )
        tzcity=$(dialog --clear --stdout --title "SET TIMEZONE - CITY" --menu "Select CITY" 30 80 0 ${selectedtzc[@]})
        arch-chroot /mnt bash -c "ln -sf /usr/share/zoneinfo/$tzregion/$tzcity /etc/localtime"
}
ask_set_localization () {
        let i=0
        looplistelement=()
        while read -r line; do
            let i=$i+1
            looplistelement+=($line)
        done < <( cat /mnt/etc/locale.gen | awk '{if (NR>=23) print}' | grep UTF-8 )
        definedlocales=$(dialog --clear --stdout --title "LOCALES" --menu "Select LOCALES" 30 80 0 ${looplistelement[@]})
        varutf8="`echo $definedlocales | cut -c2-`"
        sed -i "s|$definedlocales UTF-8|$varutf8 UTF-8|g" /mnt/etc/locale.gen
        arch-chroot /mnt bash -c "locale-gen"
}
set_localeconf () {
        setlocaleconf="`echo $definedlocales | awk '{print $1}' | cut -c2-`"
        arch-chroot /mnt bash -c "echo 'LANG=$setlocaleconf' >> /etc/locale.conf"
}
ask_set_keyboardlayoutmap () {
        setkeyboardtype=$(dialog --clear --title "SET KEYBOARD LAYOUT" --menu "Select Layout" 30 80 2 \
        "1" "AZERTY" \
        "2" "QWERTY" \
        "3" "QWERTZ" \
        2>&1 1>/dev/tty);
        if [[ $setkeyboardtype == "1" ]] ; then
                let i=0
                looplistelement=()
                while read -r line; do
                    let i=$i+1
                    looplistelement+=($line $i)
                done < <( ls -1 /usr/share/kbd/keymaps/i386/azerty | sed -n 's/\.map.gz$//p')
                setvconsole=$(dialog --clear --stdout --title "SET KEYBMAP" --menu "Select MAP" 30 80 0 ${looplistelement[@]})
                arch-chroot /mnt bash -c "echo 'KEYMAP=$setvconsole' >> /etc/vconsole.conf"
        elif [[ $setkeyboardtype == "2" ]] ; then
                let i=0
                looplistelement=()
                while read -r line; do
                    let i=$i+1
                    looplistelement+=($line $i)
                done < <( ls -1 /usr/share/kbd/keymaps/i386/qwerty | sed -n 's/\.map.gz$//p')
                setvconsole=$(dialog --clear --stdout --title "SET KEYMAP MAP" --menu "Select MAP" 30 80 0 ${looplistelement[@]})
                arch-chroot /mnt bash -c "echo 'KEYMAP=$setvconsole' >> /etc/vconsole.conf"
        elif [[ $setkeyboardtype == "3" ]] ; then
                let i=0
                looplistelement=()
                while read -r line; do
                    let i=$i+1
                    looplistelement+=("$line $i")
                done < <( ls -1 /usr/share/kbd/keymaps/i386/qwertz | sed -n 's/\.map.gz$//p')
                setvconsole=$(dialog --clear --stdout --title "SET KEYMAP MAP" --menu "Select MAP" 30 80 0 ${looplistelement[@]})
                arch-chroot /mnt bash -c "echo 'KEYMAP=$setvconsole' >> /etc/vconsole.conf"
        fi
}
ask_enter_username () {
        username=$(dialog --clear --title "USERNAME" --inputbox "Enter your Username" 30 80 3>&1 1>&2 2>&3 3>&-)
}
set_hostname () {
        arch-chroot /mnt bash -c "echo $username >> /etc/hostname"
        arch-chroot /mnt bash -c "echo '127.0.0.1     localhost $username' >> /etc/hosts"
        arch-chroot /mnt bash -c "echo '::1           localhost $username' >> /etc/hosts"
}
part1=1
part2=2
part3=3
# INSTALL BOOTLOADER GRUB
install_grub () {
        if [[ $bootvar == "gpt" ]] && [[ $encrypteddisk == "yes" ]] ; then
            arch-chroot /mnt bash -c "pacman -S --noconfirm --needed efibootmgr"
            uuidblk="`blkid -o value -s UUID /dev/${disknametarget}${part3}`"
            echo $uuidblk
            sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=$uuidblk:cryptroot root=\/dev\/mapper\/cryptroot\"|g" /mnt/etc/default/grub
            sed -i "s|#GRUB_ENABLE_CRYPTODISK=y|GRUB_ENABLE_CRYPTODISK=y|g" /mnt/etc/default/grub
            hookold="HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)"
            hooknew="HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)"
            sed -i "s|$hookold|$hooknew|g" /mnt/etc/mkinitcpio.conf
            arch-chroot /mnt bash -c "mkinitcpio -P linux"
            arch-chroot /mnt bash -c "grub-install --target=x86_64-efi --bootloader-id=EPJarchlinux --efi-directory=/boot/efi"
            arch-chroot /mnt bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
        elif [[ $bootvar == "gpt" ]] && [[ $encrypteddisk == "no" ]] ; then
            arch-chroot /mnt bash -c "pacman -S --noconfirm --needed efibootmgr"
            arch-chroot /mnt bash -c "grub-install --target=x86_64-efi --bootloader-id=EPJarchlinux --efi-directory=/boot/efi"
            arch-chroot /mnt bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
        elif [[ $bootvar == "msdos" ]] && [[ $encrypteddisk == "yes" ]] ; then
            uuidblk="`blkid -o value -s UUID /dev/${disknametarget}${part2}`"
            echo $uuidblk
            sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=$uuidblk:cryptroot root=\/dev\/mapper\/cryptroot\"|g" /mnt/etc/default/grub
            sed -i "s|#GRUB_ENABLE_CRYPTODISK=y|GRUB_ENABLE_CRYPTODISK=y|g" /mnt/etc/default/grub
            hookold="HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)"
            hooknew="HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)"
            sed -i "s|$hookold|$hooknew|g" /mnt/etc/mkinitcpio.conf
            arch-chroot /mnt bash -c "mkinitcpio -P linux"
            arch-chroot /mnt bash -c "grub-install --target=i386-pc /dev/$disknametarget"
            arch-chroot /mnt bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
        elif [[ $bootvar == "msdos" ]] && [[ $encrypteddisk == "no" ]] ; then
            arch-chroot /mnt bash -c "grub-install --target=i386-pc /dev/$disknametarget"
            arch-chroot /mnt bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
        fi
}
ask_define_userpwd () {
        arch-chroot /mnt bash -c "useradd -m $username"
        usernamepwd=$(dialog --clear --title "USER PASSWORD" --insecure --passwordbox "Enter $username Password" 30 80 3>&1 1>&2 2>&3 3>&-)
        arch-chroot /mnt bash -c "echo -e \"$usernamepwd\\n$usernamepwd\\n\" | passwd $username"
}
ask_define_rootpwd () {
        rootpwd=$(dialog --clear --title "SUPERUSER ROOT PASSWORD" --insecure --passwordbox "Enter the Superuser (root) PWD" 30 80 3>&1 1>&2 2>&3 3>&-)
        arch-chroot /mnt bash -c "echo -e \"$rootpwd\\n$rootpwd\\n\" | passwd"
}
clean_restart () {
        umount -R /mnt/boot/efi
        umount -R /mnt/boot
        umount -R /mnt
        reboot
}
prepare_setup
ask_select_mirrors
check_bootmode
update_systemclock
ask_check_diskname
ask_erase_disk
ask_encrypted_choice
essential_packages
detect_cpu
generate_fstab
ask_set_timezone_region
ask_set_timezone_city
ask_set_localization
set_localeconf
ask_set_keyboardlayoutmap
ask_enter_username
set_hostname
install_grub
ask_define_userpwd
ask_define_rootpwd
clean_restart
