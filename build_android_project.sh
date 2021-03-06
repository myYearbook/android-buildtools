#!/bin/bash

# This script can be invoked manually or by a jenkins job, and performs the
# the full Android build process with 'ant' for internal releases (signed with
# debug key) or external ones (signed with release key for Google, unsigned
# and converted market:// links for submission to Amazon).
#
# Usage
#
#   build_android_project.sh <ACTION> <WORKSPACE_DIR> [<RELATIVE_PROJECT_PATH>]
#
# Actions
#
#   --debug ..... build signed apk with debug key 
#   --release ... build signed apk with release key for google, unsigned apk  
#                 for amazon (with replaces market links) 
#
# Example Usage
#
#   # build project in current directory
#   build_android_project.sh --release .
#
#   # build project in ./source/ which references library in ./lib1/
#   build_android_project.sh --release . source
#
# Overview
#
#   1. checks that the Android project has all files in place
#   2. builds the current version
#   3. after building, the apk's are renamed to include 'debug' or 'release'
#      and 'Google' or 'Amazon' as well as the date, and can be found in bin/
#
# Amazon Market
#
#   Requires that all market:// links are replaced with links to Amazon's
#   website. This script automatically replaces all links and exits with
#   an error if there were links that couldn't be converted (which would
#   cause Amazon to reject the app submission.
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
# Author
#
#   Chris Hager (chris@metachris.org)
#
# Date
#
#   Feb, 2011
#
set -e  # make script fail if one command fails

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
if [ $# -lt 2 -o $1 != "--debug" -a $1 != "--release" ]; then
  echo "Use: $0 <ACTION> <WORKSPACE_DIR> [<RELATIVE_PROJECT_DIR>]"
  echo "Actions:"
  echo "    --debug ..... build apk signed with debug key"
  echo "    --release ... build release apk's for Google and Amazon"
  exit 1
fi

# readlink converts relative to absolute paths
WORKSPACEDIR=$( readlink -f "$2" )  # eg. TicTacToe
PROJECTDIR=$WORKSPACEDIR

TMP_WORKSPACEDIR="/tmp/google_to_amazon/$RANDOM"
TMP_PROJECTDIR=$TMP_WORKSPACEDIR
mkdir -p $TMP_WORKSPACEDIR  # required for readlink to work
if [ -n "$3" ]; then
  PROJECTDIR=$( readlink -f "$WORKSPACEDIR/$3" )
  TMP_PROJECTDIR=$( readlink -f "$TMP_WORKSPACEDIR/$3" )
fi

echo "workspace directory: $WORKSPACEDIR"
echo "project directory: $PROJECTDIR"

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
if [ "$1" = "--debug" ]; then
    cd "$PROJECTDIR"
    echo "\nBuilding debug apk..."
    $CMD_ANT clean debug
    
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
fi

# ======================
# build release versions
# ======================
if [ "$1" = "--release" ]; then
    echo "workspace_tmp: $TMP_WORKSPACEDIR"
    echo "project_tmp: $TMP_PROJECTDIR"

    echo
    echo "-------------------------------"
    echo "Building apk for Android market"
    echo "-------------------------------"
    echo
    
    # Android first
    cd "$PROJECTDIR"
    $CMD_ANT clean release
    
    # try to delete unaligned apks, if not found don't fail script
    rm bin/*-unaligned.apk 2>/dev/null || true
    
    # if signing key infos in build.properties we now have a release apk
    # and delete the unsigned one, else we keep the unsigned apk
    if [ -n "$( ls bin/*release*.apk 2>/dev/null || true )" ]; then
        rm bin/*-unsigned.apk 2>/dev/null || true
    fi
    
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
    echo "------------------------------"
    echo "Building apk for Amazon market"
    echo "------------------------------"
    echo
    
    # Clean temp dir
    #echo "- change to temporary directory"
    cd $TMP_WORKSPACEDIR  # already created at the beginning
    
    #echo "- copy project"
    cp -pr "$WORKSPACEDIR/"* .
    
    cd "$TMP_PROJECTDIR"
    # ant clean removes bin/ and gen/. Do before replacing market links
    $CMD_ANT clean

    echo
    echo "Replacing market:// links with Amazon counterparts"    
    echo "- searching for market://details?id="
    FILES_TO_UPDATE=$( grep "market://details?id=" * -Rl || true);
    for fn in $FILES_TO_UPDATE; do
      echo
      echo "Updating $fn"
      $CMD_SED 's/market:\/\/details?id=/http:\/\/www.amazon.com\/gp\/mas\/dl\/android\//g' $fn 
      diff $fn.bak $fn || true # diff returns 1 if files are not the same (catch with || false)
      rm $fn.bak
    done
    
    echo "- searching for market://search?q=pname:"
    FILES_TO_UPDATE=$( grep "market://search?q=pname:" * -Rl || true);
    for fn in $FILES_TO_UPDATE; do
      echo
      echo "Updating $fn"
      $CMD_SED 's/market:\/\/search?q=pname:/http:\/\/www.amazon.com\/gp\/mas\/dl\/android\//g' $fn 
      diff $fn.bak $fn || true # diff returns 1 if files are not the same (catch with || false)
      rm $fn.bak
    done
    
    echo "- searching for market://search?q=pub:"
    FILES_TO_UPDATE=$( grep "market://search?q=pub:" * -Rl || true);
    for fn in $FILES_TO_UPDATE; do
      echo
      echo "Updating $fn"
      $CMD_SED 's/market:\/\/search?q=pub:/http:\/\/www.amazon.com\/gp\/mas\/dl\/android?showAll=1\&p=/g' $fn 
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
    
    echo "Building Amazon apk now..."
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
fi

# cleanup temporary files created by 'android update project'
if [ $BUILDXML_CREATED ]; then
  rm "$PROJECTDIR/build.xml"
  rm "$PROJECTDIR/proguard.cfg"
fi

# cleanup temporary directory
rm -rf $TMP_WORKSPACEDIR
