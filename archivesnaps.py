#!/usr/bin/python3
#
# Run once a month to archive snapshot files of the previous month.
# Older files are also be picked up.
# Run in the middle of the month so 15 days of files will remain.
#
# Assumes the filename format is YYYYMMDDHHMMSSnnn.jpg. i.e. will
# automatically list in the creation order,
#
# Files in door directory are archived to archive/YYYYMM.n.door.tar.gz
# Files in drive directory are archived to archive/YYYYMM.n.drive.tar.gz
# Files successfully archived are removed from the door and drive dirs.
#
# Checks dirs 'archive', 'door', and 'drive' are present.
# Output should be logged to archive.log

import os
import re
from datetime import datetime

archiveDir  = "archive/"
fileListArg = 'filelist.arg.tmp'

#
# Generate a new archive filename. Assumption is that we
# are archivving the previous months snapshot files.
# Filename has YYYYMM prefix.
#
def getArchiveFilename(camera, dtCurrent):

    numMonths    = int(dtCurrent.strftime('%Y')) * 12 + int(dtCurrent.strftime('%m')) - 1
    numMonths   -= 1

    filePrefix   = "{:04d}{:02d}".format(int(numMonths / 12), int(numMonths % 12 + 1))
    fileTemplate = filePrefix+'.{}.{}.tar.gz'
    fileWildCard = fileTemplate.format('[0-9]+',camera)
    fileRegex    = re.compile(fileWildCard)

    lstArcFile   = [f for f in os.listdir(archiveDir) if fileRegex.match(f)]
    nextArcNum   = len(lstArcFile) + 1
    fileArcName  = fileTemplate.format(str(nextArcNum),camera)

    return fileArcName
    # End getArchiveFilename()

#
# Run os command with multiple arguements - possibly many using a tmp file
#
def performCommand(commandTmpl, lstArg):

    with open(fileListArg, 'w') as fp:
        fp.write('\n'.join(lstArg))

    strCommand = commandTmpl.format(fileListArg)
    print(strCommand)
    retNum = os.system(strCommand)
    return retNum
    # End performCommand()

#
# Create a tar,gz for previous months snapshot files
#
def performCameraArchive(camera):
    retNum       = 0
    dtCurrent    = datetime.now()
    strFileLimit = dtCurrent.strftime('%Y%m') + "00000000000.jpg"

    lstOldFile = [f for f in os.listdir(camera) if f < strFileLimit]

    if (0 < len(lstOldFile)):
        archiveFilename = getArchiveFilename(dtCurrent)

        cmdTar = "tar -cvzf {}{} --directory={} --files-from=".format(archiveDir,archiveFilename,camera)
        retNum = performCommand(cmdTar+"{}", lstOldFile)
 
        if (retNum != 0):
            print("Archive Command failed with ",retNum)
        else:
            retNum = performCommand("xargs -t -a {} rm", [camera+"/"+f for f in lstOldFile])

            if (retNum != 0):
                print("File remove Command failed with ",retNum)

    return retNum
    # End performCameraArchive()


performCameraArchive("door")

performCameraArchive("drive")

