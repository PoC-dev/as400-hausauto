/*
 * Copyright 2021 Patrik Schindler <poc@pocnet.net>.
 *
 * Licensing terms.
 * This is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * It is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 * or get it at http://www.gnu.org/licenses/gpl.html
 *
 * Based on the skeleton "Programming udp sockets in C on Linux
 * Silver Moon <m00n.silv3r@gmail.com>
 * http://www.binarytides.com/programming-udp-sockets-in-c-on-linux/
 *
 * Example how to handle Data Queues in C:
 * https://www.ibm.com/docs/en/i/7.1?topic=queues-example-in-ile-c-using-data
 */

#include <arpa/inet.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <sys/signal.h>
#include <time.h>
#include <qp0ztrc.h>
#include <qsnddtaq.h>
#include "comserver.h"

/* -----------------------------------------------------------------------------
 * Defines and global vars.
 * FIXME: Read this from preferences.
 */
#define PORT 49152	/* The port on which to listen for incoming data */
int exit_flag;

/*------------------------------------------------------------------------------
 * Send a message to the job log, and then exit with error.
 */

void die(char *s) {
    Qp0zLprintf("%s: %s\n", s, strerror(errno));
    exit(1);
}

/*------------------------------------------------------------------------------
 * Create Receiver Socket.
 */

