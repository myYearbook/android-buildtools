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

set -e # make script fail if one command fails

DATE=$( date +"%Y-%m-%d_%H:%M" )

# OSX compatibility (Joe Hensche)
UNAME=$(uname)
if [ ${UNAME} = "Linux" ]; then
  CMD_SED="sed --in-place=.bak"
elif [ ${UNAME} = "Darwin" ]; then
  CMD_SED="sed -i .bak"
fi

# Check for argument
if [ $# -lt 1 ]; then
  echo "Use: $0 PROJECT-DIR"
  exit 1
fi

# readlink converts relative to absolute paths
PROJECTDIR=$( readlink -f "$1" )

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
    echo "Error: $PROJECTDIR/build.xml not found." 
    echo "       Cannot build, please add this file to version control."
    exit 1
  fi
fi


# ====================================
# build normal android version (debug)
# ====================================
cd "$PROJECTDIR"
ant clean release

rm bin/*-unaligned.apk

# Append date to output apk's
cd bin
FILES=$( ls *.apk )
for fn in $FILES; do
  FN_NEW=$( echo $fn | sed "s/.apk/-google-$DATE.apk/g" ) # $CMD_SED only works on files
  mv $fn $FN_NEW
done

# =========================================
# convert code to amazon-compatible version
# =========================================
echo
echo "--------------------------"
echo "Google-to-Amazon Converter"
echo "--------------------------"
echo "- working dir: /tmp/google_to_amazon/"

# Clean temp dir
echo "- clean"
cd /tmp
if [ -d google_to_amazon ]; then
  rm -rf google_to_amazon
fi

echo "- copy project"
mkdir google_to_amazon
cd google_to_amazon
cp -pr "$PROJECTDIR/"* .

echo "- searching for Android market links"
FILES_TO_UPDATE=$( grep "market://" src/* -Rl || true);
for fn in $FILES_TO_UPDATE; do
  echo
  echo "Updating $fn"
  $CMD_SED 's/market:\/\/details?id=/http:\/\/www.amazon.com\/gp\/mas\/dl\/android\//g' $fn 
  diff $fn.bak $fn || true # diff returns 1 if files are not the same (catch with || false)
  rm $fn.bak
done

# Amazon market needs only unsigned apk's. remove build.properties
if [ -f build.properties ]; then
  rm build.properties
fi

echo
echo "- building amazon apk version"
ant clean release

# Append date to output apk's
cd bin
FILES=$( ls *.apk )
for fn in $FILES; do
  FN_NEW=$( echo $fn | sed "s/.apk/-amazon-$DATE.apk/g" )
  mv $fn "$PROJECTDIR/bin/$FN_NEW"
done

# cleanup temporary files created by 'android update project'
if [ $BUILDXML_CREATED ]; then
  rm "$PROJECTDIR/build.xml"
  rm "$PROJECTDIR/proguard.cfg"
  echo "cleaned"
fi
