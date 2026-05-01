     HCOPYRIGHT('Patrik Schindler <poc@pocnet.net>, 2021-12-25')
     H*-------------------------------------------------------------------------
     H* Redistribution and use in source and binary forms, with or without
     H* modification, are permitted provided that the following conditions are
     H* met:
     H*
     H* 1. Redistributions of source code must retain the above copyright
     H*    notice, this list of conditions and the following disclaimer.
     H* 2. Redistributions in binary form must reproduce the above copyright
     H*    notice, this list of conditions and the following disclaimer in the
     H*    documentation  and/or other materials provided with the distribution.
     H*
     H* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
     H* IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
     H* TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
     H* PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
     H* OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
     H* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
     H* LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
     H* DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
     H* THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
     H* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
     H* THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
     H*-------------------------------------------------------------------------
     H* https://www.ibm.com/docs/en/i/7.1?topic=+
     H*         queues-example-in-ile-rpg-using-data
     H*
     H* Compiler flags.
     HDFTACTGRP(*NO) ACTGRP(*NEW) CVTOPT(*DATETIME)
     H*
     H* Tweak default compiler output: Don't be too verbose.
     HOPTION(*NOXREF : *NOSECLVL : *NOSHOWCPY : *NOEXT : *NOSHOWSKP)
     H*
     H* When going prod, enable this for more speed/less CPU load.
     HOPTIMIZE(*FULL)
     H*
     H*************************************************************************
     H* List of INxx, we use:
     H*- Keys:
     H*- Other Stuff:
     H*     71: WRITE to COMPF error.
     H*
     H*************************************************************************
     F* File descriptors. Unfortunately, we're bound to handle files by file
     F*  name or record name. We can't use variables to make this more dynamic.
     F* Restriction of RPG.
     F*
     F* Main/primary file, used mainly for writing into.
     FCOMPF     UF A E           K DISK
     F*
     F*************************************************************************
     D* Global Variables (additional to autocreated ones by referenced files).
     D*
     D* Receive entries from Data Queue.
     DQRCVDTAQ         PR                  ExtPgm('QRCVDTAQ')
     D DtaqName                      10A   CONST
     D LibName                       10A   CONST
     D DtaLen                         5P 0 CONST
     D Dta                            8A   CONST
     D Wait                           5P 0 CONST
     D*
     D* Print(f) to Job Log.
     DQp0zLprintf      PR            10I 0 ExtProc('Qp0zLprintf')
     D MSG                             *   VALUE OPTIONS(*STRING)
     D                                 *   VALUE OPTIONS(*STRING:*NOPASS)
     D                                 *   VALUE OPTIONS(*STRING:*NOPASS)
     D                                 *   VALUE OPTIONS(*STRING:*NOPASS)
     D                                 *   VALUE OPTIONS(*STRING:*NOPASS)
     D                                 *   VALUE OPTIONS(*STRING:*NOPASS)
     D* -----------------------------------------------------------------------
     D* Array to hold each input's values.
     DA_WATT           S              6S 0 DIM(12)
     DA_COUNT          S              3S 0 DIM(12)
     D*
     D* Receiver for what we read from the *DTAQ.
     DDTA              DS
     D Q_STAMP                       26A
     D Q_PORT                         2A
     D Q_WATT                         4A
     D*
     D* For *ZERO reads, we need a timestamp somehow.
     DZ_STAMP          S               Z
     D*
     D* Converted values from string (source: Q_*) to Numeric.
     DN_WATT           S              6S 0
     DN_PORT           S              2S 0
     D*
     D* In addition, we have D_WATT and D_PORT derived from the PF.
     D*
     D* How many Bytes have we read from the *DTAQ?
     DQREAD            S              3S 0
     D*
     D* Keep track of changes to the minute field of the time stamp.
     DCURRMINUTE       S              2A
     DLASTMINUTE       S              2A   INZ('99')
     D*
     D* Arrax Index. Must be a short name.
     DIDX              S              2S 0
     D*
     D*************************************************************************
S1   C     *ZERO         DOWEQ     *ZERO
     C*
     C* Read entry from *DTAQ. Use a timeout of 60 seconds to insert *ZERO
     C*  into database, if we didn't receive data in time.
     C                   CALLP     QRCVDTAQ ('COMTMP    ':'HAUSAUTO  '
     C                             :QREAD:DTA:60)
     C*
     C* Debugging Aid.
     C*                  CALLP     Qp0zLprintf('%s  %s  %s' + X'25':
     C*                            Q_STAMP:Q_PORT:Q_WATT)
     C*
     C* If we get blanks after a read, we probably ran into the timeout. Handle
     C*  and immediately start next read cycle.
