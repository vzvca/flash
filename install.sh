#!/usr/bin/env tclsh

# --------------------------------------------------------------------------
#  exec variant
# --------------------------------------------------------------------------
proc wexec { args } {
    puts "+ $args"
    exec {*}$args >@ stdout 2>@ stderr
}

# --------------------------------------------------------------------------
#  Run a program capturing its stdout
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
#  Assert like
# --------------------------------------------------------------------------
proc dieif { cond msg } {
    if $cond {
	die $msg
    }
}

# --------------------------------------------------------------------------
#  Custom unknown which runs its arguments
# --------------------------------------------------------------------------
proc unknown { args } {
    wexec {*}$args
}

# --------------------------------------------------------------------------
#  Check is a debian package is installed
# --------------------------------------------------------------------------
proc checkpkg { pkg msg } {
    if { [catch {stdout dpkg -l $pkg} err] } {
	die $msg
    }
}

# --------------------------------------------------------------------------
#   Print error message and infos about program usage then quit
# --------------------------------------------------------------------------
proc usage { msg } {
    puts stderr "\n$::argv0 error: $msg"
    puts stderr "\nUsage:"
    puts stderr "\t$::argv0 -f <payload-format> -d <disk>"
    exit 1
}

# -- Check if running as root
dieif {[stdout id -u] != 0 } "You must be root to run this script !"

# -- Check mandatory debian packages
checkpkg "extlinux"         "extlinux missing !"
checkpkg "syslinux-common"  "syslinux-common missing !"

# -- parse command line
set failed [catch {
    array set ::PARAMS $argv
}]
if { $failed } {
    usage "Failed to parse command line"
}

# -- global variables
set failed [catch {
    set ::FORMAT   $::PARAMS(-f)
    set ::DISK     $::PARAMS(-d)
}]
if { $failed } {
    usage "Failed to parse command line"
}

# -- Get list of process using /old_root
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

# -- Kill them !
puts "Killing processes using ${DISK}"
foreach p $tokill {
    catch { kill -9 $p }
}
# -- Intentional second pass
foreach p $tokill {
    catch { kill -9 $p }
}


if { $FMT eq "tgz" } {
    # -- Erase disk
    puts "Erase ${DISK}1 content"
    sync
    set fout [open /proc/sys/vm/drop_caches w]
    puts $fout 3
    close $fout
    umount -l /old_root
    mount ${DISK}1 /old_root
    catch [list rm -rf {*}[glob /old_root/*]]

    # -- untar file system
    puts "Unpacking rootfs in /old_root"
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
}

if { $FMT eq "img" } {
    # -- Erase disk
    puts "Erase ${DISK} content"
    sync
    umount -l /old_root

    # -- untar file system
    puts "Flashing image"
    fconfigure stdin -encoding binary -translation binary
    dd of=${DISK} bs=4096 status=progress
}

# -- leaving
exit 0

