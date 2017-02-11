#!/usr/bin/perl -w
#
# Extended by: Nikolai Spasov (ns_at_codingrobot.com)
# Author: Andrew Wiles (adw_at_avatastic.co.uk)
# Based on the script by Jason Lassaline (jason.lassaline_at_gmail.com)
# The original script can be found at:
# http://www.dslreports.com/forum/r21063176-Re-Line-stats-monitoring-with-RRDTool-or-MRTG
# You must have the Net::Telnet and RRDS (comes with RRDTool) Perl classes
use warnings;
use IO::Handle;
use Net::Telnet ();
use RRDs;

$run = 1;

$SIG{INT} = sub {
	$run = 0;
};

# Set to your HG612 address or hostname (if any)
# The default is 192.168.1.1
$host = '192.168.1.1';
$user = 'admin';
$pass = 'admin';

# Adjust to the desired output pathname for RRDTool. Should be within your Web
# server root directory if you wish to serve graphs via cgi script unless you
# want to mess with access rules.
$RRD_SPEEDS_FILE = "/opt/vdsl-mon/hg612-speed.rrd";
$RRD_ERRORS_FILE = "/opt/vdsl-mon/hg612-errors.rrd";
$RRD_SIGNAL_FILE = "/opt/vdsl-mon/hg612-signal.rrd";
$RRD_UPTIME      = "/opt/vdsl-mon/hg612-uptime.rrd";

# Call this script every $STEP seconds to update the RRDTool file (use cron)
$STEP = 10;

# Keep the heartbeat at 2*$STEP for now in the event retrieving and parsing
# modem output takes an unusually long time.     Recorded values may span more than
# one timestep at worst.
$HEARTBEAT = 20;
$t = new Net::Telnet(Timeout => 5);

if (not -e $RRD_SPEEDS_FILE) {
	RRDs::create(
		"$RRD_SPEEDS_FILE",
		"--start=N",
		"--step=$STEP",

		"DS:maxu:GAUGE:$HEARTBEAT:0:104857600",
		"DS:maxd:GAUGE:$HEARTBEAT:0:104857600",
		"DS:curu:GAUGE:$HEARTBEAT:0:104857600",
		"DS:curd:GAUGE:$HEARTBEAT:0:104857600",

		"RRA:AVERAGE:0.5:1:1000",
		"RRA:AVERAGE:0.5:6:1000",
		"RRA:AVERAGE:0.5:24:1000",
		"RRA:AVERAGE:0.5:288:1000"
	);
}

if (not -e $RRD_SIGNAL_FILE) {
	RRDs::create(
		"$RRD_SIGNAL_FILE",
		"--start=N",
		"--step=$STEP",

		"DS:snru:GAUGE:$HEARTBEAT:0:100",
		"DS:snrd:GAUGE:$HEARTBEAT:0:100",
		"DS:attu:GAUGE:$HEARTBEAT:0:100",
		"DS:attd:GAUGE:$HEARTBEAT:0:100",
		"DS:powu:GAUGE:$HEARTBEAT:0:100",
		"DS:powd:GAUGE:$HEARTBEAT:0:100",
		"DS:inpu:GAUGE:$HEARTBEAT:0:104857600",
		"DS:inpd:GAUGE:$HEARTBEAT:0:104857600",
		"DS:delayu:GAUGE:$HEARTBEAT:0:104857600",
		"DS:delayd:GAUGE:$HEARTBEAT:0:104857600",

		"RRA:AVERAGE:0.5:1:1000",
		"RRA:AVERAGE:0.5:6:1000",
		"RRA:AVERAGE:0.5:24:1000",
		"RRA:AVERAGE:0.5:288:1000"
	);
}

if (not -e $RRD_ERRORS_FILE) {
	RRDs::create(
		"$RRD_ERRORS_FILE",
		"--start=N",
		"--step=$STEP",

		"DS:crcu:COUNTER:$HEARTBEAT:0:104857600",
		"DS:crcd:COUNTER:$HEARTBEAT:0:104857600",
		"DS:esu:COUNTER:$HEARTBEAT:0:104857600",
		"DS:esd:COUNTER:$HEARTBEAT:0:104857600",
		"DS:fecu:COUNTER:$HEARTBEAT:0:104857600",
		"DS:fecd:COUNTER:$HEARTBEAT:0:104857600",

		"RRA:AVERAGE:0.5:1:1000",
		"RRA:AVERAGE:0.5:6:1000",
		"RRA:AVERAGE:0.5:24:1000",
		"RRA:AVERAGE:0.5:288:1000",
	);
}

if (not -e $RRD_UPTIME) {
	RRDs::create(
		"$RRD_UPTIME",
		"--start=N",
		"--step=$STEP",
		"DS:lineup:GAUGE:$HEARTBEAT:0:U",
		"DS:mdmup:GAUGE:$HEARTBEAT:0:U",

		"RRA:AVERAGE:0.5:1:800",
		"RRA:AVERAGE:0.5:6:800",
		"RRA:AVERAGE:0.5:24:800",
		"RRA:AVERAGE:0.5:288:800",

		"RRA:MAX:0.5:1:800",
		"RRA:MAX:0.5:6:800",
		"RRA:MAX:0.5:24:800",
		"RRA:MAX:0.5:288:800"
	);
}

