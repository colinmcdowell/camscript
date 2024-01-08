#!/usr/bin/python3

import os
import re
import calendar
from datetime import datetime

#ftpdir="/home/ftpuser/ftp/"
ftpdir="/home/colinm/Documents/cameras/ftp/"
#camdir="/camera/"
camdir="/home/colinm/Documents/cameras/"

#
# Retrieve any ftped photos not already copied to camera directory
#
def retrieveFtpUpload(src="door"):
    srcdir = ftpdir+src
    dstdir = camdir+src

    # Match file with extraction of the timestamp
    reobj = re.compile(r"^.*_([0-9]{17})_MD_WITH_TARGET.jpg$")

    # map timestamp to orginal filename
    mapSource = { mtch.group(1):mtch.group() for mtch in 
          [ reobj.match(filename) for filename in os.listdir(srcdir) if reobj.search(filename)] }

    setDst = { f.removesuffix(".jpg") for f in os.listdir(dstdir) }

    countCopy = 0
    
    for (dst,src) in mapSource.items():
        if not (dst in setDst):
            print('cp '+srcdir+'/'+src+' '+dstdir+'/'+dst+'.jpg')
            #os.system('cp '+srcdir+'/'+src+' '+dstdir+'/'+dst+'.jpg')
            print('chmod 777 '+dstdir+'/'+dst+'.jpg')
            #os.system('chmod 777 '+dstdir+'/'+dst+'.jpg')
            countCopy += 1

    return countCopy
    # End retrieveFtpUpload()

#
# Convert string timestamp to epoche time.
# i.e. number of seconds since start of 1970
#
def parseEpoche(strTs):
    dt = datetime.strptime(strTs+'000','%Y%m%d%H%M%S%f')
    epoche = calendar.timegm(dt.timetuple())
    return epoche
    # End parseEpoche()

#
# Retrieve the snapshots for the last two camera events
# Two snapshots are part of the same event if they are
# within 10 seconds of each other
#
def groupSnapshot(src="door", maxGroups=2):
    dstdir = camdir+src

    lstDst = [ f.removesuffix(".jpg") for f in os.listdir(dstdir) ]
    lstDst.sort(reverse=True)

    if len(lstDst) < 3:
        return lstDst

    numGroups  = 0
    grpAll     = []
    grpCurrent = [lstDst[0]]
    ephLast    = parseEpoche(lstDst[0])

    for i in range(1,len(lstDst)):
        ephCurrent = parseEpoche(lstDst[i])

        if 10 <= ephLast-ephCurrent:
            grpCurrent.sort()
            grpAll.extend(grpCurrent)
            grpCurrent.clear()

            numGroups += 1
            if maxGroups < numGroups:
                break
        
        grpCurrent.append(lstDst[i])
        ephLast = ephCurrent

    return grpAll
    # End groupSnapshot()

#
# Generate header for html carouseling last two motion events
#
def generateHeader():
    return """<!DOCTYPE html>
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
"""
    # End generateHeader()

#
# Generate trailer for html carouseling last two motion events
#
def generateTrailer(pageTS, fileHtml):
    htmlTrail="""</body>
</html>

<script>

var pageTS = "--pageTS--";

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
  xhttp.open("GET", "--filehtml--.ts", true);
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
"""

    trailUpdate = htmlTrail.replace("--pageTS--",pageTS).replace("--filehtml--",fileHtml)
    return trailUpdate
    # End generateTrailer()

#
# Generate html to carousel last two motion events.
# html Javascript will make AJAX to check if there is an update
#
def generateCarousel(htmlFilename,lstFile):
    pageTS = datetime.now().strftime('%Y%m%d%H%M%S')
    ind    = 0

    # Truncate file
    os.system("echo -n >"+htmlFilename)

    with open(htmlFilename+'.ts', 'w') as fw:
        fw.write(pageTS)

    with open(htmlFilename, 'a') as fa:
        htmlHead = generateHeader()
        fa.write(htmlHead)

        for file in lstFile:
            fa.write("<div id='pic"+str(ind)+"' style='display:none'><img height='850' src='"+file+".jpg'/></div>\n")
            ind += 1

        trailUpdate = generateTrailer(pageTS, htmlFilename)
        fa.write(trailUpdate)
    # End generateCarousel()

#
# Cameras both ftp shapshots of new events. Copy new event files
# to the /camera directory. This includes renaming file with their
# creation timestamp. File timestamp down to milliseconds.
#
# If any new snapsshots retrieved then also regenerate the recent
# event html.
#
def runLatestEvent():
    countDoor  = retrieveFtpUpload("door")
    countDrive = retrieveFtpUpload("drive")

    if 0 < countDoor+countDrive:
        lstDoorTs  = groupSnapshot(src="door")
        lstDriveTs = groupSnapshot(src="drive")

        lstFile = [ *["door/"+ts for ts in lstDoorTs], *["drive/"+ts for ts in lstDriveTs] ]

        generateCarousel("lastEvent.html", lstFile)
    # End runLatestEvent()


runLatestEvent()

