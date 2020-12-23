#!/usr/bin/env tclsh

# --------------------------------------------------------------------------
#  Variante d'exec qui capture les flux de sortie standard
# --------------------------------------------------------------------------
proc wexec { args } {
    puts "+ $args"
    exec {*}$args >@ stdout 2>@ stderr
}

# --------------------------------------------------------------------------
#  Récuperation de la sortie standard d'un programme
# --------------------------------------------------------------------------
proc stdout { args } {
    set fin [open "| $args" "r"]
    set res [read $fin]
    close $fin
    return [string trim $res]
}

# --------------------------------------------------------------------------
#  Exit with error message
# --------------------------------------------------------------------------
proc die {msg} {
    puts $msg
    exit 1
}

# --------------------------------------------------------------------------
#  Arrêt sur erreur
# --------------------------------------------------------------------------
proc dieif { cond msg } {
    if $cond {
	die $msg
    }
}

# --------------------------------------------------------------------------
#  Surcharge d'unknown qui execute les commandes shell
# --------------------------------------------------------------------------
proc unknown { args } {
    wexec {*}$args
}

# --------------------------------------------------------------------------
#  Verification de la presence d'un paquet debian
# --------------------------------------------------------------------------
proc checkpkg { pkg msg } {
    if { [catch {stdout dpkg -l $pkg} err] } {
	die $msg
    }
}

# --------------------------------------------------------------------------
#   Affiche un message d'aide et quitte
# --------------------------------------------------------------------------
proc usage { msg } {
    puts stderr "\n$::argv0 error: $msg"
    puts stderr "\nUsage:"
    puts stderr "\t$::argv0 -a <rootfs-tar> -d <disk>"
    exit 1
}

# -- verification que le lancement a lieu en root
dieif {[stdout id -u] != 0 } "Vous devez etre root pour lancer ce script !"

# -- verification que les paquets necessaires sont installes
checkpkg "extlinux"         "extlinux missing !"
checkpkg "syslinux-common"  "syslinux-common missing !"

# -- parsing des arguments
set failed [catch {
    array set ::PARAMS $argv
}]
if { $failed } {
    usage "Failed to parse command line"
}

# -- variables globales pour les arguments
set ::TGZ      $::PARAMS(-a)
set ::DISK     $::PARAMS(-d)

set ::MOUNT /mnt/payload

# -- recuperation de la liste de tous les process qui utilisent old_root
puts "Listing processes using ${DISK}"
set tokill [list]
set procs [glob /proc/*/exe ]
foreach p $procs {
    catch {
	set plink [file readlink $p]
	if { $plink eq "" } continue
	lassign [file split $plink] dummy root
	if { $root eq "old_root" } {
	    lassign [file split $p] dummy dummy pid
	    lappend tokill $pid
	}
    }
}

# -- arret brutal de tous les processus utilisant le disque
# -- qui va être flashé
puts "Killing processes using ${DISK}"
foreach p $tokill {
    catch { kill -9 $p }
}
# -- intentional second pass
foreach p $tokill {
    catch { kill -9 $p }
}

# -- effacement du disque
puts "Erase ${DISK}1 content"
sync
set fout [open /proc/sys/vm/drop_caches w]
puts $fout 3
close $fout
umount -l /old_root
mount ${DISK}1 /old_root
catch [list rm -rf {*}[glob /old_root/*]]

# -- untar file system
puts "Unpacking rootfs in ${MOUNT}"
fconfigure stdin -encoding binary -translation binary
tar -C /old_root/ -xzv

# -- install extlinux mbr
puts "Installing bootloader MBR"
dd bs=440 conv=notrunc count=1 if=/usr/lib/syslinux/mbr/mbr.bin of=${DISK}

# -- installation des menus extlinux
puts "Installing bootloader"
extlinux --install /old_root
set fout [open "/old_root/extlinux.conf" "w"]
puts $fout "default linux"
puts $fout "timeout 1"
puts $fout "label linux"
puts $fout "kernel /boot/vmlinuz-4.9.0-4-amd64"
puts $fout "append initrd=/boot/initrd.img-4.9.0-4-amd64 root=${DISK}1 net.ifnames=0"
close $fout

# -- syncing
sync
umount /old_root

# -- leaving
exit 0

