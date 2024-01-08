#!/bin/bash
#
# Shrewsbury camera script run every minute.
#
# (1) Retrieve any new snapshots send by the cameras
# These are stored at /camera/door /camera/drive until they are archived every month.
#
# (2) Generate latestevents.html that displays a carousel of most recent two events.
# The html contains an AJAX call that the browser uses to determine whether
# to reload the page.
#
# As per bash functions must be declared before they are called.
#

#
# Confirm a given directory exists.
# Create the directory if not present
#
function checkDirectory()
{
  dirname=$1

  if [ ! -d $dirname ]; then
    mkdir $dirname
    chmod 777 $dirname
    if [ ! -d $dirname ]; then
      echo "Directory '$dirname' is not present"
      exit 1
    fi
  fi
} # checkDirectory()


#
# Take file timestamp and convert to epoch seconds.
# As per bash function returned can be transferred via stdout
#
function parseEpoch()
{
  timeStamp=$1

  dateS=`echo "$timeStamp" | cut -c 1-8`
  hourS=`echo "$timeStamp" | cut -c 9-10`
  minS=`echo "$timeStamp" | cut -c 11-12`
  secS=`echo "$timeStamp" | cut -c 13-14`

  epoch=`date +"%s" -d "$dateS $hourS:$minS:$secS"`
  echo $epoch;
} # parseEpoch