S2   C     Q_STAMP       IFEQ      *BLANK
     C                   EXSR      HDLEMPTY
     C                   ITER
E2   C                   ENDIF
     C*
     C* Otherwise we may continue with actual data.
     C* Extract current minute.
     C     2             SUBST     Q_STAMP:15    CURRMINUTE
     C*
     C* Convert variables to Numeric.
     C                   MOVE      Q_PORT        N_PORT
     C                   MOVE      Q_WATT        N_WATT
     C*
     C* Handle first run with LASTMINUTE fake value '99' from INZ in D (ignore).
S2   C     LASTMINUTE    IFEQ      '99'
     C                   MOVEL     CURRMINUTE    LASTMINUTE
E2   C                   ENDIF
     C*
     C* If minute values do not match, begin new cycle.
S2   C     CURRMINUTE    IFNE      LASTMINUTE
     C                   EXSR      NEWMINUTE
E2   C                   ENDIF
     C*
     C* Add up converted values for a given port, and increment value count.
     C                   Z-ADD     N_PORT        IDX
     C                   ADD       N_WATT        A_WATT(IDX)
     C                   ADD       1             A_COUNT(IDX)
     C*
     C* Throw away data. Next run might be an empty one.
     C                   CLEAR                   DTA
     C*
     C* Catch external signal asking for shutdown.
     C                   SHTDN                                        LR
S2   C     *INLR         IFEQ      *ON
     C                   EXSR      NEWMINUTE
     C                   LEAVE
E2   C                   ENDIF
     C*
E1   C                   ENDDO
     C* ------------------------------------------------------------------------
     C* Properly end *PGM.
     C                   RETURN
     C*************************************************************************
     C     NEWMINUTE     BEGSR
     C*
     C* Write records, clean up and begin new cycle.
     C*
     C                   MOVE      *ZERO         IDX
     C                   MOVE      Q_STAMP       D_STAMP
     C*
S1   C     IDX           DOWLT     2
     C                   ADD       1             IDX
     C                   Z-ADD     IDX           D_PORT
     C*
     C* If we have *ZERO counts, then there wasn't any pulse, and thus 0 Watts.
S2   C     A_COUNT(IDX)  IFEQ      *ZERO
     C                   MOVE      *ZERO         D_WATT
     C* Add "now" timestamp to entry - we do not have anything else.
     C                   TIME                    Z_STAMP
     C                   MOVEL     Z_STAMP       D_STAMP
X2   C                   ELSE
     C     A_WATT(IDX)   DIV       A_COUNT(IDX)  D_WATT
E2   C                   ENDIF
     C* Write DB entry. Should succeed, because we have all mandatory fields
     C*  filled: D_STAMP, D_PORT, D_WATT.
     C                   WRITE     COMVALTBL                            71
S2   C     *IN71         IFEQ      *ON
     C                   CALLP     Qp0zLprintf('Error writing regular record ' +
     C                             'for Port %s at % with count %s, and sum ' +
     C                             '%s W, equalling %s W.' + X'25':
     C                             %CHAR(D_PORT):D_STAMP:%CHAR(A_COUNT(IDX)):
     C                             %CHAR(A_WATT(IDX)):%CHAR(D_WATT))
E2   C                   ENDIF
     C*
E1   C                   ENDDO
     C*
     C* Cleanup for new data.
     C                   CLEAR                   A_WATT
     C                   CLEAR                   A_COUNT
     C*
     C                   MOVEL     CURRMINUTE    LASTMINUTE
     C*
     C                   ENDSR
     C*************************************************************************
     C     HDLEMPTY      BEGSR
     C* Fill Array with *ZERO and directly write out the records.
     C*
     C                   MOVE      *ZERO         IDX
     C                   MOVE      *ZERO         D_WATT
     C* Add "now" timestamp to entry - we do not have anything else.
     C                   TIME                    Z_STAMP
     C                   MOVEL     Z_STAMP       D_STAMP
     C*
S1   C     IDX           DOWLT     2
     C                   ADD       1             IDX
     C                   Z-ADD     IDX           D_PORT
     C                   CALLP     Qp0zLprintf('Writing 0 for port %s.' +
     C                             X'25':%CHAR(IDX))
     C* Write DB entry.
     C                   WRITE     COMVALTBL                            71
S2   C     *IN71         IFEQ      *ON
     C                   CALLP     Qp0zLprintf('Error writing *ZERO record ' +
     C                             'for Port %s at %s.' + X'25':%CHAR(IDX):
     C                             D_STAMP)
E2   C                   ENDIF
     C*
E1   C                   ENDDO
     C*
     C                   ENDSR
     C*************************************************************************
     C* vim: syntax=rpgle colorcolumn=81 autoindent noignorecase
