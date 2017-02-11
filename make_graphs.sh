#!/bin/bash

declare -A updowntitles
declare -A errortitles
declare -A signaltitles

rrdcmd="/usr/bin/rrdtool"

rrdfilespeed="/opt/vdsl-mon/hg612-speed.rrd"
rrdfilesignal="/opt/vdsl-mon/hg612-signal.rrd"
rrdfileerr="/opt/vdsl-mon/hg612-errors.rrd"
rrdfileup="/opt/vdsl-mon/hg612-uptime.rrd"

outdir="/opt/vdsl-mon/public_html/"
rrdstd="-w 460 -h 120 -a PNG --end now --lower-limit 0 --slope-mode --watermark hg612 --color CANVAS#FFFFFF --color FONT#000000 --color BACK#FFFFFF --font DEFAULT:8:"
rrdupdowns="max cur"
rrdsignals="snr att pow inp delay"
rrderrs="es crc fec"
rrdscales="1h 1d 1w 1m 13w"

updowntitles[max]="Maximum Sync (Kbps)"
updowntitles[cur]="Current Sync (Kbps)"

errortitles[es]="ES count"
errortitles[crc]="CRC rate"
errortitles[fec]="FEC rate"

signaltitles[snr]="SNR (dB)"
signaltitles[att]="Attenuation (dB)"
signaltitles[pow]="Power (dBm)"
signaltitles[inp]="INP"
signaltitles[delay]="Delay"

for scale in $rrdscales
do
  for updown in $rrdupdowns
  do
    ${rrdcmd} graph ${outdir}hg612_${updown}_${scale}.png ${rrdstd} --start end-${scale} --title="${updowntitles[${updown}]}" \
      DEF:dn=${rrdfilespeed}:${updown}d:AVERAGE \
      DEF:up=${rrdfilespeed}:${updown}u:AVERAGE \
      AREA:up\#00ff0080:"Upstream  " \
      GPRINT:up:LAST:"Last\: %6.2lf" \
      GPRINT:up:MIN:" Min\: %6.2lf" \
      GPRINT:up:MAX:" Max\: %6.2lf\n" \
      AREA:dn\#0000ff80:"Downstream" \
      GPRINT:dn:LAST:"Last\: %6.2lf" \
      GPRINT:dn:MIN:" Min\: %6.2lf" \
      GPRINT:dn:MAX:" Max\: %6.2lf\n" \
      LINE1:dn\#0000ff: \
      LINE1:up\#00ff00: &
  done
  for updown in $rrdsignals
  do
    ${rrdcmd} graph ${outdir}hg612_${updown}_${scale}.png ${rrdstd} --start end-${scale} --title="${signaltitles[${updown}]}" \
      DEF:dn=${rrdfilesignal}:${updown}d:AVERAGE \
      DEF:up=${rrdfilesignal}:${updown}u:AVERAGE \
      AREA:up\#00ff0080:"Upstream  " \
      GPRINT:up:LAST:"Last\: %6.2lf" \
      GPRINT:up:MIN:" Min\: %6.2lf" \
      GPRINT:up:MAX:" Max\: %6.2lf\n" \
      AREA:dn\#0000ff80:"Downstream" \
      GPRINT:dn:LAST:"Last\: %6.2lf" \
      GPRINT:dn:MIN:" Min\: %6.2lf" \
      GPRINT:dn:MAX:" Max\: %6.2lf\n" \
      LINE1:dn\#0000ff: \
      LINE1:up\#00ff00: &
  done
  for updown in $rrderrs
  do
    ${rrdcmd} graph ${outdir}hg612_${updown}_${scale}.png ${rrdstd} --start end-${scale} --title="${errortitles[${updown}]}" \
      DEF:dn=${rrdfileerr}:${updown}d:AVERAGE \
      DEF:up=${rrdfileerr}:${updown}u:AVERAGE \
      AREA:up\#00ff0080:"Upstream  " \
      GPRINT:up:LAST:"Last\: %6.2lf" \
      GPRINT:up:MIN:" Min\: %6.2lf" \
      GPRINT:up:MAX:" Max\: %6.2lf\n" \
      AREA:dn\#0000ff80:"Downstream" \
      GPRINT:dn:LAST:"Last\: %6.2lf" \
      GPRINT:dn:MIN:" Min\: %6.2lf" \
      GPRINT:dn:MAX:" Max\: %6.2lf\n" \
      LINE1:dn\#0000ff: \
      LINE1:up\#00ff00: &
  done
  wait

  ${rrdcmd} graph ${outdir}uptimes_${scale}.png ${rrdstd} --start end-${scale} --title="Uptimes" -v days --rigid \
    DEF:lin=${rrdfileup}:lineup:AVERAGE \
    DEF:mdm=${rrdfileup}:mdmup:AVERAGE \
    AREA:mdm\#7affaf80:"Modem Uptime" \
    GPRINT:mdm:LAST:"Cur\:%6.1lf" \
    GPRINT:mdm:AVERAGE:"Ave\:%6.1lf" \
    GPRINT:mdm:MAX:"Max\:%6.1lf\n" \
    AREA:lin\#ffaf7a80:" Line Uptime" \
    GPRINT:lin:LAST:"Cur\:%6.1lf" \
    GPRINT:lin:AVERAGE:"Ave\:%6.1lf" \
    GPRINT:lin:MAX:"Max\:%6.1lf\n" \
    LINE1:mdm\#000001: \
    LINE1:lin\#000001:

done
