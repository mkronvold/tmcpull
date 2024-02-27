#!/bin/bash

tempkey=9492       # set this to something unique to your scripts
tmps=1             # number of tmp files needed
DEBUG=

############ don't mess with these ###########
#
program=${0##*/}   # similar to using basename
confdir=$(dirname "$0")
[ $workdir ] || workdir=$confdir
[ -d $workdir ] || workdir=$confdir
#[ -f $confdir/bab.conf ] && source $confdir/bab.conf || die "No config file found in default location $confdir/bab.conf" 10
[ -f $confdir/babfunc.sh ] && source $confdir/babfunc.sh || die "$confdir/babfunc.sh not found" 11
mktmps
#
###############################################

# get config
#[ $listdir ] || warn "No listdir found in config" 10
#[ -d $listdir ] || listdir=$(pwd)

CSVLOOK=cat
CSVGREP=cat
CSVCUT=$(which csvcut || die "csvkit not found.  Install with: sudo pip install csvkit" )
GREPNAMES=
GREP=
REGEX=
COLUMN=1
work=
DRYRUN=
MKCSV=
BREAKPOINT=
DEBUG=

while [[ $# -gt 0 ]] && [[ "$1" == "--"* ]] ;
do
  opt=${1}
  case "${opt}" in
    "--" )
      break 2;;
    "--dry" ) DRYRUN=1;;
    "--dryrun" ) DRYRUN=1;;
    "--reqs"|"--requirements" ) [ $(which csvlook) ] && echo "csvkit found." || die "csvkit not found.  Install with: sudo pip install csvkit";;
    "--csv" ) MKCSV=1;;
    "--look"|"--csvlook" ) CSVLOOK=$(which csvlook || echo cat);;
    "--save="* )
      SAVE=1
      SAVEFILE="${opt#*=}";;
    "--test" ) DRYRUN=1;;
    "--debug" ) DEBUG=1 ;;
    "--break" ) BREAKPOINT=1;;
    "--tkcall" )
      GREP=
      COLUMN=1
      work=listtkcall ;;
    "--tkr" ) work=listtkr ;;
    "--tkrcount" ) work=counttkr ;;
    "--tns" )
      work=listtns
      COLUMN=2 ;;
    "--clusterdetails"|"--clusters"|"--tkc" ) work=listtkc ;;
    "--tkg"|"--mgmt"|"--management" ) work=listmgmt ;;
    "--workspaces"|"--wks" ) work=listworkspaces ;;
    "--unhealthy" ) work=unhealthy ;;
    "-n"|"--names"|"--columns" )
      GREPNAMES=1
      MKCSV=1
      ;;
    "--grep="* )
      GREP="${opt#*=}"
      MKCSV=1
      ;;
    "--regex="* )
      REGEX="${opt#*=}"
      MKCSV=1
      ;;
    "--column="* )
      COLUMN="${opt#*=}"
      ;;
    "--dev"|"--rnd"|"--development" ) GREP=dev ;;
    "--stg"|"--staging" ) GREP=stg ;;
    "--prod"|"--production" ) GREP=prod ;;
    "--dr" )
      MKCSV=1
      REGEX=den\|dr- ;;
    "--tnsdev" )
      MKCSV=1
      GREP=dev
      COLUMN=2
      work=listtns ;;
    "--tnsstg" )
      MKCSV=1
      GREP=stg
      COLUMN=2
      work=listtns ;;
    "--tnsprod" )
      MKCSV=1
      GREP=prod
      COLUMN=2
      work=listtns ;;
    "--tnsdr" )
      MKCSV=1
      GREP=dr
      COLUMN=2
      work=listtns ;;
    "--tkcdev" )
      MKCSV=1
      GREP=dev
      COLUMN=1
      work=listtkc ;;
    "--tkcstg" )
      MKCSV=1
      GREP=stg
      COLUMN=1
      work=listtkc ;;
    "--tkcprod" )
      MKCSV=1
      GREP=prod
      COLUMN=1
      work=listtkc ;;
    "--tkcdr" )
      MKCSV=1
      REGEX=den\|dr-
      COLUMN=1
      work=listtkc ;;
    "--ls="* )
      work=ls
      ls="${opt#*=}";;
    *)
    #   erm.  nothing here.
    ;;
  esac
  shift
