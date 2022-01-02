## What is it?
This is a slowly growing collection of programs for running on an AS/400,
ported from some mess I created on Linux almost a decade ago. Functionality is
currently split between those two platforms until everything has been migrated.

Its main goal is to provide some means of automation to my home. Most important
is the variable power setting to the hot water boiler depending on solar yield.
This cut the power bill trendemously.

All those programs are highly specific to my home, so don't think you can just
copy over those and do your own home automation. But you may see it as a pool
of example programs, how to do something in OS/400, or even as a well of source
code for specifitc tasks to be done in OS/400.

It is released to the public according to the GNU GPL v 2.0 or later.

**Be warned!** This is work in progress. While I try to omit uploading things
which are known to be broken, the main issue is missing feature completeness.
If this matters in any way, because... see above.

## Goals
- Allow the hot water boiler to draw only excess energy, to save power.
- Provide some means of a minimum temperature to hold in any case. Nobody likes
  to shower with 20°C water in winter, right?
- Provide some means to heat up the water in any case to a certain temperature
  **once**. Might be even more energy saving than holding a certain temperature
  all the time.
- Switch the garden lights on and off depending on time of day, and brightness.
  Actual "too dark" can be acquired from the SMA 5000TL.
- Switch the staircase lights on and off depending on weekday, time of day, and
  brightness.
- Provide an auto-refreshing dashboard view for all acquired and calculated
  values on a 5250 screen.
- Provide applications for setting parameters on a 5250 screen, and update the
  objects saving those parameters permanently.
- Try to exploit GDDM to draw graphs.

## Hardware-Components
People say, a picture tells more than a thousand words. They might be right.
Since I'm a German resident, products I use are probably not available in other
countries.
```
                             +--------+ Temperature
  Switches:       +----------+ Boiler +-------------------+
  Eltako ER12-001 |          +--------+ sensor            |
                  |                                       |
                  |          +--------------+             |
                  | +--------+ Garden Light |             |
                  | |        +--------------+             |
                  | |                                     |
                  | |        +-----------------+          |
                  | | +------+ Staircase Light |          |
+-------------+   | | |      +-----------------+          |
|             |   | | |                                   |
|  +--------+ |   | | |                                   |
|  |   (In) | |   | | | (Out)                             | 1w-Bus
|  |     +--+-+---+-+-+--+         +--------+     +-------+-------+
|  |     | W&T COMServer |         |  IBM   |     | EDS OW Server |
|  |     |     50210     |         | AS/400 |     | v2 Enet       |
|  |     +--+------------+         +----+---+     +-------+-------+
|  |        |                           |                 |
|  |  |     |                           |                 |          |
|  |  +=====+=====+=====================+=================+===+======+
|  |  |           |                                           |  LAN |
|  +--------------|----------------+ House Consumption        |
|                 |            (S0)| 1000 Imp/kWh             |
|        +--------+-------+   +----+----------------+         |
|        | SMA Sunny Home |   | Eltako DSZ12D-3x65A |         |
|        | Manager 2.0    |   | Power Meter         |         |
|        +----+------+----+   +----+-----------+----+         |
|             |      |         (In)|           |(Out)         |
|             |      |             |           |              |
|  -----------+      +----+--------+           +------->--    |
|  From                   |                    To House       |
|  power grid             |(Out)                              |
|                +--------+------------+                      |
|                | Eltako DSZ12D-3x65A | Solar Power          |
|                | Power Meter         | 1000 Imp/kWh         |
|                +---+----+------------+                      |
|                (S0)|    |(In)                               |
+--------------------+    |                                   |
                          |                                   |
                     +----+-----------------------------------+----+
                     | Solar Inverter SMA Sunny Tripower 5000TL-20 |
                     +--------------------------+------------------+
                                                |
                                     +----------+----------+
                                     | Solar Cells on Roof |
                                     +---------------------+
```
### Wiesemann & Theis COMServer 50210
This device is a very old Ethernet connected digital I/O device. With a
proprietary UDP based protocol you can read from, and write to "registers", to
get the status of the pins.
In addition, the 50210 can be told to send an unsolicited UDP packet to a
configurable IP address on every state change, containing the current state of
the input registers.

This device has power meters connected to its first two inputs. These measure
the power passing through, and generate a 50ms pulse for each 1Wh having been
accumulated. Thus, each counter pulse will generate *two* packets. One for the
initial 0=>1 change, and a second one for the following 1=>0 change.

This device has relays (Eltako ER12-001) connected to some of its output pins,
to switch ordinary 230V devices on, and off.

### Embedded Data Systems OW Server v2 Enet
This device attaches Dallas Semiconductor so called *one-wire devices*. Return
is not counted and data flows alternating to 5V power to this one wire.

I have connected a lot of DS18S20 temperature sensors to its three buses, as
well as a DS2450 Quad A/D converter, and finally a DS2408 8-Port digital
output, built to a readymade device for analog output between 0..10V by
esera.de. This analog output is connected to a phase controlled modulator. The
modulator is used to steer the amount of power to an electrical hot water
boiler. One of the temperature sensors is also inserted into a temperature
sensor opening of the boiler, to measure current water temperature. Currently
temperature data is used only for acquisition. The DS240 is currently connected
to a mini solar cell, measuring brightness outside to have the relays switch on
and off certain lights as needed.

The attached sensors are polled regularly by the OW-Server by itself and
acquired data kept in RAM. Data is exposed very conveniently through SNMP
requests being sent to the OW-Server. Also, SNMP Write requests are used to
change the power setting of the boiler via the DS2408.

### SMA Devices
The SMA devices are there for enabling to exploit solar power delivered through
sunlight on solar cells to the house. While they are connected to the network
to talk to each other, there's currently no further functionality implemented.

### AS/400
An elderly IBM AS/400 9401 Model 150 running OS/400 V4R5. I was searching for
some means to get this box some meaningful work besides editing database
content via green screen. See [my AS/400 Wiki](https://try-as400.pocnet.net)
for details around this highly interesting platform.

## Software-Components
All things related to the 50210 have their names begin with COM. All things
related to the OW-Server have their names begin with OW. All things related to
the SMA Sunny products have their names begin with SMA.

Presented below is only stuff which is already finished, and functional.

### COM-Software
Applications related to the COMServer currently comprise of two readymade
programs, and some auxiliary files. See README-COMServer for how to make it run.

- COMRECV is a try-to-be-very-efficient application program to receive pulses
  from the COMServer. Time passing between two 0=>1 pulses is measured, and the
  current power draw in Watts in this time period is calculated. The current
  time stamp, the calculated power draw, and the port number are saved in an
  OS/400 data queue object, because this has very low overhead with writes to
  not spoil the timing sensitive power calculation.

- COMCPYRCD runs asynchronously to COMRECV. It takes records off the said data
  queue object, calculates the mean average of power drawn over one minute, and
  saves the result in a database table.  Note that this calculation isn't
  mathematically correct, because higher power draw results in more records
  being generated. But it's good enough for the time being.

## Contact
You may write email to poc@pocnet.net for questions and general contact.

Patrik Schindler,
December 2021
