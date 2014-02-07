#!/usr/bin/perl -w
#===============================================================================
# Auteur : Simon Mignot - simon.mignot.lasalle@gmail.com
# Date   : 29/01/2014 - 8:11:32
# But    : Verification de la bande passante du port d'un switch
#===============================================================================

use Math::Round;
use Nagios::Plugin;

sub getInterfacesName
{
	$command = `snmpwalk -Os -c $community -v 1 $ip .1.3.6.1.2.1.2.2.1.2`;
	#TODO split for display only interfaces name rather of the full OID
	return $command;
}

sub getInterfacesIDs
{
	my (@names) = @_;
	foreach my $value (@names)
	{
		$currentID = getInterfaceID($value);
		if($currentID eq "error")
		{
			return;
		}
		else
		{
			push(@return, $currentID);
		}
	}
	return @return;
}

sub getInterfaceID
{
	my ($name) = @_;
	$commandId = `snmpwalk -Os -c $community -v 1 $ip .1.3.6.1.2.1.2.2.1.2 | grep "ifDescr.*STRING: $name\$"`;
	chop($commandId);
	if($commandId eq "")
	{
		$badName = 1;
		return "error";
	}
	$commandId = substr($commandId, 8);
	$length = index($commandId, "=") - 1;
	$return = substr($commandId, 0, $length);
	return $return;
}
sub getTotalBytes
{
	my ($IDInterface, $community, $bIn) = @_;
	if($bIn)
	{
		$sensID = 16;
	}
	else
	{
		$sensID = 10;
	}
	my $result = `snmpget -Ov -c $community -v 1 $ip .1.3.6.1.2.1.2.2.1.$sensID.$IDInterface`;
	$result = substr($result, 11);
	chop($result);
	return $result;
}

sub getFormattedData
{
	my ($speed) = @_;
	if(!($speed =~ /^\d+\.*\d*$/))
	{
		return $speed;
	}
	if($speed < 750)
	{
		$speed = nearest(.001, $speed);
		return "$speed octets";
	}
	if($speed >= 750 && $speed < 750000)
	{
		$speed = nearest(.001, $speed / 1000);
		return "$speed Ko";
	}
	if($speed >= 750000 && $speed < 750000000)
	{
		$speed = nearest(.001, $speed / 1000000);
		return "$speed Mo";
	}
	if($speed >= 750000000)
	{
		$speed = nearest(.001, $speed / 1000000000);
		return "$speed Go";
	}
}

sub writeFile
{
	open(FILE, ">$path");
	print FILE $totalBytesIN;
	print FILE "\n";
	print FILE $totalBytesOUT;
	print FILE "\n";
	print FILE time;
	print FILE "\n";
	close(FILE);
}

my $LICENCE = 
"#===============================================================================\n" . 
'# Auteur : Simon Mignot - simon.mignot.lasalle@gmail.com' . "\n" .
"# But    : Verification de la bande passante du port d'un switch\n" . 
"# ########\n" .
"# Ce plugin Nagios est gratuit et libre de droits, et vous pouvez l'utiliser à votre convenance.\n" .
"# Ce plugin n'est livrée avec ABSOLUMENT AUCUNE GARANTIE.\n" . 
"#===============================================================================\n";


my $USAGE = "Usage : %s [-H <host>] [-C <community>] [-i <interface name>] [-w <warning>] [-c <critical>] [-F all]";

use vars qw/ $VERSION /;
$VERSION = 'v1.0';

my $plugin = Nagios::Plugin->new(
		shortname => "check switch's bandwidth",
		usage     => "$USAGE",
		version   => $VERSION,
		license   => $LICENCE,
		);

$defaultWarn = 100000; # 100 Ko/s
$defaultCrit = 500000; # 500 Ko/s

$plugin->add_arg(
		spec     => 'host|H=s',
		help     => '--host=IP',
		required => 1,
		);
$plugin->add_arg(
		spec     => 'community|C=s',
		help     => '--community=name',
		required => 1,
		);
$plugin->add_arg(
		spec     => 'interfaces|i=s',
		help     => '--interfaces=name1;name2;nameX (eg. "Ethernet1/0/1;Ethernet1/0/2;Ethernet1/0/5" or Ethernet1/0/11)',
		default	 => 'default',
		);
$plugin->add_arg(
		spec     => 'warning|w=i',
		default  => $defaultWarn,
		help     => '--warning=X bytes/s',
		);
$plugin->add_arg(
		spec     => 'critical|c=i',
		default  => $defaultCrit,
		help     => '--critical=X bytes/s',
		);
$plugin->add_arg(
		spec	 => 'view-interface|F=s',
		help	 => '--view-interface=all',
		default	 => 'no',
		);

$plugin->getopts();
my $options = $plugin->opts();

$ip = $options->get('host');
$community = $options->get('community');
$warningThresold = $options->get('warning');
$criticalThresold = $options->get('critical');
$viewInterface = $options->get('view-interface');
@interfacesNames = split(';', $options->get('interfaces'));

