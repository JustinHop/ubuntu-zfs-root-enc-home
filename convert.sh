#!/bin/bash

set -euo pipefail

# Set some default values:
HELP=
KEYFILE=
RMKEYFILE=
NOOP=
SITESTRING=io.github.justinhop
VERBOSE=
ZFSUSER=

usage()
{
  echo "Usage: $0  [ -h | --help ]
  [ -k | --keyfile KEYFILE ]
  [ -n | --noop ]
  [ -r | --remove ]
  [ -v | --verbose ] ZFSUSER

  KEYFILE = Plain text passphrase in a file, should be the same as passwd for user
  noop    = No actions taken
  remove  = Remove inital unencrypted zfs volume for user, be careful
  ZFSUSER = Username of existing user with zfs mounted home dir"

  exit 2
}

PARSED_ARGUMENTS=$(getopt -a -n $0 -o hk:nrv --long help,keyfile:,noop,remove,verbose -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    -h | --help)    HELP=1          ; shift   ;;
    -k | --keyfile) KEYFILE="$2"    ; shift 2 ;;
    -n | --noop)    NOOP=echo       ; shift   ;;
    -r | --remove)  RMKEYFILE=1     ; shift   ;;
    -v | --verbose) VERBOSE=1       ; shift   ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Unexpected option: $1 - this should not happen."
    usage ;;
esac
done

if [ $HELP ]; then
  usage
  exit 2
fi

# BEGIN DEVELOPMENT SETTINGS
#NOOP=echo
#VERBOSE=1
#set -x
# END DEVELOPMENT SETTINGS

if [ $VERBOSE ]; then
  echo "PARSED_ARGUMENTS is $PARSED_ARGUMENTS"
  echo "HELP    : $HELP"
  echo "KEYFILE : $KEYFILE"
  echo "NOOP    : $NOOP"
  echo "VERBOSE : $VERBOSE"
  echo "Parameters remaining are: $@"
fi

PCMD=$NOOP
if [ $(whoami) != "root" ]; then
  # set stuff for non root users and make sure sudo works
  PCMD="$PCMD sudo"
  sudo true
fi

for ZFSUSER in $@; do
  [ $VERBOSE ] && echo "ZFSUSER : $ZFSUSER"
  ZUSER=$ZFSUSER
  ZUID=$(getent passwd $ZFSUSER | cut -d: -f3)
  ZGID=$(getent passwd $ZFSUSER | cut -d: -f4)
  ZHOME=$(getent passwd $ZFSUSER | cut -d: -f6)
  if [ $VERBOSE ]; then
    echo "ZUSER  : $ZUSER"
    echo "ZUID   : $ZUID"
    echo "ZGID   : $ZGID"
    echo "ZHOME  : $ZHOME"
  fi
  if ps -u $ZUID ; then
    echo "There are processes being run by $ZFSUSER UID=$ZUID GID=$ZGID."
    echo "Kill those processes and try again"
    exit 1
  else
    if [ $VERBOSE ]; then
      echo "Found no processes with UID=$ZUID"
    fi
  fi
  zfs get mountpoint -s local -H -o name,value | while read ZVOLNAME ZMOUNTPOINT; do
    [[ $ZMOUNTPOINT = $ZHOME ]] || continue

    ZVOLNAMENE=${ZVOLNAME}_noenc
    ZSNAPNAME=${ZVOLNAME}@premigrate2enc
    ZBOOTFS=$(zfs get com.ubuntu.zsys:bootfs-datasets $ZVOLNAME -s local -H -o value)
    if [ $VERBOSE ]; then
      echo "ZVOLNAME    : $ZVOLNAME"
      echo "ZVOLNAMENE  : $ZVOLNAMENE"
      echo "ZSNAPNAME   : $ZSNAPNAME"
      echo "ZMOUNTPOINT : $ZMOUNTPOINT"
      echo "ZBOOTFS     : $ZBOOTFS"
    fi
    if ! [ $KEYFILE ] || ! [ -f $KEYFILE ] ; then
      read -s -p "Encryption key for $ZUSER, should be same as password:" ZPASSPHRASE
      RMKEYFILE=1
      KEYFILE=$(mktemp)
      export KEYFILE
      export ZPASSPHRASE
      bash -c 'cat > $KEYFILE <<< $ZPASSPHRASE'
    fi
    $PCMD zfs rename $ZVOLNAME $ZVOLNAMENE
    $PCMD zfs set mountpoint=none $ZVOLNAMENE
    $PCMD zfs snapshot $ZSNAPNAME
    ZCMD="$PCMD zfs send -v -c $ZVOLNAMENE | $PCMD zfs recv -v -o encryption=aes-256-gcm -o keyformat=passphrase -o keylocation=file://$KEYFILE -o mountpoint=$ZHOME -o com.ubuntu.zsys:bootfs-dataset=$ZBOOTFS $ZVOLNAME"
    if [ $NOOP ]; then
      echo "$ZCMD"
    else
      eval $ZCMD
    fi
    $PCMD zfs set keylocation=prompt $ZVOLNAME
    $PCMD zfs set canmount=noauto $ZVOLNAME
    $PCMD zfs set ${SITESTRING}:user=$ZUSER $ZVOLNAME
    $PCMD chown -Rh $ZUID:$ZGID $ZHOME
    if [ $RMKEYFILE ]; then
      $PCMD shred $KEYFILE
      $PCMD rm $KEYFILE
    fi
  done
done
