This script performs the Android apk build process with 'ant' for both internal 
releases (signed with a debug key) and external ones (signed with release key 
for Google, unsigned and with converted market:// links for submission to Amazon).

**Usage**

    build_android_project.sh <ACTION> <WORKSPACE_DIR> [<RELATIVE_PROJECT_PATH>]

    Actions

      --debug ..... build signed apk with debug key 
      --release ... build signed apk with release key for google, unsigned apk  
                    for amazon (with replaces market links) 
    Example Usage

      # build project in current directory
      build_android_project.sh --release .

      # build project in ./source/ which references library in ./lib1/
      build_android_project.sh --release . source

**Overview**

1. checks that the Android project has all files in place
2. builds the current version
3. after building, the apk's are renamed to include 'debug' or 'release'
   and 'Google' or 'Amazon', as well as the current date and time. The 
   resulting apk's can be found in bin/

**Amazon Market**

Requires that all ``market://`` links are replaced with links to Amazon's
website. This script automatically replaces all links and exits with
an error if there were links that couldn't be converted (which would
cause Amazon to reject the app submission).

**Required files**

* ``default.properties`` (contains android-version to build for)

**Optional files**

* ``build.properties`` (may contain the keystore infos including
  passwords for alias and key to auto-sign the apk)

* ``build.xml`` files are ignored and replaced on hudson with the
  most current one from 'android update project'


**License**

New BSD License

**Contributors**

* Chris Hager
* Joe Hensche
