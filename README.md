Common build tools for mobile apps

Android
-------
``build_android_project.sh`` is a shell script wrapper for Android's auto-generated build.xml. 
This script is triggered by hudson on a commit, and can also be run locally.

1. Checks project setup
2. Compiles apk (signed if keystore info is added to build.properties, see TicTacToe)
3. Runs google-to-amazon converter which adapts source to Amazon requirements (convert
Android market links to Amazon links) and outputs an unsigned apk
4. Appends date and time to filenames for archiving in hudson
