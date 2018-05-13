#!/usr/bin/wish

package require Tk
package require ctext
package require autoscroll

set COMPILE "./bin/fastspin"
set OUTPUT "--asm"
set EXT ".pasm"
set PORT ""
set makeBinary 0
set codemem hub
set datamem hub
set gasmode 1
set casemode 0
set LIBRARY ""
set cseoptimize 0
set usectypes 0

#
# read a file and return its text
# does UCS-16 to UTF-8 conversion
#
proc uread {name} {
    set encoding ""
    set f [open $name r]
    gets $f line
    if {[regexp \xFE\xFF $line] || [regexp \xFF\xFE $line]} {
	fconfigure $f -encoding unicode
	set encoding unicode
    }
    seek $f 0 start ;# rewind
    set text [read $f [file size $name]]
    close $f
    if {$encoding=="unicode"} {
	regsub -all "\uFEFF|\uFFFE" $text "" text
    }
    return $text
}

#
# reset anything associated with the output file and configuration
#
proc resetOutputVars { } {
    global OUTPUT
    global EXT
    global SPINFILE
    global PASMFILE
    
    set PASMFILE ""
    if { [string length $SPINFILE] != 0 } {
	regenOutput $SPINFILE
    }
}

# exit the program
proc exitProgram { } {
    checkChanges
    exit
}

# load a file into a text (or ctext) window
proc loadFileToWindow { fname win } {
    set file_data [uread $fname]
    $win replace 1.0 end $file_data
    $win edit modified false
}

# save contents of a window to a file
proc saveFileFromWindow { fname win } {
    set fp [open $fname w]
    set file_data [$win get 1.0 end]
    puts -nonewline $fp $file_data
    close $fp
    $win edit modified false
    regenOutput $fname
}

#
# tag text containing "error:" in a text widget w
#
proc tagerrors { w } {
    $w tag remove errtxt 0.0 end
    # set current position at beginning of file
    set cur 1.0
    # search through looking for error:
    while 1 {
	set cur [$w search -count length "error:" $cur end]
	if {$cur eq ""} {break}
	$w tag add errtxt $cur "$cur lineend"
	set cur [$w index "$cur + $length char"]
    }
    $w tag configure errtxt -foreground red
}

#
# recreate the compiled output
# spinfile is the name of the output file
#
proc regenOutput { spinfile } {
    global COMPILE
    global PASMFILE
    global OUTPUT
    global EXT
    global LIBRARY
    global makeBinary
    global codemem
    global datamem
    global gasmode
    global casemode
    global cseoptimize
    global usectypes
    
    set outname $PASMFILE
    if { [string length $outname] == 0 } {
	set dirname [file dirname $spinfile]
	set outname [file rootname $spinfile]
	set outname "$outname$EXT"
	set PASMFILE $outname
    }
    set errout ""
    set status 0
    if { $EXT eq ".pasm" } {
	set cmdline [list $COMPILE --noheader -g $OUTPUT --code=$codemem --data=$datamem]
	if { $cseoptimize ne 0 } {
	    set cmdline [concat $cmdline [list --cse]]
	}
    } else {
	set cmdline [list $COMPILE --noheader $OUTPUT]
	if { $gasmode ne 0 } {
	    set cmdline [concat $cmdline [list --gas]]
	}
	if { $casemode ne 0 } {
	    set cmdline [concat $cmdline [list --normalize]]
	}
	if { $usectypes ne 0 } {
	    set cmdline [concat $cmdline [list --ctypes]]
	}
    }
    if { $LIBRARY ne "" } {
	set cmdline [concat $cmdline [list -L $LIBRARY]]
    }
    if { $makeBinary == 1 } {
	set binfile [file rootname $PASMFILE]
	set binfile "$binfile.binary"
	if { $EXT eq ".pasm" } {
	    set cmdline [concat $cmdline [list --binary -o $binfile $spinfile]]
	} else {
	    set cmdline [concat $cmdline [list --binary -O -o $binfile $spinfile]]
	}
    } else {
	set cmdline [concat $cmdline [list -o $PASMFILE $spinfile]]
    }
    .bot.txt replace 1.0 end "$cmdline\n"
    set runcmd [list exec -ignorestderr]
    set runcmd [concat $runcmd $cmdline]
    lappend runcmd 2>@1
    if {[catch $runcmd errout options]} {
	set status 1
    }
    .bot.txt insert 2.0 $errout
    tagerrors .bot.txt
    if { $status != 0 } {
	tk_messageBox -icon error -type ok -message "Compilation failed" -detail "see compiler output window for details"
    }
}

