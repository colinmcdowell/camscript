#!/bin/bash
#
# Perform maintance to door and drive ftp directories
# IE prune files of the previous month and earier
# Output should be logged to copysnaps.log
# Should be run as user ftpuser under cron
#

echo "Starting snapshot maintance at "`date`

file_limit=`date +"%Y%m%d" -d "-7 days"`"000000000"
echo "file_limit $file_limit"

echo -n >maintainfile.tmp

if [ ! -d "/home/ftpuser/ftp/door" ]; then
    echo "Directory '/home/ftpuser/ftp/door' is not present"
else
    for file in `find /home/ftpuser/ftp/door -type f -regextype egrep -regex "^.*[0-9]{17}_MD_WITH_TARGET\.jpg$"`
    do
        file_stamp=`echo "$file" | sed "s|^\(.*\)_\([0-9]\{17\}\)_MD_WITH_TARGET.jpg$|\2|"`
        # echo "file_stamp $file_stamp"
        if [ "$file_stamp" -lt "$file_limit" ]; then
            echo $file >>maintainfile.tmp
            echo "To Be Pruned $file"
        fi
    done
fi

if [ ! -d "/home/ftpuser/ftp/drive" ]; then
    echo "Directory '/home/ftpuser/ftp/drive' is not present"
else
    for file in `find /home/ftpuser/ftp/drive -type f -regextype egrep -regex "^.*[0-9]{17}_MD_WITH_TARGET\.jpg$"`
    do
        file_stamp=`echo "$file" | sed "s|^\(.*\)_\([0-9]\{17\}\)_MD_WITH_TARGET.jpg$|\2|"`
        #echo "file_stamp $file_stamp"
        if [ "$file_stamp" -lt "$file_limit" ]; then
            echo $file >>maintainfile.tmp
            echo "To Be Pruned $file"
        fi
    done
fi

if [ -s maintainfile.tmp  ]; then
    echo "Pruning old snapshot files at "`date`
    xargs -t -a maintainfile.tmp rm
else
    rm maintainfile.tmp
fi

