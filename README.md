# hg612-scripts
VDSL monitoring for the Huawei HG612

Collection of scripts I use to monitor my VDSL2 connection stats. They are tailored for the Huawei HG612 with unlocked firmware.

The modem is available for a few quid on ebay and the firmware can be found easily on the Internet. Pairing this modem with your own router is one of the best combinations for the BT network.

Requirements:
- Unlocked HG612 with telnet access
- rrdtool
- perl, net::telnet, rrds

###### get-stats.pl
Perl script collecting data over telnet and storing it into RRD files.

###### make-graph.sh
Generate PNG graphs from the RRD files.

___

![Works on my machine](https://blog.codinghorror.com/content/images/uploads/2007/03/6a0120a85dcdae970b0128776ff992970c-pi.png)