#!/bin/bash
 # /opt/scripts/mgmtBevo.sh
 # version 0.3.9 2014-12-05
 
 ### BEGIN INIT INFO
 # Provides:   minecraft
 # Required-Start: $local_fs $remote_fs screen-cleanup
 # Required-Stop:  $local_fs $remote_fs
 # Should-Start:   $network
 # Should-Stop:    $network
 # Default-Start:  2 3 4 5
 # Default-Stop:   0 1 6
 # Short-Description:    Minecraft server
 # Description:    Starts the minecraft server
 ### END INIT INFO
 
 #Settings
 SERVICE='forge-1.7.10-10.13.2.1272-universal.jar'
 OPTIONS='nogui'
 USERNAME='minecraft'
 WORLD='world'
 MCPATH='/opt/minecraft/bevo'
 LOG_FILE='/opt/scripts/log/'
 MAXHEAP=3072
 MINHEAP=1024
 HISTORY=1024
 CPU_COUNT=1
 INVOCATION="java -Xmx${MAXHEAP}M -Xms${MINHEAP}M \
 -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalPacing -XX:ParallelGCThreads=$CPU_COUNT -XX:+AggressiveOpts \
 -XX:MaxPermSize=256m -XX:PermSize=128M \
 -jar $SERVICE $OPTIONS"
 
 BACKUPENABLE=1
 BACKUPPLAYERONLINE=1
 BACKUPPATH='/opt/backup/bevo'
 BACKUPINTERVAL=30
 BACKUPDays=3
 
 STARTLOOP=1
 
 
 
 
 
 ME=`whoami`
 as_user() {
   if [ $ME == $USERNAME ] ; then
     bash -c "$1"
   else
     su - $USERNAME -c "$1"
   fi
 }
 
 log() {
 
   date=`date +"%Y-%m-%d"`   
   echo "[`date`] - ${*}" >> ${LOG_FILE}${date}.log
   echo ${*}
   
   yesterday=`date -d "-1 day" +"%Y-%m-%d"`
   
   if [ -f ${LOG_FILE}${yesterday}.log ]
   then
      gzip -9 ${LOG_FILE}${yesterday}.log
   fi
   
 }
 
 
 mc_start() {
   if  pgrep -u $USERNAME -f $SERVICE > /dev/null
   then
     echo "$SERVICE is already running!"
   else
     log "Starting $SERVICE..."
     cd $MCPATH
     chown -R $USERNAME:$USERNAME $MCPATH
     chmod -R 775 $MCPATH
     as_user "cd $MCPATH && screen -h $HISTORY -dmS minecraft $INVOCATION"
     sleep 7
     if pgrep -u $USERNAME -f $SERVICE > /dev/null
     then
       log "$SERVICE is now running."
     else
       log "Error! Could not start $SERVICE!"
     fi
   fi
 }
 
 mc_saveoff() {
   if pgrep -u $USERNAME -f $SERVICE > /dev/null
   then
     log "$SERVICE is running... suspending saves"
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"say SERVER BACKUP STARTING. Server may lag for a bit!\"\015'"
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"save-off\"\015'"
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"save-all\"\015'"
     sync
     sleep 10
   else
     log "$SERVICE is not running. Not suspending saves."
   fi
 }
 
 mc_saveon() {
   if pgrep -u $USERNAME -f $SERVICE > /dev/null
   then
     log "$SERVICE is running... re-enabling saves"
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"save-on\"\015'"
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"say SERVER BACKUP DONE. Next scheduled backup in $BACKUPINTERVAL minutes.\"\015'"
   else
     log "$SERVICE is not running. Not resuming saves."
   fi
 }
 
 mc_stop() {
   if pgrep -u $USERNAME -f $SERVICE > /dev/null
   then
     log "Stopping $SERVICE"
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"say SERVER SHUTTING DOWN. Saving map...\"\015'"
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"save-all\"\015'"
     sleep 2
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"stop\"\015'"
     sleep 10
   else
     log "$SERVICE was not running."
   fi
   if pgrep -u $USERNAME -f $SERVICE > /dev/null
   then
     log "Error! $SERVICE could not be stopped."
   else
     log "$SERVICE is stopped."
   fi
 } 
 
 
 mc_backup() {
 
   changedate=`expr $(date +%s -r /opt/minecraft/bevo/world/playerdata/$(ls -t /opt/minecraft/bevo/world/playerdata|head -n 1)) - $(date +%s -r /opt/backup/bevo/$(ls -t /opt/backup/bevo|head -n 1))`
   
   if [ $changedate -lt 100 ] && [ $BACKUPPLAYERONLINE == 1 ] && [ "$1" != "force" ]; then
      log "Skipping Backup because no Player was online..."
   else 
       
       time_start=$(date +"%s")       
       mc_saveoff
       
       DATE=`date "+%Y-%m-%d"`
       NOW=`date "+%Y-%m-%d_%Hh%M"`
       BACKUP_FILE="$BACKUPPATH/${WORLD}_${NOW}.tar"
       log "Backing up minecraft world..."
       
       if [ "$1" == "full" ]; then
         rm ${BACKUPPATH}/snapshot_${DATE}.dif
         as_user "tar --listed-incremental=\"${BACKUPPATH}/snapshot_${DATE}.dif\" -C \"$MCPATH\" -cf \"$BACKUP_FILE\" $WORLD"   
       else
         as_user "tar --listed-incremental=\"${BACKUPPATH}/snapshot_${DATE}.dif\" -C \"$MCPATH\" -cf \"$BACKUP_FILE\" $WORLD"
       fi
    
       mc_saveon
       
       log "Compressing backup..."
       as_user "bzip2 \"$BACKUP_FILE\""
       
       log "Deleting old Backup..."
       cd $BACKUPPATH
       
       OLDBACKUP=`date -d "-${BACKUPDays} days" "+%Y-%m-%d"`
       echo OLDBACKUP
       find ${BACKUPPATH} -name "${WORLD}_${OLDBACKUP}*.tar.bz2" -print0 | xargs -0 rm
       find ${BACKUPPATH} -name "snapshot_${OLDBACKUP}*.dif" -print0 | xargs -0 rm 
       log "Done."
       
       time_stop=$(date +"%s")       
       diff=$(($time_stop - $time_start))
       log "Backup took $(($diff / 60)) minutes and $(($diff % 60)) seconds."
    
   fi
  
    
 }
 
 
 mc_backup_service() {
 
   script=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/$(basename $0)
   tmp=${TMPDIR:-/tmp}/xyz.$$
   trap "rm -f $tmp; exit 1" 0 1 2 3 13 15
   crontab -l | sed "/$(basename $0) backup/d" > $tmp
   
   
   if [ $BACKUPENABLE == 1 ] ; then
      crontime=$(date -d "$BACKUPINTERVAL minutes" +"%M %H %d %m * %Y")
      echo "$crontime $script backup" >> $tmp
   fi
   
   crontab < $tmp
   rm -f $tmp
   trap 0
 }
 
 
  mc_restore() {
  
   echo
   echo "Restore from Backup:"
   echo   
   PS3='Please enter your choice: '
   
   cd $BACKUPPATH
   
   select file in *.bz2; do
      backup_filename=$file
      break
   done

   echo
   echo "The Server will be stoped to restore the backup."
   read -p "Are you sure you want to proceed? " -n 1 -r
   echo
   
   if [[ $REPLY =~ ^[Yy]$ ]]
   then
      log "Starting Restore of Backup $backup_filename"
      log "Stopping Server.."
          
          
          echo $backup_filename
   fi

 }
 
 
 mc_command() {
   command="$1";
   if pgrep -u $USERNAME -f $SERVICE > /dev/null
   then
     pre_log_len=`wc -l "$MCPATH/logs/latest.log" | awk '{print $1}'`
     log "$SERVICE is running... executing command"
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"$command\"\015'"
     sleep .3 # assumes that the command will run and print to the log file in less than .3 seconds
     # print output
     tail -n $[`wc -l "$MCPATH/logs/latest.log" | awk '{print $1}'`-$pre_log_len] "$MCPATH/logs/latest.log"
   fi
 }

 #Start-Stop here
 case "$1" in
   start)
     mc_start
     ;;
   startloop)
     mc_start_loop
     ;;
   stop)
     mc_stop
     ;;
   restart)
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"say Restart in 5 minutes \"\015'"
     sleep 1m
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"say Restart in 4 minutes \"\015'"
     sleep 1m
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"say Restart in 3 minutes \"\015'"
     sleep 1m
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"say Restart in 2 minutes \"\015'"
     sleep 1m
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"say Restart in 1 minutes \"\015'"
     sleep 50s
     as_user "screen -p 0 -x minecraft -X eval 'stuff \"say Restart in 10 seconds \"\015'"
     sleep 10s
     mc_stop
     mc_start
     ;;
   backup)
      if [ $# -gt 1 ]; then
       shift
       mc_backup "$*"
     else
       mc_backup
     fi
     ;;
   restore)
      if [ $# -gt 1 ]; then
       shift
       mc_restore "$*"
     else
       mc_restore
     fi
     ;;
   status) 
     if pgrep -u $USERNAME -f $SERVICE > /dev/null
     then
       echo "$SERVICE is running."
     else
       echo "$SERVICE is not running."
     fi
     ;;
   log)
     tail -f $MCPATH/logs/latest.log
     ;;
   fml)
     tail -f $MCPATH/logs/fml-server-latest.log
     ;;
   tps)
     mc_command "forge tps"
     ;;
   screen)
      as_user "/usr/bin/script -q -c 'screen -x minecraft' /dev/null"
      ;;
   command | cmd)
     if [ $# -gt 1 ]; then
       shift
       mc_command "$*"
     else
       echo "Must specify server command (try 'help'?)"
     fi
     ;;
 
   *)
   echo "Usage: $0 {start|stop|backup|status|restart|command \"server command\"}"
   exit 1
   ;;
 esac
 
 exit 0
