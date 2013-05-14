#!/bin/sh

#
#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

#Knox PID
PID=0

#start, stop or status
KNOX_LAUNCH_COMMAND=$1

#start/stop script location
KNOX_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#App name
KNOX_NAME=knox

#The Knox's jar name
KNOX_JAR="$KNOX_SCRIPT_DIR/server.jar"

#Name of PID file
PID_DIR="/var/run/$KNOX_NAME"
PID_FILE="$PID_DIR/$KNOX_NAME.pid"
PID_PERM_FILE="$PID_DIR/$KNOX_NAME.perm"

#Name of LOG/OUT/ERR file
LOG_DIR="/var/log/$KNOX_NAME"
OUT_FILE="$LOG_DIR/$KNOX_NAME.out"
ERR_FILE="$LOG_DIR/$KNOX_NAME.err"
LOG_PERM_FILE="$LOG_DIR/$KNOX_NAME.perm"

#The max time to wait
MAX_WAIT_TIME=10

function main {
   case "$1" in
      start)  
         knoxStart
         ;;
      stop)   
         knoxStop
         ;;
      status) 
         knoxStatus
         ;;
      clean) 
         knoxClean
         ;;
      *)
         printf "Usage: $0 {start|stop|status|clean}\n"
         ;;
   esac
}

function knoxStart {
   prepareEnv

   getPID
   if [ $? -eq 0 ]; then
     printf "Knox is already running with PID=$PID.\n"
     return 0
   fi
  
   printf "Starting Knox "
   
   rm -f $PID_FILE

   echo $KNOX_JAR
   echo $ERR_FILE
   echo $PID_FILE
   nohup java -jar $KNOX_JAR >> $OUT_FILE 2>>$ERR_FILE & printf $! >$PID_FILE "\n"|| return 1
   
   getPID
   knoxIsRunning $PID
   if [ $? -ne 1 ]; then
      printf "failed.\n"
      return 1
   fi

   printf "succeed with PID=$PID.\n"
   return 0
}

function knoxStop {
   getPID
   knoxIsRunning $PID
   if [ $? -eq 0 ]; then
     printf "Knox is not running.\n"
     return 0
   fi
  
   printf "Stopping Knox [$PID] "
   knoxKill $PID >>$OUT_FILE 2>>$ERR_FILE 

   if [ $? -ne 0 ]; then 
     printf "failed. \n"
     return 1
   else
     rm -f $PID_FILE
     printf "succeed.\n"
     return 0
   fi
}

function knoxStatus {
   printf "Knox "
   getPID
   if [ $? -eq 1 ]; then
     printf "is not running. No pid file found.\n"
     return 0
   fi

   knoxIsRunning $PID
   if [ $? -eq 1 ]; then
     printf "is running with PID=$PID.\n"
     return 1
   else
     printf "is not running.\n"
     return 0
   fi
}

# Removed the Knox PID file if Knox is not run
function knoxClean {
   getPID
   knoxIsRunning $PID
   if [ $? -eq 0 ]; then 
     rm -f $PID_FILE
     printf "Removed the Knox PID file: $PID_FILE.\n"
     
     rm -f $OUT_FILE
     printf "Removed the Knox OUT file: $OUT_FILE.\n"
     
     rm -f $ERR_FILE
     printf "Removed the Knox ERR file: $ERR_FILE.\n"
     return 0
   else
     printf "Can't clean files the Knox is run with PID=$PID.\n" 
     return 1    
   fi
}

# Returns 0 if the Knox is running and sets the $PID variable.
function getPID {
   if [ ! -f $PID_FILE ]; then
     PID=0
     return 1
   fi
   
   PID="$(<$PID_FILE)"
   return 0
}

function knoxIsRunning {
   if [ -e /proc/$1 ]; then return 1; fi
   return 0
}

function knoxKill {
   local localPID=$1
   kill $localPID || return 1
   for ((i=0; i<MAX_WAIT_TIME*10; i++)); do
      knoxIsRunning $localPID
      if [ $? -eq 0 ]; then return 0; fi
      sleep 0.1
   done   

   kill -s KILL $localPID || return 1
   for ((i=0; i<MAX_WAIT_TIME*10; i++)); do
      knoxIsRunning $localPID
      if [ $? -eq 0 ]; then return 0; fi
      sleep 0.1
   done

   return 1
}

function prepareEnv {
   if [ ! -d "$PID_DIR" ]; then mkdir -p $PID_DIR; fi
   if [ ! -d "$LOG_DIR" ]; then mkdir -p $LOG_DIR; fi
   if [ ! -f "$OUT_FILE" ]; then touch $OUT_FILE; fi
   if [ ! -f "$ERR_FILE" ]; then touch $ERR_FILE; fi   
}

#Starting main
main $KNOX_LAUNCH_COMMAND