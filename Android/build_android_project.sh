#!/bin/sh

#
# This script is invoked by jenkins/hudson and performs the 
# full Android build process (jenkins calls 'android update
# project' before invokind this script):
#
#   1. checks that the Android project has all files in place
#   2. builds the current version
#   3. runs the amazon converter script and build for amazon 
#   4. appends date to filenames
#   5. move all apk's into orig_dir/bin for hudson to archive
#
# Required files:
#
#   default.properties (contains android-version to build for)
#
# Optional files:
#
#   build.properties (may contain the keystore infos including 
#   passwords for alias and key to auto-sign the apk)
# 
#   build.xml files are ignored and replaced on hudson with the
#   most current one from 'android update project'
#
# Author: Chris Hager
# Date: Feb, 2011
#
# Todo:
# [ ] Amazon build: run zipalign (unsigned packages are not auto-aligned
#

set -e # make script fail if one command fails

DATE=$( date +"%Y-%m-%d_%H:%M" )

# OSX compatibility (Joe Hensche)
UNAME=$(uname)
if [ ${UNAME} = "Linux" ]; then
  CMD_SED="sed --in-place=.bak"
elif [ ${UNAME} = "Darwin" ]; then
  CMD_SED="sed -i .bak"
fi

CMD_ANT=ant
if [ ${ANT_HOME} ]; then
  # On jenkins use this ant
  CMD_ANT=${ANT_HOME}/bin/ant
fi

# Check for argument
if [ $# -lt 1 ]; then
  echo "Use: $0 PROJECT-DIR"
  exit 1
fi

# readlink converts relative to absolute paths
PROJECTDIR=$( readlink -f "$1" )
TMPDIR="/tmp/google_to_amazon/$RANDOM"

# make sure default.properties file is there (android min-sdk)
if [ ! -f "$PROJECTDIR/default.properties" ]; then
  echo "Error: $PROJECTDIR/default.properties not found. Is this the directory"
  echo "of a valid Android project? If so, please add default.properties to version control."
  exit 1
fi

# make sure build.xml is available (is always on hudson, as it runs
# android update project before invoking this script
if [ ! -f "$PROJECTDIR/build.xml" ]; then
  if [ -n $( which android 2>/dev/null ) ]; then
    android update project -p "$PROJECTDIR"
    BUILDXML_CREATED=1
  else
    echo "Error: Could not update project properties, command 'android' not found."
    exit 1
  fi
fi


# ====================================
# build normal android version (debug)
# ====================================
cd "$PROJECTDIR"
$CMD_ANT clean release

# try to delete unaligned apks, if not found don't fail script
rm bin/*-unaligned.apk 2>/dev/null || true

# Append date to output apk's
# Cannot do it with ls because it breaks with whitespaces in the filename
cd bin
find ./ -name "*.apk" -print0 | while read -d $'\0' fn
do
  FN_NEW=$( echo "$fn" | sed "s/.apk/-google-$DATE.apk/g" ) # $CMD_SED only works on files
  mv "$fn" "$FN_NEW"
done

# =========================================
# convert code to amazon-compatible version
# =========================================
echo
echo "--------------------------"
echo "Google-to-Amazon Converter"
echo "--------------------------"
echo "- working dir: $TMPDIR"

# Clean temp dir
echo "- change to temporary directory"
mkdir -p $TMPDIR
cd $TMPDIR

echo "- copy project"
cp -pr "$PROJECTDIR/"* .

# ant clean removes bin/ and gen/. Do before replacing market links
$CMD_ANT clean

echo "- searching for Android market links"
FILES_TO_UPDATE=$( grep "market://" * -Rl || true);
for fn in $FILES_TO_UPDATE; do
  echo
  echo "Updating $fn"
  $CMD_SED 's/market:\/\/details?id=/http:\/\/www.amazon.com\/gp\/mas\/dl\/android\//g' $fn 
  diff $fn.bak $fn || true # diff returns 1 if files are not the same (catch with || false)
  rm $fn.bak
done

echo

# Make sure all links were updated and none left (because of other format, etc)
# If links are left over, fail!
FILES_TO_UPDATE=$( grep "market://" * -Rl || true )
if [ $FILES_TO_UPDATE ]; then
  echo "Error: Could not convert all market:// links to amazon market links. Files:"
  grep "market://" src/* -RHn
  exit 1
fi

# Amazon market needs only unsigned apk's. remove build.properties
if [ -f build.properties ]; then
  rm build.properties
fi

echo "- building amazon apk version"
$CMD_ANT release

# try to delete unaligned apks, if not found don't fail script
rm bin/*-unaligned.apk 2>/dev/null || true

# Append date to output apk's
# Cannot do it with ls because it breaks with whitespaces in the filename
cd bin
find ./ -name "*.apk" -print0 | while read -d $'\0' fn
do
  FN_NEW=$( echo "$fn" | sed "s/.apk/-amazon-$DATE.apk/g" )
  mv "$fn" "$PROJECTDIR/bin/$FN_NEW"
done

# cleanup temporary files created by 'android update project'
if [ $BUILDXML_CREATED ]; then
  rm "$PROJECTDIR/build.xml"
  rm "$PROJECTDIR/proguard.cfg"
fi

# cleanup temporary directory
rm -rf $TMPDIR
