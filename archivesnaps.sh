#!/bin/bash
#
# Run once a month to archive snapshot files of the previous month.
# Older files are also be picked up.
# Run in the middle of the month so 15 days of files will remain.
#
# Assumes the filename format is YYYYMMDDHHMMSSnnn.jpg. i.e. will
# automatically list in the creation order,
#
# Files in door directory are archived to archive/YYYYMM_n.door.tar.gz
# Files in drive directory are archived to archive/YYYYMM_n.drive.tar.gz
# Files successfully archived are removed from the door and drive dirs.
#
# Checks dirs 'archive', 'door', and 'drive' are present.
# Output should be logged to archive.log

arc_month=`date +"%Y%m" -d "-1 months"`

echo "Starting snapshot archive for month $arc_month at "`date`

# Check archive present and create if not.
if [ ! -d "archive" ]; then
    mkdir archive
    if [ ! -d "archive" ]; then
        echo "Could not create 'archive'"
        exit 1
    fi
fi


# Generate unique door archive name for previous month
arc_door_number=`find archive -maxdepth 1 -name "$arc_month*.door.tar.gz" | wc -l`
arc_door_file=$arc_month"."$arc_door_number".door.tar.gz"
file_door_limit=`date +"%Y%m"`"00000000000"

# create or truncate file list
echo -n >listdoorfile.tmp

if [ ! -f "listdoorfile.tmp" ]; then
    echo "Could not create listdoorfile.tmp"
    exit 1
fi

if [ ! -d "door" ]; then
    echo "Directory 'door' is not present"
    exit 1
fi

# Generate list of files to be archived
for file in `find door -maxdepth 1 -type f -regextype egrep -regex "^.*[0-9]{17}\.jpg$" -printf "%f\n"`
do
    file_stamp=`echo $file | sed "s|^.*\([0-9]\{17\}\)\.jpg$|\1|"`
    #echo "file_stamp $file_stamp file_door_limit $file_door_limit"
    if [ "$file_stamp" -lt "$file_door_limit" ]; then
        echo $file >>listdoorfile.tmp
        echo "Adding to Archive list $file"
    fi
done

# If at least one file to archive
if [ -s listdoorfile.tmp  ]; then
    echo "Generating door archive for month "$arc_month
    tar -cvzf archive/$arc_door_file --directory=door --files-from=listdoorfile.tmp
    if [ $? -eq 0 ]; then
        echo "Archive door $arc_month successful. Removing archived files"
        sed "s|^\(.*\)$|door/\1|" listdoorfile.tmp | xargs -t rm
    fi
else
    echo "No door archive for month "$arc_month
fi

# Generate unique drive archive file name
arc_drive_number=`find -maxdepth 2 -path "*/archive/*" -name "$arc_month*.drive.tar.gz" | wc -l`
arc_drive_file=$arc_month"."$arc_drive_number".drive.tar.gz"
file_drive_limit=`date +"%Y%m"`"00000000000"

# create or truncate file list
echo -n >listdrivefile.tmp

if  [ ! -f "listdrivefile.tmp" ]; then
    echo "Could not create listdrivefile.tmp"
    exit 1
fi

if [ ! -d "drive" ]; then
    echo "Directory 'drive' is not present"
    exit 1
fi

# Files listed alphabetically
for file in `find drive -maxdepth 1 -type f -regextype egrep -regex "^.*[0-9]{17}\.jpg$" -printf "%f\n"`
do
    file_stamp=`echo $file | sed "s|^.*\([0-9]\{17\}\)\.jpg$|\1|"`
    if [ "$file_stamp" -lt "$file_drive_limit" ]; then
        echo $file >>listdrivefile.tmp
        echo "Adding to Archive list $file"
    fi
done

# If at least one file to archive
if [ -s listdrivefile.tmp  ]; then
    echo "Generating drive archive for month "$arc_month
    tar -cvzf archive/$arc_drive_file --directory=drive --files-from=listdrivefile.tmp
    if [ $? -eq 0 ]; then
        echo "Archive drive $arc_month successful. Removing archived files"
        sed "s|^\(.*\)$|drive/\1|" listdrivefile.tmp | xargs -t rm
    fi
else
    echo "No drive archive for month "$arc_month
fi