int setup_recv_socket(unsigned int port) {
    struct sockaddr_in si_me;
    int s;

    /* create an UDP socket */
    if ((s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
        die("socket");
    }

    /* zero struct */
    memset((char *) &si_me, 0, sizeof(si_me));

    /* Setup */
    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(port);
    si_me.sin_addr.s_addr = htonl(INADDR_ANY);

    /* bind socket to port */
    if ( bind(s, (struct sockaddr*)&si_me, sizeof(si_me) ) == -1) {
        die("bind");
    }

    return(s);
};

/*------------------------------------------------------------------------------
 * Comserver gives us data in host byte order (correct for LSB platforms).
 */

unsigned short bswap(unsigned short val) {
    return (val << 8) | (val >> 8);
}

/*------------------------------------------------------------------------------
 * What to do when we receive a SIGTERM.
 */

void set_exit_flag(int signum) {
    exit_flag = 1;
}

/*------------------------------------------------------------------------------
 * Main
 */

int main(int argc, char *argv[]) {
    struct sigaction termaction;
    struct sockaddr_in si_other;
    struct timeval stamp;
    struct WUT_WRITE_REGISTER pkt, pkt_swp;
    char buf[1500], dtaqbuf[33];
    int slen = sizeof(si_other), s = 0, r = 0, recv_len;
    unsigned int i, sndqbytes, cur_watt;
    unsigned int shortlen = sizeof(short), current_regstate = 0;
    unsigned long int cur_usecs[12], prev_usecs[12];
    unsigned short int prev_state[12];

    /* Clean up beforehand. */
    for (i=0; i<13; i++) {
        prev_state[i] = prev_usecs[i] = prev_state[i] = 0;
    }

    sndqbytes = sizeof(dtaqbuf) - 1;

    /* Setup Receiver Socket. */
    s = setup_recv_socket(PORT);
    if ( (r=socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
        die("socket2");
    }

    /* Create signal handler for SIGTERM. */
    memset(&termaction, 0, sizeof(struct sigaction));
    termaction.sa_handler = set_exit_flag;
    sigaction(SIGTERM, &termaction, NULL);

    /* Init variable for timediff first. */
    gettimeofday(&stamp, NULL);

    /* Keep listening for data */
    while( exit_flag == 0 ) {
        /* try to receive some data. This is a blocking call. */
        /* FIXME: Get rid of GOTO. This is sooo BASIC-like... */
        tryagain:
        if ((recv_len = recvfrom(s, buf, 1500, 0, (struct sockaddr *) &si_other,
                &slen)) == -1) {
            if (errno == EINTR) {
                goto tryagain;
            } else {
                die("recvfrom()");
            }
        }

        /* Sort first few bytes into the struct. */
        /* FIXME: Do we really need to copy, or can we just set *s? */
        memcpy(&pkt.send_sequence, buf,                shortlen);
        memcpy(&pkt.recv_sequence, buf + shortlen,     shortlen);
        memcpy(&pkt.payload_type,  buf + shortlen * 2, shortlen);
        memcpy(&pkt.length,        buf + shortlen * 3, shortlen);
        memcpy(&pkt.count,         buf + shortlen * 4, shortlen);
        memcpy(&pkt.data,          buf + shortlen * 5, shortlen);

        /* Swap bytes and write into secondary buffer */
        /* FIXME: Can we unify the above copy with the swapping? */
        pkt_swp.send_sequence = bswap(pkt.send_sequence);
        pkt_swp.recv_sequence = bswap(pkt.recv_sequence);
        pkt_swp.payload_type = bswap(pkt.payload_type);
        pkt_swp.length = bswap(pkt.length);
        pkt_swp.count = bswap(pkt.count);
        pkt_swp.data = bswap(pkt.data);

        /* Increment counters in input_ticks. */
        for (i=0; i<pkt_swp.count; i++) {
            current_regstate = pkt_swp.data + (i * shortlen);

            if ( current_regstate > 0 ) {
                gettimeofday(&stamp, NULL);

                /* Is "our" bit set? */
                if ( current_regstate & 2 ) {
                    /* Only do if previous state was already 0. */
                    if ( prev_state[1] == 0 ) {
                        /* Calculate usecs over all from gettimeofday call. */
                        cur_usecs[1] = stamp.tv_sec * 1000000 + stamp.tv_usec;
                        /* Calculate current watts from above values . */
                        cur_watt = 3600000000 / (cur_usecs[1] - prev_usecs[1]);
                        /* Prevent bogus values. Very arbitrary. */
                        if ( prev_usecs[1] > 0 && cur_watt < 6000 ) {
                            /* Put timestamp into buffer. */
                            strftime(dtaqbuf, 32, "%Y-%m-%d-%H.%M.%S.000000",
                                localtime(&stamp.tv_sec));
                            /* Append calculated data to buffer. */
                            sprintf(dtaqbuf+26, "%02u%04lu", 2, cur_watt);
                            /* Send buffer to *DTAQ object. */
                            QSNDDTAQ("COMTMP    ", "HAUSAUTO  ", sndqbytes,
                                dtaqbuf);
                        }
                        /* Save previous values. */
                        prev_usecs[1] = cur_usecs[1];
                        /* Indicate our last state was 1. */
                        prev_state[1] = 1;
                    } else {
                        /* In theory, this should not happen. */
                        Qp0zLprintf("1 following 1 on Port %d. Lost Packet?\n",
                            2);
                    }
                } else {
                    /* Our bit is not set, so reset state. */
                    prev_state[1] = 0;
                }
                if ( current_regstate & 1 ) {
                    if ( prev_state[0] == 0 ) {
                        cur_usecs[0] = stamp.tv_sec * 1000000 + stamp.tv_usec;
                        cur_watt = 3600000000 / (cur_usecs[0] - prev_usecs[0]);
                        if ( prev_usecs[0] > 0 && cur_watt < 6000 ) {
                            strftime(dtaqbuf, 32, "%Y-%m-%d-%H.%M.%S.000000",
                                localtime(&stamp.tv_sec));
                            sprintf(dtaqbuf+26, "%02u%04lu", 1, cur_watt);
                            QSNDDTAQ("COMTMP    ", "HAUSAUTO  ", sndqbytes,
                                dtaqbuf);
                        }
                        prev_usecs[0] = cur_usecs[0];
                        prev_state[0] = 1;
                    } else {
                        Qp0zLprintf("1 following 1 on Port %d. Lost Packet?\n",
                            1);
                    }
                } else {
                    prev_state[0] = 0;
                }
            } else {
                prev_state[0] = prev_state[1] = 0;
            }
        }
    }
    close(s);
    return 0;
}

/*------------------------------------------------------------------------------
 * vim: ft=c colorcolumn=81 autoindent shiftwidth=4 tabstop=4 expandtab
 */
