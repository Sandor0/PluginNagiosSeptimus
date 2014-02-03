#!/usr/bin/perl -w
#===============================================================================
# Auteur : Simon Mignot - simon.mignot.lasalle@gmail.com
# Date   : 29/01/2014 - 8:11:32
# But    : Verification de la bande passante du port d'un switch
#===============================================================================

use Time::HiRes;
use Math::Round;
use Nagios::Plugin;

sub getInterfaceID
{
	my ($name) = @_;
	$commandId = `snmpwalk -Os -c cove -v 1 $ip .1.3.6.1.2.1.2.2.1.2 | grep $name`;
	chop($commandId);
	$commandId = substr($commandId, 8);
	$length = index($commandId, "=") - 1;
	return substr($commandId, 0, $length);
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
        if($speed < 750)
        {
		$speed = nearest(.001, $speed);
                return "$speed octets";
        }
        if($speed >= 750 && $speed < 75000)
        {
                $speed = nearest(.001, $speed / 1000);
                return "$speed Ko";
        }
        if($speed >= 75000 && $speed < 75000000)
        {
                $speed = nearest(.001, $speed / 100000);
                return "$speed Mo";
        }
        if($speed >= 75000000)
        {
                $speed = nearest(.001, $speed / 100000000);
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


my $USAGE = "Usage : %s [-H <host>] [-C <community>] [-i <interface name>] [-w <warning>] [-c <critical>]";

use vars qw/ $VERSION /;
$VERSION = 'v1.0';

my $plugin = Nagios::Plugin->new(
	shortname => "check switch's bandwidth",
	usage     => "$USAGE",
	version   => $VERSION,
	license   => $LICENCE,
);

$defaultWarn = 100000;
$defaultCrit = 500000;

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
        spec     => 'interface|i=s',
        help     => '--interface=name (eg. Ethernet1/0/11)',
        required => 1,
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

$plugin->getopts();
my $options = $plugin->opts();

$ip = $options->get('host');
$community = $options->get('community');
$interfaceName = $options->get('interface');
$warningThresold = $options->get('warning');
$criticalThresold = $options->get('critical');
$interfaceID = getInterfaceID($interfaceName);
$totalBytesIN = getTotalBytes($interfaceID, $community, 1);
$totalBytesOUT = getTotalBytes($interfaceID, $community, 0);
$path = "/var/traffic/$interfaceID.lastdata";

if($warningThresold == 0)
{
	$warningThresold = $defaultWarn;
}
if($criticalThresold == 0)
{
	$criticalThresold = $defaultCrit;
}

if( -e $path)
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
	$bandwidthOUT = $bandwidthIN;
	$status = "UNKNOWN";
	$statusinfos = "";
	writeFile();
}
print "Bande passante $status $statusinfos: IN:";
print getFormattedData($bandwidthIN);
print "/s ; OUT:";
print getFormattedData($bandwidthOUT);
print "/s - $interfaceName in/out: " . getFormattedData($totalBytesIN) . "/" . getFormattedData($bandwidthOUT);

print "|";

print "bandwidthIN=$bandwidthIN" . "octets/s; ";
print "bandwidthOUT=$bandwidthOUT" . "octets/s;\n";


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