$t->open($host);

$t->waitfor('/Login:/i');
$t->print($user);
$t->waitfor('/Password:/i');
$t->print($pass);
$t->waitfor('/ATP>/');
$t->print('sh');

while ($run) {
	select STDOUT;

	# Fire off adsl info command
	@result = $t->cmd('xdslcmd info --stats');
	@uptime = $t->cmd('cat /proc/uptime');

	chomp(@result);
	chomp(@uptime);

	# Initialize all outputs as unknown in case parsing fails
	$max_up     = "U";
	$max_down   = "U";
	$cur_up     = "U";
	$cur_down   = "U";
	$snr_up     = "U";
	$snr_down   = "U";
	$att_up     = "U";
	$att_down   = "U";
	$power_up   = "U";
	$power_down = "U";
	$delay_up   = "U";
	$delay_down = "U";
	$inp_up     = "U";
	$inp_down   = "U";

	$fec_up   = "U";
	$fec_down = "U";
	$crc_up   = "U";
	$crc_down = "U";

	$es_up   = "U";
	$es_down = "U";
	$mdmup   = "U";
	$lineup  = "U";

	# Indicate we have passed the 'Since Link time' section so we can get ES and CRC stats
	$at_total_result = 0;

	# Loop over results, parsing expanded adsl info output
	while (@result) {
		if ($result[0] =~ /SNR\s+\(dB\):\s+(\d+.\d+)\s+(\d+.\d+)/) {

			# SNR Margin down/up in dB
			$snr_down = $1;
			$snr_up   = $2;
		} elsif ($result[0] =~ /Attn\(dB\):\s+(\d+.\d+)\s+(\d+.\d+)/) {

			# Attenuation down/up in dB
			$att_down = $1;
			$att_up   = $2;
		} elsif ($result[0] =~ /Pwr\(dBm\):\s+(\d+.\d+)\s+(\d+.\d+)/) {

			# Output power down/up in dB
			$power_down = $1;
			$power_up   = $2;
		} elsif ($result[0] =~ /INP:\s+(\d+.\d+)\s+(\d+.\d+)/) {
			$inp_down = $1;
			$inp_up   = $2;
		} elsif ($result[0] =~ /delay:\s+(\d+)\s+(\d+)/) {
			$delay_down = $1;
			$delay_up   = $2;
		} elsif ($result[0] =~ /Max:\s+Upstream rate = (\d+) Kbps, Downstream rate = (\d+) Kbps/) {

			# Output power down/up in dB
			$max_down = $2;
			$max_up   = $1;
		} elsif ($result[0] =~ /Bearer.*Upstream rate = (\d+) Kbps, Downstream rate = (\d+) Kbps/) {

			# Output power down/up in dB
			$cur_down = $2;
			$cur_up   = $1;
		}

		elsif ($result[0] =~ /Since Link time =/) {
			my $d = 0, $h = 0, $m = 0, $s = 0;
			if ($result[0] =~ /(\d+)\s+day/) {
				$d = $1 * 24 * 60 * 60;
			}
			if ($result[0] =~ /(\d+)\s+hour/) {
				$h = $1 * 60 * 60;
			}
			if ($result[0] =~ /(\d+)\s+min/) {
				$m = $1 * 60;
			}
			if ($result[0] =~ /(\d+)\s+sec/) {
				$s = $1;
			}
			$lineup = ($d + $h + $m + $s) / (24 * 60 * 60);
			$at_total_result = 1;
		} elsif ($at_total_result) {
			if ($result[0] =~ /^CRC:\s+(\d+)\s+(\d+)/) {
				$crc_down = $1;
				$crc_up   = $2;
			} elsif ($result[0] =~ /^ES:\s+(\d+)\s+(\d+)/) {
				$es_down = $1;
				$es_up   = $2;
			} elsif ($result[0] =~ /^FEC:\s+(\d+)\s+(\d+)/) {
				$fec_down = $1;
				$fec_up   = $2;
			}

		}

		# Note that there is more information available in the output, such
		# as line profile up/down and maximum line up/down bandwidth. Parse
		# as you see fit.
		shift(@result);
	}

	while (@uptime) {
		if ($uptime[0] =~ /(\d+).\d+\s+\d+.\d+/) {
			$mdmup = $1 / (24 * 60 * 60);
		}
		shift(@uptime);
	}

	# File must exist, so update it with 'now' as the time stamp. This will be off
	# a small amount due to the time it takes to retrieve and parse the modem data
	# this is likely not significant and is probably a constant offset.
	# STDOUT->printflush("$es_up:$es_down:$crc_up:$crc_down");

	RRDs::update("$RRD_SPEEDS_FILE", "N:$max_up:$max_down:$cur_up:$cur_down");
	RRDs::update("$RRD_ERRORS_FILE", "N:$crc_up:$crc_down:$es_up:$es_down:$fec_up:$fec_down");
	RRDs::update("$RRD_SIGNAL_FILE",
		"N:$snr_up:$snr_down:$att_up:$att_down:$power_up:$power_down:$inp_up:$inp_down:$delay_up:$delay_down");
	RRDs::update("$RRD_UPTIME", "N:$lineup:$mdmup");

	sleep $STEP;
}
$t->close();

