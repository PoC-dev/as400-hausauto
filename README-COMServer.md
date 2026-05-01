The Wiesemann & Theis COMServer 50210 is a very old Ethernet connected digital I/O device. With a proprietary UDP based protocol you can read from, and write to "registers", to get the status of the pins. In addition, the 50210 can be told to send an unsolicited UDP packet to a configurable IP address on every state change, containing the current state of the input registers.

This document is part of the AS/400 house automation program collection, to be found on [GitHub](https://github.com/PoC-dev/as40-hausauto) - see there for further details. Its content is subject to the [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) license, also known as *Attribution-ShareAlike 4.0 International*.

## How the COMserver related jobs are meant to run
First, the applications are meant to run in a separate subsystem, so they can be easily started at IPL time. Second, the applications are meant to run with a separate user profile solely for that purpose.

The instructions assume you are signed on to a 5250 session as QSECOFR or some user with equivalent rights.

> ***Note:*** Lines which end in a + sign are continued on the next line!

First, create a new library to hold all the needed objects. Change thereto.
```
crtlib lib(hausauto) text('Hausautomation')
chgcurlib curlib(hausauto)
chgsrcpf file(sources)
```

Next, create a user profile for the programs to run with.
```
crtusrprf usrprf(hausauto) password(*none) curlib(hausauto) lmtcpb(*yes) +
  text('Hausautomation')
```

Now we can create the run time environment objects.
```
crtsbsd sbsd(*curlib/hausauto) pools((1 *base)) syslible(hausauto) +
  text('Hausautomation Subsystem')
crtjobq jobq(*curlib/haustasks) autchk(*dtaaut)
crtjobd jobd(*curlib/comrecv) jobq(hausauto/haustasks) user(hausauto) +
  rtgdta(comrecv) rqsdta('call pgm(hausauto/comrecv)') +
  text('Start COMrecv *pgm')
crtjobd jobd(*curlib/comcpyrcd) jobq(hausauto/haustasks) user(hausauto) +
  rtgdta(comcpyrcd) rqsdta('call pgm(hausauto/comcpyrcd)') +
  text('Start COMcpyrcd *pgm')
crtcls cls(*curlib/comrecv) runpty(5) timeslice(100) purge(*no) +
  text('Class for running the power calculator')
crtdtaq dtaq(*curlib/comtmp) maxlen(32) +
  text('Temporary data store for entries from COMserver')
```

Next, we need to modify the subsystem description we've created earlier.
- Add entries for actual auto start
- Add a job queue: Each job is placed in a queue for the SBS to pick it up
- Add routing entries to match against the JOBD's RTGDTA to add run time  attributes. We want COMRECV to run in a very high priority so there is the  least delay in calculating power.
```
addaje sbsd(*curlib/hausauto) job(comrecv) jobd(*curlib/comrecv)
addaje sbsd(*curlib/hausauto) job(comcpyrcd) jobd(*curlib/comcpyrcd)
addjobqe sbsd(*curlib/hausauto) jobq(*curlib/haustasks) maxact(*nomax)
addrtge sbsd(*curlib/hausauto) seqnbr(10) cmpval('comrecv') pgm(qcmd) +
  cls(*curlib/comrecv)
addrtge sbsd(*curlib/hausauto) seqnbr(99) cmpval(*any) pgm(qcmd) +
  cls(*libl/qbatch)
```

### Files: Naming and upload
```
Repository name    MBR Name and Type
-------------------------------------
compf.dds          COMPF        PF
comportpf.dds      COMPORTPF    PF
comprefspf.dds     COMPREFSPF   PF
comcpydcd.rpgle    COMCPYRCD    RPGLE
comrecv.c          COMRECV      C
strcomcpyr.clp     STRCOMCPYR   CLP
strcomrecv.clp     STRCOMRECV   CLP
```

Upload these files with any FTP client **in ASCII mode** into HAUSAUTO/SOURCES. Then set their file type with WRKMBRPDM in the 5250 session as shown above. Now you can just type 14 beneath the objects to create them.

> **Note!** You need to create the physical files first, because they are referenced in the programs. When the objects don't exist and you try to compile the programs, compilation will fail.

Now you can start the subsystem with `STRSBS SBSD(HAUSAUTO)`. You should see the jobs run in WRKACTJOB:
```
Opt   Subsystem/Job  User        Type CPU %  Function        Status
 __   HAUSTASKS      QSYS        SBS    0,0                   DEQW
 __     COMCPYRCD    HAUSAUTO    ASJ    0,0  PGM-COMCPYRCD    RUN
 __     COMRECV      HAUSAUTO    ASJ    0,0  PGM-COMRECV      RUN
```

After no more than one minute has passed, you should be able to see records in `strsql` when commanding `SELECT * FROM COMPF`.

If something does not work, check:
- `wrklib lib(*curlib)`: Are all objects created as outlined above?
- `wrkactjob`. If the programs appear, use option 5 (work with), and then 10 to
  display their job log.
- `dspmsg`
- `dspmsg qsysopr`
- `dsplog`

## Current state
Please be once again reminded that this is **work in progress**.
- Collecting data by unsolicited packets from the hard coded first two COMServer ports works. The tick count per meter is currently also hard coded.
- Writing calculated watts to the data queue works.
- Pickup of these records and calculating some crude mean average over one minute works, along with the writing of those records to the final database file.
- Autostart of jobs at SBS start works.
- Graceful end of background ("batch") jobs works.

Also see **FIXME** remarks in the source code.

## Contact
You may write email to poc@pocnet.net for questions and general contact.

----
2026-05-01 poc@pocnet.net
