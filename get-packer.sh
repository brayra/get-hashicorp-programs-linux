#!/bin/bash

PROG=$(basename "$0")
PROG_DIR="$(dirname "$(realpath "$0")")"
BIN_DIR="$HOME/bin"
VERSION=
LIST_ONLY=0
LATEST=0
if ! UNZIP=$(which unzip) ; then
	echo "ERROR: please install unzip"
	exit 1
fi

usage()
{
echo "
usage: $PROG [Options] [VERSION]

   Download and install a version of terraform

   -h          : display this help
   -l          : list versions
   -L          : latest version
   -p          : destination path to install
"
}

while getopts ":lp:Lh" opt; do
  case $opt in
    l ) LIST_ONLY=1
       ;;
    L ) LATEST=1
       ;;
    p ) TDIR="${OPTARG}"
		if ! [ -d "$TDIR" ] ; then
			echo "ERROR: Unable to locate destination directory: $TDIR" >&2
			exit 1
		fi
		BIN_DIR="$TDIR"
		;;
    h ) usage
        exit 1
        ;;
    \?) usage
        exit 1
        ;;
  esac
done
shift $(($OPTIND -1))

# Check for root user
#if [ $UID -ne 0 ] ; then
#	echo "ERROR: Must be root!!!" >&2
#  exit 1
#fi

# Check argument count
#if [ $# -lt 1 ] ; then
#	echo "ERROR: Not enough arguments" >&2
#	usage
#	exit 1
#fi

if [ $# -gt 0 ] ; then
	VERSION="$1"
fi
#https://releases.hashicorp.com/packer/1.6.6/packer_1.6.6_linux_amd64.zip
VERSIONS=$(wget -O - -q https://releases.hashicorp.com/packer/|grep 'href="/packer/'|egrep -v '(rc|oci|alpha|beta)'|sed 's!^.*packer/\([^/]*\).*$!\1!g')

if [ $LIST_ONLY -eq 1 ] ; then
	echo "$VERSIONS"
	exit
fi

if [ "$VERSION" != "" ] ; then
	if ! echo "$VERSIONS" |grep -q "^${VERSION}$"  >/dev/null 2>&1 ; then
		echo "ERROR: Cannot locate the version: ${VERSION}" >&2
	fi
elif [ $LATEST -eq 1 ] ; then
	VERSION=$(echo "$VERSIONS"|head -1)
else
	if [ -z $DISPLAY ] ; then
		# there is no windowing enviroment. display text menu
		NUM=$( echo "$VERSIONS" | wc -l )
		declare -a vault_versions
		while true ; do
			clear
			COUNT=0
			echo "Please select a version:"
			while read id name ; do
				COUNT=$(( $COUNT + 1 ))
				vault_versions[$COUNT]=$id
				COLOR="\e[$(($COUNT % 2 * 2 * 10 + 7))m"
				printf "  ${COLOR}%2d  %s\n\e[0m" "$COUNT"  "$id"
			done < <(echo "${VERSIONS}")
			read -n 2 -p "Select a version: (1-$COUNT, q=quit)?" answer
			if [ $answer = "q" ] ; then 
				echo "User cancelled" >&2
				exit 1
			elif [ $answer -ge 1 ] && [ $answer -le $COUNT ] ; then
				VERSION=${vault_versions[$answer]}
				echo ""
				break
			fi
		done
	else
		VERSION=$(zenity --list --title="Select Version" --width=600 --height=400 --column="Version" $VERSIONS)
	fi


	if [ "$VERSION" = "" ] ; then
		echo "No version selected" >&2
		exit 1
	fi
fi


DOWNLOAD="https://releases.hashicorp.com/packer/${VERSION}/packer_${VERSION}_linux_amd64.zip"


tmp_dir=$(mktemp -d -t terraform-XXXXXXXXXX)
DEST="${tmp_dir}/packer${VERSION}_linux_amd64.zip"

RESULT=0
wget -O "${DEST}" "$DOWNLOAD"
if [ $? -eq 0 ] ; then
	ls -l "${DEST}"
	unzip -d "${tmp_dir}" "${DEST}"
  if [ -f "${tmp_dir}/packer" ] ; then
		cp "${tmp_dir}/packer" "${BIN_DIR}"
		echo "Installed version v${VERSION}"
	else
		echo "ERROR: Unable to extract version" >&2
		RESULT=1
	fi
else
	echo "ERROR: Failed to download version: ${VERSION}" >&2
	RESULT=1
fi

rm -rf "${tmp_dir}"
exit $RESULT
