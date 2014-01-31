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
	my ($IDInterface, $community) = @_;
        my $result = `snmpget -Ov -c $community -v 1 $ip .1.3.6.1.2.1.2.2.1.16.$IDInterface`;
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
        print FILE $totalBytes;
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

$plugin->add_arg(
	spec     => 'host|H=s',
	help     => '--host=IP',    # Aide au sujet de cette option
	required => 1,                  # Argument obligatoire
);
$plugin->add_arg(
        spec     => 'community|C=s',
        help     => '--community=name',    # Aide au sujet de cette option
        required => 1,                  # Argument obligatoire
);
$plugin->add_arg(
        spec     => 'interface|i=s',
        help     => '--interface=name (eg. Ethernet1/0/11)',    # Aide au sujet de cette option
        required => 1,                  # Argument obligatoire
);
$plugin->add_arg(
        spec     => 'warning|w=i',
	default  => 100000,
        help     => '--warning=X bytes/s',    # Aide au sujet de cette option
);
$plugin->add_arg(
        spec     => 'critical|c=i',
	default  => 500000,
        help     => '--critical=X bytes/s',    # Aide au sujet de cette option
);

$plugin->getopts();
my $options = $plugin->opts();

$ip = $options->get('host');
$community = $options->get('community');
$interfaceName = $options->get('interface');
$warningThresold = $options->get('warning');
$criticalThresold = $options->get('critical');
$interfaceID = getInterfaceID($interfaceName);
$totalBytes = getTotalBytes($interfaceID, $community);
$path = "/var/traffic/$interfaceID.lastdata";

if( -e $path)
{
	open(FILE, "<$path");
	$lastdata = <FILE>;
	$lasttime = <FILE>;
	close(FILE);
	my $diff = $totalBytes - $lastdata;
	my $speed = $diff / (time - $lasttime);
	$bandwidth = $speed * 1; # * x seconds
	$statusinfos = "";
	if($speed == 0)
	{
		$status = "UNKNOWN";
		$statusinfos = "(Port maybe not connected)";
	}
	elsif($speed > $criticalThresold)
	{
		$status = "CRITICAL";
		$statusinfos = "(>$criticalThresold)";
	}
	elsif($speed > $warningThresold)
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
	$bandwidth = "Disponible au prochain check.";
	$status = "UNKNOWN";
	$statusinfos = "";
	writeFile();
}
print "Bande passante $status $statusinfos: ";
print getFormattedData($bandwidth);
print "/s - $interfaceName : " . getFormattedData($totalBytes);

print "|";

print "bandwidth=";
print $bandwidth;
print "octets/s;$warningThresold;$criticalThresold;0\n";

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

