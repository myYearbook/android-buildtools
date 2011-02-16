Common build tools for mobile apps

Android
=======

``build_android_project.sh`` is a shell script wrapper for Android's auto-generated build.xml. 
This script is triggered by hudson on a commit, and can also be run locally.

1. Checks project setup
2. Compiles apk (signed if keystore info is added to build.properties, see TicTacToe)
3. Runs google-to-amazon converter which adapts source to Amazon requirements (convert
Android market links to Amazon links) and outputs an unsigned apk
4. Appends date and time to filenames for archiving in hudson

Setting up a new Hudson/Jenkins Job
-----------------------------------

http://confluence.mybdev.com/display/DEVOPS/Setting+up+a+new+project+with+Gerrit+and+Jenkins-Hudson

* For an Android project, go to http://dev02.scs.myyearbook.com:8080/view/5.%20Android/
* "New Job" -> Enter job name and *set 'copy from' to 'TicTacToe'*
* Configure the job to your needs