#
# In a named directory group those snapshots close in time.
# Parameters are directory contenting the snapshot files,
# number of groups required to be returned,
# and the name of a file to write the snapshot names.
# The snapsshots filenames are in descenting order
# (processing most recent first).
# Files are named in the directory with timestamp only and jpg extension.
#
# A Group of snapshots representing an event are stored on a text line.
# A gap of 10 seconds between shapshots is considered a new event.
#
function groupSnapshot()
{
  directory=$1
  maxGroups=$2
  fileName=$3

  filesnaps=(`find $directory -maxdepth 1 -type f -regextype egrep -regex "^.*[0-9]{17}\.jpg$" -printf "%f\n" | sed "s|\.jpg$||" | sort -r`)

  lastepoch=0;
  declare -a crtgroup=()

  echo -n >$fileName

  if [ 0 -lt ${#filesnaps[@]} ]; then
    lastepoch=$(parseEpoch ${filesnaps[0]} );
    crtgroup+=(${filesnaps[0]})

    numgroups=0;

    for (( i=1; i<${#filesnaps[@]} && numgroups<maxGroups; i++ ));
    do
      crtepoch=$(parseEpoch ${filesnaps[$i]} );

      let diffepoch=$lastepoch-$crtepoch;

      if [ 10 -lt $diffepoch ]; then
        echo "${crtgroup[@]}" >>$fileName
        crtgroup=(${filesnaps[$i]})
        let "numgroups++"
      else
        crtgroup+=(${filesnaps[$i]})
      fi

      lastepoch=$crtepoch
    done
  fi
} # groupSnapshot


#
# Retrieve a number of snapshot events.
# Passed /camera subdirectory to process, number of groups required,
# and name of file to store the result.
#
function recentEvents()
{
  dirName=$1
  maxEvents=$2
  returnFile=$3

  tempFile=`echo "$returnFile" | sed "s|\.tmp$|.grp.tmp|"`
  echo -n >$tempFile;
  echo -n >$returnFile;

  groupSnapshot $dirName $maxEvents $tempFile

  # An event/group is on its own line.  Sort each line ascending order.
  while read -r line; do
    echo $line | sed "s/\s\+/\n/g" | sort >>$returnFile;
  done <$tempFile

  #rm $tempFile
} # recentEvents


#
# Generate html given a file of snapshot references.
# Also generates a small file containing the current timestamp.
# The browser can retrieve this file to determine if it should
# reload the page.
#
# Passed a file of the snapshot file references, and the name
# of the file to generate the html and script into.
#
function generateCarousel()
{
  filename=$1
  filehtml=$2

  cat >$filehtml <<EOF
<!DOCTYPE html>
<html>
<head>
<title>Door Page</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
  <!-- width: 100%; -->
<style>
#bodyId {
  background-color: #181818;
}
</style>
</head>
<body id="bodyId">
EOF

    ind=0;

    pageTS=`date +"%Y%m%d%H%M%S%3N"`

    echo -n "$pageTS" >"$filehtml.ts"

    for file in `cat $filename`
    do
        echo "<div id='pic"$ind"' style='display:none'><img height='850' src='"$file"'/></div>" >>$filehtml
        let "ind++"
    done

cat >>$filehtml <<EOF
</body>
</html>

<script>

var pageTS = "$pageTS";

function checkTimestamp(retrievedTS) {
  if (retrievedTS == pageTS) {
    console.log("Page not updated");
  } else {
    console.log("Page updated. Reloading");
    window.location.reload();
  }
}

function loadPageTimestamp() {
  var xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
    if (this.readyState == 4 && this.status == 200) {
      console.log("Response "+this.responseText);
      checkTimestamp(this.responseText);
    }
  };
  xhttp.open("GET", "$filehtml.ts", true);
  xhttp.send();
}

var ind = 0;

function slidePicture() {
  var pic_curr = document.getElementById("pic"+ind);
  ind = (ind + 1) % $ind;
  var pic_next = document.getElementById("pic"+ind);
  pic_curr.style.display = "none";
  pic_next.style.display = "block";
}

document.getElementById("pic0").style.display = "block";

setInterval(slidePicture, 3000);

setInterval(loadPageTimestamp, 20000);

</script>
EOF
} # generateCarousel()

#
# Grab two most recent events for both door and drive cameras.
# Generate html to carousel these events in a browser
#
function updateCarouselHtml()
{
  echo "Starting event html generation "`date`

  #checkDirectory door
  #checkDirectory drive

  recentEvents "door" 2 "last_event.door.1.tmp"

  sed "s|^\(.*\)$|door/\1.jpg|" last_event.door.1.tmp >last_event.door.2.tmp

  recentEvents "drive" 2 "last_event.drive.1.tmp"

  sed "s|^\(.*\)$|drive/\1.jpg|" last_event.drive.1.tmp >last_event.drive.2.tmp

  cat last_event.door.2.tmp last_event.drive.2.tmp >last_event_all.tmp

  generateCarousel last_event_all.tmp last_event.tmp.html

  #rm last_event.door.1.tmp last_event.door.2.tmp last_event.drive.1.tmp last_event.drive.2.tmp last_event_all.tmp
} # updateCarouselHtml

#
# Retrieve new snapshot files from ftp directories to /camera.
#
# Copy and permission update commands are written to a script
# file and run.
#
function retrieveFtpUpload()
{
  directory=$1

  ftpdir="/home/ftpuser/ftp/$directory"
  ftpfiles="ftpfiles.$directory.tmp"
  ftpfilesfull="ftpfiles.$directory.full.tmp"
  localfiles="localfiles.$directory.tmp"
  tobecopied="tobecopied.$directory.tmp"
  retrievesh="retrieve$directory.sh"

  if [ ! -d "$ftpdir" ]; then
      echo "Directory '$ftpdir' is not present"
      exit 1
  fi

  if [ ! -d "$directory" ]; then
      echo "Directory '$directory' is not present"
      exit 1
  fi

  # Generate list of files in the upload directory
  ls -1 $ftpdir/*.jpg >$ftpfilesfull
  sed "s|^$ftpdir/\(.*\)_\([0-9]\{17\}\)_MD_WITH_TARGET.jpg$|\2|" $ftpfilesfull | sort | uniq >$ftpfiles

  # Generate list of files already retrieved
  find $directory -name "*.jpg" | sed "s|^$directory/\([0-9]*\).jpg$|\1|" | sort | uniq >$localfiles

  # Generate list of files not retreived yet.
  comm -23 $ftpfiles $localfiles >$tobecopied

  echo -n >$retrievesh

  # Generate a shell script to copy the files if any found
  if [ -s $tobecopied  ]; then
      echo "#!/bin/bash" >$retrievesh
      echo "# GENERATED SHELL TO RETRIEVE $directory SNAPSHOTS" >>$retrievesh

      grep -f $tobecopied $ftpfilesfull | sed "s|^$ftpdir/\(.*\)_\([0-9]\{17\}\)_MD_WITH_TARGET.jpg$|cp -v $ftpdir/\1_\2_MD_WITH_TARGET.jpg $directory/\2.jpg|" >>$retrievesh

      # Make the snapshot available to other users on this host
      sed "s|^\(.*\)$|chmod 777 $directory/\1.jpg|" $tobecopied >>$retrievesh

      # Run it
      sh $retrievesh
  fi

  # Clean up
  #rm $ftpfiles $ftpfilesfull $localfiles $tobecopied
} # retrieveFtpUpload

#
# (1) Retrieve door and drive files.
#
# (2) If there were new events then re-generate the html script.
#
function runLatestEvent()
{
  doorshell="retrievedoor.sh"
  driveshell="retrievedrive.sh"

  echo "Starting event retrieve "`date`

  retrieveFtpUpload "door"
  retrieveFtpUpload "drive"

  if [ -s $doorshell ] || [ -s $driveshell ]; then
    updateCarouselHtml
  fi

  if [ -e $doorshell ]; then
    rm $doorshell
  fi

  if [ -e $driveshell ]; then
    rm $driveshell
  fi
}

cd /camera
runLatestEvent