set SpinTypes {
    {{Spin2 files}   {.spin2} }
    {{Spin files}   {.spin} }
    {{All files}    *}
}

proc checkChanges {} {
    if {[.orig.txt edit modified]==1} {
	set answer [tk_messageBox -icon question -type yesno -message "Save old spin file?" -default yes]
	if { $answer eq yes } {
	    saveSpinFile
	}
    }
}

proc getLibrary {} {
    global LIBRARY
    set LIBRARY [tk_chooseDirectory -title "Choose Spin library directory"]
}

proc newSpinFile {} {
    global SPINFILE
    set SPINFILE ""
    set PASMFILE ""
    checkChanges
    wm title . "New File"
    .orig.txt delete 1.0 end
    .bot.txt delete 1.0 end
}

proc loadSpinFile {} {
    global SPINFILE
    global SpinTypes
    checkChanges
    set filename [tk_getOpenFile -filetypes $SpinTypes -defaultextension ".spin2" ]
    if { [string length $filename] == 0 } {
	return
    }
    loadFileToWindow $filename .orig.txt
    .orig.txt highlight 1.0 end
    regenOutput $filename
    set SPINFILE $filename
    set PASMFILE ""
    wm title . $SPINFILE
}

proc saveSpinFile {} {
    global SPINFILE
    global PASMFILE
    global SpinTypes
    
    if { [string length $SPINFILE] == 0 } {
	set filename [tk_getSaveFile -initialfile $SPINFILE -filetypes $SpinTypes -defaultextension ".spin" ]
	if { [string length $filename] == 0 } {
	    return
	}
	set SPINFILE $filename
	set PASMFILE ""
    }
    
    saveFileFromWindow $SPINFILE .orig.txt
    wm title . $SPINFILE
}

proc saveSpinAs {} {
    global SPINFILE
    global SpinTypes
    set filename [tk_getSaveFile -filetypes $SpinTypes -defaultextension ".spin" ]
    if { [string length $filename] == 0 } {
	return
    }
    set SPINFILE $filename
    set PASMFILE ""
    wm title . $SPINFILE
    saveSpinFile
}

set aboutMsg {
GUI tool for .spin2
Version 3.8    
Copyright 2011-2018 Total Spectrum Software Inc.
------
There is no warranty and no guarantee that
output will be correct.    
}

proc doAbout {} {
    global aboutMsg
    tk_messageBox -icon info -type ok -message "Spin 2 GUI" -detail $aboutMsg
}

proc doHelp {} {
    if {[winfo exists .help]} {
	raise .help
	return
    }
    toplevel .help
    frame .help.f
    text .help.f.txt -wrap none -yscroll { .help.f.v set } -xscroll { .help.f.h set }
    scrollbar .help.f.v -orient vertical -command { .help.f.txt yview }
    scrollbar .help.f.h -orient horizontal -command { .help.f.txt xview }

    grid columnconfigure .help {0 1} -weight 1
    grid rowconfigure .help 0 -weight 1
    grid .help.f -sticky nsew
    
    grid .help.f.txt .help.f.v -sticky nsew
    grid .help.f.h -sticky nsew
    grid rowconfigure .help.f .help.f.txt -weight 1
    grid columnconfigure .help.f .help.f.txt -weight 1

    loadFileToWindow README.txt .help.f.txt
    wm title .help "Spin Converter help"
}

