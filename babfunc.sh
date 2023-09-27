#--------------------------------------------------------------------
mktmps () {
  tmp=()           # array of tmp files, refer to them as ${tmp[0]} thru ${tmp[tmps]}
                   # yes this always makes one extra tmp[0] as a spare intentionally
                   # change i=1 to change behavior to 0 to tmps-1
  for ((i=0; i<=tmps; i++));
  do
    tmpfile=$( mktemp /dev/shm/${tempkey}_${program}_tmp.XXXXXXXXXX )
    tmp+=($tmpfile)
  done
}

#--------------------------------------------------------------------
cleanup () {
     #  Delete temporary files, then optionally exit given status.
     local status=${1:-'0'}
#     rm -f ${tmp[@]}
     [[ $(which shred) ]] && shred --remove ${tmp[@]} || (dd if=/dev/urandom of=${tmp[@]} bs=1M count=100 ; rm -f ${tmp[@]} )
     [ $status = '-1' ] ||  exit $status      #  thus -1 prevents exit.
}

#--------------------------------------------------------------------
debug () {
     #  Message with DEBUG: to stderr.          Usage: debug "message"
     [ $DEBUG ] && echo -e "\n !! DEBUG: $1 "  >&2
}

#--------------------------------------------------------------------
warn () {
     #  Message with basename to stderr.          Usage: warn "message"
     echo -e "\n !!  ${program}: $1 "  >&2
}

#--------------------------------------------------------------------
dryrun () {
     # Message with DRYRUN: if $DRYRUN is set otherwise run it
     # Usage: dryrun "command"
     if [ $DRYRUN ]; then
       echo -e "\n -- DRYRUN: $1 "  >&1
     else
       IFS=' ' read -r -a command_arr <<< "${1}"
       "${command_arr[@]}"
     fi
}


#--------------------------------------------------------------------
die () {
     #  Exit with status of most recent command or custom status, after
     #  cleanup and warn.      Usage: command || die "message" [status]
     local status=${2:-"$?"}
     cleanup -1  &&   warn "$1"  &&  exit $status
}

#--------------------------------------------------------------------
trap "die 'SIG disruption, but cleanup finished.' 114" 1 2 3 15
#    Cleanup after INTERRUPT: 1=SIGHUP, 2=SIGINT, 3=SIGQUIT, 15=SIGTERM

#--------------------------------------------------------------------
#   Formats the specified number(s) according to the rules of the
#   current locale in terms of digit grouping (thousands separators).
# Usage:
#    groupDigits num ...
# Examples:
#   groupDigits 1000 # -> '1,000'
#   groupDigits 1000.5 # -> '1,000.5'
#   (LC_ALL=lt_LT.UTF-8; groupDigits 1000,5) # -> '1 000,5'
groupDigits() {
  local decimalMark fractPart
  decimalMark=$(printf "%.1f" 0); decimalMark=${decimalMark:1:1}
  for num; do
    fractPart=${num##*${decimalMark}}; [[ "$num" == "$fractPart" ]] && fractPart=''
    printf "%'.${#fractPart}f\n" "$num" || return
  done
}

#--------------------------------------------------------------------
# Calculate using bc
# usage:
#     calculate {options} expression
#               --scale=n  number of digits to return
# requires: bc
calculate()
{
    floatscale=1 #default
    result=
    expression=
    while [[ $# -gt 0 ]] && [[ "$1" == "--"* ]] ;
    do
        opt=${1}
        case "${opt}" in
            "--" )
                break 2;;
            "--scale="* )
                floatscale="${opt#*=}";;
            *)
            #   erm.  nothing here.
            ;;
        esac
        shift
    done
    expression=$*
    result=$(echo "scale=${floatscale}; ${expression}" | bc -q 2>/dev/null)
    printf '%*.*f' 0 "${floatscale}" "${result}"
}

#--------------------------------------------------------------------
# Draw a horizontal line the width of the terminal
# requires: tput
hr () { printf "%0$(tput cols)d" | tr 0 ${1:-=}; }

#--------------------------------------------------------------------
# csv output helper, see usage
csv()
{
  if [ ! "${1}" ]; then
    echo "Usage: csv [items] >> {file.csv}"
    echo "   [items] will be protected against embedded commas"
    echo "   example:"
    echo "   # csv 1 \"2 3 4 5\" \"6-7?8\" \"9,10\""
    echo "   1,2 3 4 5,6-7?8,\"9,10\""
    return
  fi
  #
  local items=("$@") # quote and escape as needed
                     # datatracker.ietf.org/doc/html/rfc4180
  for i in "${!items[@]}"; do
    if [[ "${items[$i]}" =~ [,\"] ]]; then
       items[$i]=\"$(echo -n "${items[$i]}" | sed s/\"/\"\"/g)\"
    fi
  done
  (
    IFS=,
    echo "${items[*]}"
  )
}

#--------------------------------------------------------------------