#foreach (@interfacesNames)
#{
#	print "$_\n";
#}
$badName = 0;

if($interfacesNames[0] ne "default")
{
	@interfacesIDs = getInterfacesIDs(@interfacesNames);
}
else
{
	$badName = 1;	
}

foreach (@interfacesIDs)
{
	print "$_\n";
}


if($viewInterface eq 'all' || $badName == 1)
{
	print getInterfacesName();
	exit $plugin->nagios_exit(UNKNOWN, "Lists interfaces.");
}

$dir = "/var/log/centreon/traffic/";
if(!(-d $dir))
{
	`mkdir $dir`;
}
if($warningThresold == 0)
{
	$warningThresold = $defaultWarn;
}
if($criticalThresold == 0)
{
	$criticalThresold = $defaultCrit;
}

$maxIN = 0;
$maxOUT = 0;
$totalIN = 0;
$totalOUT = 0;
$averageIN = 0;
$averageOUT = 0;
$dividerAverage = 0;

for($i = 0; $i < $#interfacesIDs + 1; $i++)
{
	$interfaceName = $interfacesNames[$i];
	$interfaceID = $interfacesIDs[$i];

	$totalBytesIN = getTotalBytes($interfaceID, $community, 1);
	$totalBytesOUT = getTotalBytes($interfaceID, $community, 0);
	$filename = "$ip.$interfaceID.$interfaceName.lastdata";
	$filename =~ s/\//-/g;
	$path = $dir . $filename;

	$toNextCheck = 0;
	if(-e $path)
	{
		open(FILE, "<$path");
		$lastdataIN = <FILE>;
		$lastdataOUT = <FILE>;
		$lasttime = <FILE>;
		close(FILE);
		my $diffIN = abs($totalBytesIN - $lastdataIN);
		my $diffOUT = abs($totalBytesOUT - $lastdataOUT);
		my $speedIN = $diffIN / (time - $lasttime);
		my $speedOUT = $diffOUT / (time - $lasttime);
		$bandwidthIN = $speedIN * 1; # * x seconds
			$bandwidthOUT = $speedOUT * 1; # * x seconds

			$totalIN += $speedIN;
		$totalOUT += $speedOUT;
		$dividerAverage++;
		if($speedIN > $maxIN)
		{
			$maxIN = $speedIN;
		}
		if($speedOUT > $maxOUT)
		{
			$maxOUT = $speedOUT;
		}


		$statusinfos = "";
		if($speedIN == 0 && $speedOUT == 0)
		{
			$status = "UNKNOWN";
			$statusinfos = "(Port maybe not connected)";
		}
		elsif($speedIN > $criticalThresold || $speedOUT > $criticalThresold)
		{
			$status = "CRITICAL";
			$statusinfos = "(>$criticalThresold)";
		}
		elsif($speedIN > $warningThresold || $speedOUT > $warningThresold)
		{
			$status = "WARNING";
			$statusinfos = "(>$warningThresold)";
		}
		else
		{
			$status = "OK";
		}
		writeFile();
	}
	else
	{
		$bandwidthIN = "Disponible au prochain check.";
		$toNextCheck = 1;
		$bandwidthOUT = $bandwidthIN;
		$status = "UNKNOWN";
		$statusinfos = "";
		writeFile();
	}
}

if($#interfacesIDs + 1 == 1)
{
	print "Bande passante $status $statusinfos: IN:";
	print getFormattedData($bandwidthIN);
	print "/s ; OUT:";
	print getFormattedData($bandwidthOUT);
	print "/s - $interfaceName in/out: " . getFormattedData($totalBytesIN) . "/" . getFormattedData($bandwidthOUT);
	if($toNextCheck == 0)
	{
		print "|";
		print "bandwidthIN=$bandwidthIN" . "octets/s; ";
		print "bandwidthOUT=$bandwidthOUT" . "octets/s;\n";
	}
}
else
{
	$averageIN = $totalIN / $dividerAverage;
	$averageOUT = $totalOUT / $dividerAverage;
	print "Max entrant/sortant : " . getFormattedData($maxIN) . "/" . getFormattedData($maxOUT) . " ; ";
	print "Total entrant/sortant : " . getFormattedData($totalIN) . "/" . getFormattedData($totalOUT) . " ; ";
	print "Moyenne entrant/sortant : " . getFormattedData($averageIN) . "/" . getFormattedData($averageOUT) . ".";
	print "|";
}

if($status eq "OK")
{
	exit $plugin->nagios_exit(OK, "Bandwidth OK" );
}
if($status eq "UNKNOWN")
{
	exit $plugin->nagios_exit(UNKNOWN, "Bandwidth UNKNOWN");
}
if($status eq "WARNING")
{
	exit $plugin->nagios_exit(WARNING, "Bandwidth WARNING");
}
if($status eq "CRITICAL")
{
	exit $plugin->nagios_exit(CRITICAL, "Bandwidth CRITICAL");
}