#
# set up syntax highlighting for a given ctext widget
proc setHighlightingSpin {w} {
    set color(keywords) blue
    set color(brackets) purple
    set color(numbers) DarkPink
    set color(operators) green
    set color(comments) grey
    set color(strings)  red
    set color(preprocessor) cyan
    set keywordsbase [list Con Obj Dat Var Pub Pri Quit Exit Repeat While Until If Then Else Return Abort Long Word Byte]
    foreach i $keywordsbase {
	lappend keywordsupper [string toupper $i]
    }
    foreach i $keywordsbase {
	lappend keywordslower [string tolower $i]
    }
    set keywords [concat $keywordsbase $keywordsupper $keywordslower]
    
    ctext::addHighlightClass $w keywords $color(keywords) $keywords
    ctext::addHighlightClassForSpecialChars $w brackets $color(brackets) {[](){}}
    ctext::addHighlightClassForSpecialChars $w operators $color(operators) {+-=><!@~\*/&:|}
    ctext::addHighlightClassForRegexp $w comments $color(comments) {\'[^\n\r]*}
    ctext::addHighlightClassForRegexp $w strings $color(strings) {"(\\"||^"])*"}
    ctext::addHighlightClassForRegexp $w preprocessor $color(preprocessor) {\#[a-z]+}
}

menu .mbar
. configure -menu .mbar
menu .mbar.file -tearoff 0
menu .mbar.edit -tearoff 0
menu .mbar.run -tearoff 0
menu .mbar.help -tearoff 0

.mbar add cascade -menu .mbar.file -label File
.mbar.file add command -label "New Spin File" -accelerator "^N" -command { newSpinFile }
.mbar.file add command -label "Open Spin..." -accelerator "^O" -command { loadSpinFile }
.mbar.file add command -label "Save Spin" -accelerator "^S" -command { saveSpinFile }
.mbar.file add command -label "Save Spin As..." -command { saveSpinAs }
.mbar.file add separator
.mbar.file add command -label "Library directory..." -command { getLibrary }
.mbar.file add separator
.mbar.file add command -label Exit -accelerator "^Q" -command { exitProgram }

.mbar add cascade -menu .mbar.edit -label Edit
.mbar.edit add command -label "Cut" -accelerator "^X" -command {event generate [focus] <<Cut>>}
.mbar.edit add command -label "Copy" -accelerator "^C" -command {event generate [focus] <<Copy>>}
.mbar.edit add command -label "Paste" -accelerator "^V" -command {event generate [focus] <<Paste>>}

.mbar add cascade -menu .mbar.run -label Run
.mbar.run add command -label "Run on device" -accelerator "^R" -command { doRun }

.mbar add cascade -menu .mbar.help -label Help
.mbar.help add command -label "Help" -command { doHelp }
.mbar.help add separator
.mbar.help add command -label "About..." -command { doAbout }

wm title . "Spin 2 GUI"

grid columnconfigure . {0 1} -weight 1
grid rowconfigure . 0 -weight 1
frame .orig
frame .bot

grid .orig -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky nsew
grid .bot -column 0 -row 1 -columnspan 2 -sticky nsew

scrollbar .orig.v -orient vertical -command {.orig.txt yview}
scrollbar .orig.h -orient horizontal -command {.orig.txt xview}
ctext .orig.txt -wrap none -xscroll {.orig.h set} -yscrollcommand {.orig.v set}
label .orig.label -background DarkGrey -foreground white -text "Spin"
grid .orig.label       -sticky nsew
grid .orig.txt .orig.v -sticky nsew
grid .orig.h           -sticky nsew
grid rowconfigure .orig .orig.txt -weight 1
grid columnconfigure .orig .orig.txt -weight 1

scrollbar .bot.v -orient vertical -command {.bot.txt yview}
scrollbar .bot.h -orient horizontal -command {.bot.txt xview}
text .bot.txt -wrap none -xscroll {.bot.h set} -yscroll {.bot.v set} -height 4
label .bot.label -background DarkGrey -foreground white -text "Compiler Output"

grid .bot.label      -sticky nsew
grid .bot.txt .bot.v -sticky nsew
grid .bot.h          -sticky nsew
grid rowconfigure .bot .bot.txt -weight 1
grid columnconfigure .bot .bot.txt -weight 1


bind . <Control-n> { newSpinFile }
bind . <Control-o> { loadSpinFile }
bind . <Control-s> { saveSpinFile }
bind . <Control-q> { exitProgram }
bind . <Control-r> { doRun }

autoscroll::autoscroll .orig.v
autoscroll::autoscroll .orig.h
autoscroll::autoscroll .bot.v
autoscroll::autoscroll .bot.h



###############################################################################
# Term for a simple terminal interface
###############################################################################
# The terminal bindings are implemented by defining a new bindtag 'Term'
###############################################################################

##################### Terminal In/Out events ############################
proc term_out { chan key } {
    switch -regexp -- $key {
	[\x07-\x08] -
	\x0D        -
	[\x20-\x7E] { puts -nonewline $chan $key; return -code break }
	[\x01-\x06] -
	[\x09-\x0C] -
	[\x0E-\x1F] -
	\x7F        { return }
	default     { return }
    } ;# switch
}

proc term_in { ch } {
    upvar #0 Term(Text) txt
    
    switch -regexp -- $ch {
	\x07    { bell }
	\x0A    {  } # ignore
	\x0D    { $txt insert end "\n" }
	default { $txt insert end $ch }
    }
    $txt see end
}

proc receiver {chan} {
    foreach ch [ split [read $chan] {}] {
	term_in $ch
    }
}

##################### Windows ############################
proc scrolled_text { f args } {
    toplevel $f
    eval {text $f.text \
	      -xscrollcommand [list $f.xscroll set] \
	      -yscrollcommand [list $f.yscroll set]} $args
    scrollbar $f.xscroll -orient horizontal \
	-command [list $f.text xview]
    scrollbar $f.yscroll -orient vertical \
	-command [list $f.text yview]
    grid $f.text $f.yscroll -sticky news
    grid $f.xscroll -sticky news
    grid rowconfigure    $f 0 -weight 1
    grid columnconfigure $f 0 -weight 1
    return $f.text
}

##### main #######

proc doRun {} {
    global PORT
    global makeBinary
    global PASMFILE
    global SPINFILE
    global Term

    if {[winfo exists .term]} {
	raise .term
    } else {
	set Term(Text) [scrolled_text .term -width 80 -height 25 -font $Term(Font) ]
    }
    if {$Term(Chan) ne ""} {
	close $Term(Chan)
	set Term(Chan) ""
    }
    set makeBinary 1
    regenOutput $SPINFILE
    set binfile [file rootname $PASMFILE]
    set binfile "$binfile.binary"

    set PORT [exec bin/propeller-load -Q]
    exec bin/propeller-load -r $binfile
    
    set Term(Port) $PORT
    set chan [open $Term(Port) r+]
    fconfigure $chan -mode $Term(Mode) -translation binary -buffering none -blocking 0
    fileevent $chan readable [list receiver $chan]
    set Term(Chan) $chan

    bind $Term(Text) <Any-Key> [list term_out $chan %A]

    wm title .term "Terminal Output"
    catch {console hide}
}


setHighlightingSpin .orig.txt

set PASMFILE ""
# Configure your serial port here
#
set Term(Port) com1
set Term(Mode) "115200,n,8,1"
set Term(Font) Courier
set Term(Chan) ""

# Global variables
#
set Term(Text) {}


if { $::argc > 0 } {
    loadFileToWindow $argv .orig.txt
    regenOutput $argv[1]
} else {
    set SPINFILE ""
}
