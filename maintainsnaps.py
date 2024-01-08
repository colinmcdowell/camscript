#!/usr/bin/python3
#
# Perform maintance to door and drive ftp directories
# IE prune files of the previous month and earier
# Output should be logged to copysnaps.log
# Should be run as user ftpuser under cron
#

import os
import re
from datetime import datetime, timedelta

#ftpdir="/home/ftpuser/ftp/"
ftpdir      = "/home/colinm/Documents/cameras/ftp/"
fileListArg = "maintain.arg.tmp"

#
# Generate list of ftp snapshot files older than given date
#
def gettListToPrune(camera,fileLimitTs):
    srcdir = ftpdir+camera

    # Match file with extraction of the timestamp
    reobj = re.compile(r"^.*_([0-9]{17})_MD_WITH_TARGET.jpg$")

    lstToPrune = []

    for file in os.listdir(srcdir):
        
        mat = reobj.match(file)
        if not mat:
            continue
        
        if mat.group(1) < fileLimitTs:
            lstToPrune.append(srcdir+'/'+file)

    return lstToPrune
    # End gettListToPrune

#
# Perform a system commnd with a list of arguements
# 
def performCommand(commandTempl, lstArg):

    with open(fileListArg, 'w') as fp:
        fp.write('\n'.join(lstArg))

    strCommand = commandTempl.format(fileListArg)
    print(strCommand)
    retNum = os.system(strCommand)
    return retNum
    # End performCommand()

#
# Prune door and drive camera files more than a week old
#
def performMaintain():
    dtCurrent   = datetime.now()
    dtLimit     = dtCurrent - timedelta(days=7)
    fileLimitTs = dtLimit.strftime('%Y%m%d')+'000000000'

    lstPruneDoor  = gettListToPrune("door", fileLimitTs)
    lstPruneDrive = gettListToPrune("drive",fileLimitTs)
    retNum = 0

    if 0<len(lstPruneDoor) or 0<len(lstPruneDrive):
        retNum = performCommand("xargs -t -a {} rm", [*lstPruneDoor, *lstPruneDrive])

        if (retNum == 0):
            print("Ftp file maintain completed ")
        else:
            print("Ftp file maintain failed with ",retNum)

    return retNum
    # End performMaintain()


performMaintain()


