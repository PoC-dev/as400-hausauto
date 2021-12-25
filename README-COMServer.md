## How to get it to run
First, the applications are meant to run in a separate subsystem, so they can
be easily started at IPL time. Second, the applications are meant to run
with a separate user profile solely for that purpose.

The instructions assume you are signed on to a 5250 session as QSECOFR or some
user with equivalent rights.

***Note:*** Lines which end in a + sign are continued on the next line!

First, create a new library to hold all the needed objects. Change thereto.
```
CRTLIB LIB(HAUSAUTO) TEXT('Hausautomation')
CHGCURLIB CURLIB(HAUSAUTO)
CHGSRCPF FILE(SOURCES)
```

Next, create a user profile for the programs to run with. 
```
CRTUSRPRF USRPRF(HAUSAUTO) PASSWORD(*NONE) CURLIB(HAUSAUTO) LMTCPB(*YES) +
  TEXT('Hausautomation')
```

Now we can create the run time environment objects.
```
CRTSBSD SBSD(*CURLIB/HAUSAUTO) POOLS((1 *BASE)) SYSLIBLE(HAUSAUTO) +
  TEXT('Hausautomation Subsystem')
CRTJOBQ JOBQ(*CURLIB/HAUSTASKS) AUTCHK(*DTAAUT)
CRTJOBD JOBD(*CURLIB/COMRECV) JOBQ(HAUSAUTO/HAUSTASKS) USER(HAUSAUTO) +
  RTGDTA(COMRECV) RQSDTA('CALL PGM(HAUSAUTO/COMRECV)') +
  TEXT('Start COMRECV *PGM') 
CRTJOBD JOBD(*CURLIB/COMCPYRCD) JOBQ(HAUSAUTO/HAUSTASKS) USER(HAUSAUTO) +
  RTGDTA(COMCPYRCD) RQSDTA('CALL PGM(HAUSAUTO/COMCPYRCD)') +
  TEXT('Start COMCPYRCD *PGM') 
CRTCLS CLS(*CURLIB/COMRECV) RUNPTY(5) TIMESLICE(100) PURGE(*NO) +
  TEXT('Class for running the power calculator') 
CRTDTAQ DTAQ(*CURLIB/COMTMP) MAXLEN(32) +
  TEXT('Temporary data store for entries from COMServer')
```

Next, we need to modify the subsystem description we've created earlier.
- Add entries for actual auto start
- Add a job queue: Each job is placed in a queue for the SBS to pick it up
- Add routing entries to match against the JOBD's RTGDTA to add run time
  attributes. We want COMRECV to run in a very high priority so there is the
  least delay in calculating power.
```
ADDAJE SBSD(*CURLIB/HAUSAUTO) JOB(COMRECV) JOBD(*CURLIB/COMRECV)
ADDAJE SBSD(*CURLIB/HAUSAUTO) JOB(COMCPYRCD) JOBD(*CURLIB/COMCPYRCD)
ADDJOBQE SBSD(*CURLIB/HAUSAUTO) JOBQ(*CURLIB/HAUSTASKS) MAXACT(*NOMAX)
ADDRTGE SBSD(*CURLIB/HAUSAUTO) SEQNBR(10) CMPVAL('COMRECV') PGM(QCMD) +
  CLS(*CURLIB/COMRECV)
ADDRTGE SBSD(*CURLIB/HAUSAUTO) SEQNBR(99) CMPVAL(*ANY) PGM(QCMD) +
  CLS(*LIBL/QBATCH)
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
strcomcpyr.clle    STRCOMCPYR   CLLE 
strcomrecv.clle    STRCOMRECV   CLLE 
```

Upload these files with any FTP client **in ASCII mode** into HAUSAUTO/SOURCES.
Then set their file type with WRKMBRPDM in the 5250 session as shown above. Now
you can just type 14 beneath the objects to create them.

**Note!** You need to create the physical files first, because they are
referenced in the programs. When the objects don't exist and you try to compile
the programs, compilation will fail.

Now you can start the subsystem with `STRSBS SBSD(HAUSAUTO)`. You should see
the jobs run in WRKACTJOB:
```
Opt   Subsystem/Job  User        Type CPU %  Function        Status
      HAUSTASKS      QSYS        SBS    0,0                   DEQW 
        COMCPYRCD    HAUSAUTO    ASJ    0,0  PGM-COMCPYRCD    RUN  
        COMRECV      HAUSAUTO    ASJ    0,0  PGM-COMRECV      RUN  
```

After no more than one minute has passed, you should be able to see records in
STRSQL when commanding "SELECT * FROM COMPF".

If something does not work, check:
- WRKLIB LIB(*CURLIB): Are all objects created as outlined above?
- WRKACTJOB. If the programs appear, use option 5 (work with), and then 10 to
  display their job log.
- DSPMSG
- DSPMSG QSYSOPR
- DSPLOG

## Current state
Please be once again reminded that this is **work in progress**.
- Collecting data by unsolicited packets from the hard coded first two
  COMServer ports works. The tick count per meter is currently also hard coded.
- Writing calculated watts to the data queue works.
- Pickup of these records and calculating some crude mean average over one
  minute works, along with the writing of those records to the final database
  file.
- Autostart of jobs at SBS start works.
- Graceful end of background ("batch") jobs works.

Also see FIXME remarks in the source code.

## Contact
You may write email to poc@pocnet.net for questions and general contact.

Patrik Schindler,
December 2021
