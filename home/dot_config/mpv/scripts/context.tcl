# #############################################################
# Context menu constructed via CLI args. Mostly proof of concept.
# Avi Halachmi (:avih) https://github.com/avih
#
# Developed for and used in conjunction with context.lua - context-menu for mpv.
# See context.lua for more info.
#
# 2017-02-02 - Version 0.1 - initial version
# #############################################################

# Required when launching via tclsh, no-op when launching via wish
package require Tk  

# Remove the main window from the host window manager
wm withdraw .

if { $::argc < 4 } {
    puts "Usage: context.tcl x y item1 rv1 [item2 rv2 ...]"
    exit 1
}

# construct the menu from argv:
# - First pair is absolute x, y menu position, or under the mouse if -1, -1
# - The rest of the pairs are display-string, return-value-on-click.
#   If the return value is empty then the display item is disabled, but if the
#   display is "-" (and empty rv) then a separator is added instead of an item.
# - For now, return-value is expected to be a number, and -1 is reserved for cancel.
#
# On item-click/menu-dismissed, we print a json object to stdout with the
# keys x, y (menu absolute position) and rv (return value) - all numbers.
set RV_CANCEL -1
set m [menu .popupMenu -tearoff 0]
set first 1
foreach {disp rv} $::argv {
    if {$first} {
        set pos_x $disp
        set pos_y $rv
        set first 0
        continue
    }

    if {$rv == ""} {
        if {$disp == "-"} {
            $m add separator
        } else {
            $m add command -state disabled -label "$disp"
        }
    } else {
        $m add command -label "$disp" -command "done $rv"
    }
}

# Read the absolute mouse pointer position if we're not given a pos via argv
if {$pos_x == -1 && $pos_y == -1} {
    set pos_x [winfo pointerx .]
    set pos_y [winfo pointery .]
}

proc done {rv} {
    puts -nonewline "{\"x\":\"$::pos_x\", \"y\":\"$::pos_y\", \"rv\":\"$rv\"}"
    exit
}

# Seemingly, on both windows and linux, "cancelled" is reached after the click but
# before the menu command is executed and _a_sync to it. Therefore we wait a bit to
# allow the menu command to execute first (and exit), and if it didn't, we exit here.
proc cancelled {} {
    after 100 {done $::RV_CANCEL}
}

# Calculate the menu position relative to the Tk window
set win_x [expr {$pos_x - [winfo rootx .]}]
set win_y [expr {$pos_y - [winfo rooty .]}]

# Launch the popup menu
tk_popup .popupMenu $win_x $win_y

# On Windows tk_popup is synchronous and so we exit when it closes, but on Linux
# it's async and so we need to bind to the <Unmap> event (<Destroyed> or
# <FocusOut> don't work as expected, e.g. when clicking elsewhere even if the
# popup disappears. <Leave> works but it's an unexpected behavior for a menu).
# Note: if we don't catch the right event, we'd have a zombie process since no
#       window. Equally important - the script will not exit.
# Note: untested on macOS (macports' tk requires xorg. meh).
if {$tcl_platform(platform) == "windows"} {
    cancelled
} else {
    bind .popupMenu <Unmap> cancelled
}