done


#main
debug "tmps=$tmps"
debug "tmp()=${tmp[@]}"
debug "tmp[0]=${tmp[0]}"
debug "tmp[1]=${tmp[1]}"
[ $BREAKPOINT ] && die "DEBUG BREAKPOINT" 99

case "$work" in
  "listtkr" )
    debug "attempting to list tkrs of all tkcs"
    [ $GREP ] && CSVGREP="csvgrep -c $COLUMN -m $GREP" || CSVGREP=cat
    [ $REGEX ] && CSVREGEX="csvgrep -c $COLUMN -r $REGEX" || CSVREGEX=cat
    [ $GREPNAMES ] && CSVGREP="csvgrep -n"
    if [ $MKCSV ]; then
      if [ $SAVE ]; then
        echo "clustername,distribution" > $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
        tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name) \(.spec.tkgServiceVsphere.distribution.version)"' | awk -F+ '{print $1}' | $CSVGREP | $CSVREGEX | csvsort -c 2 | sed -e 's/\ /,/g' >> $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
      else
        ( echo "clustername,distribution" ;
        tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name) \(.spec.tkgServiceVsphere.distribution.version)"' | awk -F+ '{print $1}' | sed -e 's/\ /,/g' ) | $CSVGREP | $CSVREGEX | csvsort -c 2 | $CSVLOOK
      fi
    else
      tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name) \(.spec.tkgServiceVsphere.distribution.version)"' | awk -F+ '{print $1}'
    fi
    ;;
  "counttkr" )
    debug "attempting to count tkrs of all tkcs"
    [ $GREP ] && CSVGREP="csvgrep -c $COLUMN -m $GREP" || CSVGREP=cat
    [ $REGEX ] && CSVREGEX="csvgrep -c $COLUMN -r $REGEX" || CSVREGEX=cat
    tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name) \(.spec.tkgServiceVsphere.distribution.version)"' | awk -F+ '{print $1}' | sed -e 's/\ /,/g' | $CSVGREP | $CSVREGEX | csvstat -c 2 --freq --freq-count 25 | jq | sort | grep :
    ;;
  "listtkc" )
    debug "attempting to list tkc details"
    [ $GREP ] && CSVGREP="csvgrep -c $COLUMN -m $GREP" || CSVGREP=cat
    [ $REGEX ] && CSVREGEX="csvgrep -c $COLUMN -r $REGEX" || CSVREGEX=cat
    [ $GREPNAMES ] && CSVGREP="csvgrep -n"
    if [ $MKCSV ]; then
      if [ $SAVE ]; then
        echo "clustername,memorytotal,memorypercent,cputotal,cpupercent,nodecount,health,message" > $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
        tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name),\(.status.allocatedMemory.allocatable),\(.status.allocatedMemory.allocatedPercentage),\(.status.allocatedCpu.allocatable),\(.status.allocatedCpu.allocatedPercentage),\(.status.nodeCount),\(.status.health),\(.status.healthDetails.message)"' | $CSVGREP | $CSVREGEX >> $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
      else
        ( echo "clustername,memorytotal,memorypercent,cputotal,cpupercent,nodecount,health,message" ;
        tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name),\(.status.allocatedMemory.allocatable),\(.status.allocatedMemory.allocatedPercentage),\(.status.allocatedCpu.allocatable),\(.status.allocatedCpu.allocatedPercentage),\(.status.nodeCount),\(.status.health),\(.status.healthDetails.message)"' ) | $CSVGREP | $CSVREGEX | $CSVLOOK 2> /dev/null
      fi
    else
      tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name) \(.status.allocatedMemory.allocatable) \(.status.allocatedMemory.allocatedPercentage) \(.status.allocatedCpu.allocatable) \(.status.allocatedCpu.allocatedPercentage) \(.status.nodeCount) \(.status.health) \(.status.healthDetails.message)"'
    fi
    ;;
  "listtkcall" )
    debug "attempting to list all tkc details"
    [ $GREP ] && CSVGREP="csvgrep -c $COLUMN -m $GREP" || CSVGREP=cat
    [ $REGEX ] && CSVREGEX="csvgrep -c $COLUMN -r $REGEX" || CSVREGEX=cat
    [ $GREPNAMES ] && CSVGREP="csvgrep -n"
    echo "clustername,memorytotal,memorypercent,cputotal,cpupercent,nodecount,health,message" > .tmp-all.csv
    tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name),\(.status.allocatedMemory.allocatable),\(.status.allocatedMemory.allocatedPercentage),\(.status.allocatedCpu.allocatable),\(.status.allocatedCpu.allocatedPercentage),\(.status.nodeCount),\(.status.health),\(.status.healthDetails.message)"' >> .tmp-all.csv
    GREP=prod; cat .tmp-all.csv | csvgrep -c $COLUMN -m $GREP >> .tmp-${GREP}.csv
    GREP=dr ; REGEX=den\|dr-  ; cat .tmp-all.csv | csvgrep -c $COLUMN -r $REGEX >> .tmp-${GREP}.csv
    GREP=stg ; cat .tmp-all.csv | csvgrep -c $COLUMN -m $GREP >> .tmp-${GREP}.csv
    GREP=dev ; cat .tmp-all.csv | csvgrep -c $COLUMN -m $GREP >> .tmp-${GREP}.csv

    if [ $SAVE ]; then
      csvstack -n env -g prod,dr,stg,dev .tmp-prod.csv .tmp-dr.csv .tmp-stg.csv .tmp-dev.csv > $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
    else #nosave
      csvstack -n env -g prod,dr,stg,dev .tmp-prod.csv .tmp-dr.csv .tmp-stg.csv .tmp-dev.csv | $CSVREGEX | $CSVLOOK 2> /dev/null
    fi
    rm -f .tmp-prod.csv .tmp-dr.csv .tmp-stg.csv .tmp-dev.csv .tmp-all.csv
    ;;
  "listtns" )
    debug "attempting to list all tns by tkc"
    [ $GREP ] && CSVGREP="csvgrep -c $COLUMN -m $GREP" || CSVGREP=cat
    [ $REGEX ] && CSVREGEX="csvgrep -c $COLUMN -r $REGEX" || CSVREGEX=cat
    [ $GREPNAMES ] && CSVGREP="csvgrep -n"
    if [ $MKCSV ]; then
      if [ $SAVE ]; then
        ( echo "namespace,clustername,workspace,mgmtcluster" ;
        tanzu mission-control cluster namespace list -o json | jq -r '.namespaces[] | "\(.fullName.name),\(.fullName.clusterName),\(.spec.workspaceName),\(.fullName.managementClusterName)"' ) | $CSVGREP | $CSVREGEX | csvsort -c 4,2,3,1 > $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
      else
        ( echo "namespace,clustername,workspace,mgmtcluster" ;
        tanzu mission-control cluster namespace list -o json | jq -r '.namespaces[] | "\(.fullName.name),\(.fullName.clusterName),\(.spec.workspaceName),\(.fullName.managementClusterName)"' ) | $CSVGREP | $CSVREGEX | csvsort -c 4,2,3,1 | $CSVLOOK 2> /dev/null
      fi
    else
      ( echo "namespace,clustername,workspace,mgmtcluster" ;
      tanzu mission-control cluster namespace list -o json | jq -r '.namespaces[] | "\(.fullName.name),\(.fullName.clusterName),\(.spec.workspaceName),\(.fullName.managementClusterName)"' ) | $CSVGREP | $CSVREGEX | csvsort -c 4,2,3,1
    fi
    ;;
  "listmgmt" )
    debug "attempting to list all mgmt-clusters"
    debug "attempting to list all tkcs by tns"
    [ $GREP ] && CSVGREP="csvgrep -c $COLUMN -m $GREP" || CSVGREP=cat
    [ $REGEX ] && CSVREGEX="csvgrep -c $COLUMN -r $REGEX" || CSVREGEX=cat
    [ $GREPNAMES ] && CSVGREP="csvgrep -n"
    if [ $MKCSV ]; then
      if [ $SAVE ]; then
        echo "fullName,ClusterGroup,health,READYmessage" > $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
        tanzu mission-control management-cluster list -o json | jq -r '.managementClusters[] | "\(.fullName.name),\(.spec.defaultClusterGroup),\(.status.health),\(.status.conditions.READY.message)"' | $CSVGREP | $CSVREGEX | grep connected >> $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
      else
        ( echo "fullName,ClusterGroup,health,READYmessage" ;
        tanzu mission-control management-cluster list -o json | jq -r '.managementClusters[] | "\(.fullName.name),\(.spec.defaultClusterGroup),\(.status.health),\(.status.conditions.READY.message)"' | $CSVGREP | $CSVREGEX | grep connected ) | $CSVLOOK 2> /dev/null
      fi
    else
      tanzu mission-control management-cluster list
    fi
    ;;
  "listworkspaces" )
    debug "attempting to list all workspaces"
    [ $DRYRUN ] && echo "tanzu mission-control workspace list -o json | jq '.workspaces[].fullName.name'" || tanzu mission-control workspace list -o json | jq '.workspaces[].fullName.name'
    ;;
  "unhealthy" )
    debug "finding all unhealthy clusters"
    ( echo "clustername,nodecount,health,message" ;
      tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name),\(.status.nodeCount),\(.status.health),\(.status.healthDetails.message)"' ) | csvgrep -c 3 -r '^(?!HEALTHY$)' | $CSVLOOK 2> /dev/null
    ;;
  # "dev" )
  #   debug "finding all dev clusters"
  #   ( echo "clustername,memorytotal,memorypercent,cputotal,cpupercent,nodecount,health,message" ;
  #     tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name),\(.status.allocatedMemory.allocatable),\(.status.allocatedMemory.allocatedPercentage),\(.status.allocatedCpu.allocatable),\(.status.allocatedCpu.allocatedPercentage),\(.status.nodeCount),\(.status.health),\(.status.healthDetails.message)"' ) | $CSVGREP -c 1 -m dev | $CSVLOOK 2> /dev/null
  #   ;;
  # "stg" )
  #   debug "finding all stg clusters"
  #   ( echo "clustername,memorytotal,memorypercent,cputotal,cpupercent,nodecount,health,message" ;
  #     tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name),\(.status.allocatedMemory.allocatable),\(.status.allocatedMemory.allocatedPercentage),\(.status.allocatedCpu.allocatable),\(.status.allocatedCpu.allocatedPercentage),\(.status.nodeCount),\(.status.health),\(.status.healthDetails.message)"' ) | $CSVGREP -c 1 -m stg | $CSVLOOK 2> /dev/null
  #   ;;
  # "prod" )
  #   debug "finding all prod clusters"
  #   ( echo "clustername,memorytotal,memorypercent,cputotal,cpupercent,nodecount,health,message" ;
  #     tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name),\(.status.allocatedMemory.allocatable),\(.status.allocatedMemory.allocatedPercentage),\(.status.allocatedCpu.allocatable),\(.status.allocatedCpu.allocatedPercentage),\(.status.nodeCount),\(.status.health),\(.status.healthDetails.message)"' ) | $CSVGREP -c 1 -m prod | $CSVLOOK 2> /dev/null
  #   ;;
  # "dr" )
  #   debug "finding all dr clusters"
  #   ( echo "clustername,memorytotal,memorypercent,cputotal,cpupercent,nodecount,health,message" ;
  #     tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name),\(.status.allocatedMemory.allocatable),\(.status.allocatedMemory.allocatedPercentage),\(.status.allocatedCpu.allocatable),\(.status.allocatedCpu.allocatedPercentage),\(.status.nodeCount),\(.status.health),\(.status.healthDetails.message)"' ) | $CSVGREP -c 1 -m dr- | $CSVLOOK 2> /dev/null
  #   ;;
  *)
    die "nothing else to do" 100
    ;;
esac

cleanup
