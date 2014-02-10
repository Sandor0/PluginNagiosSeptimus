#!/usr/bin/perl -w
#===============================================================================
# Auteur : Simon Mignot - simon.mignot.lasalle@gmail.com
# Date   : 29/01/2014 - 8:11:32
# But    : Verification de la bande passante du port d'un switch
#===============================================================================

use Math::Round;
use Nagios::Plugin;
use Net::SNMP;

sub in_array
{
        my ($arr, $search_for) = @_;
        foreach my $value (@$arr)
        {
                return 1 if $value eq $search_for;
        }
        return 0;
}

sub getParsedData
{
        my ($dataToParse) = @_;
        @array = ('K', 'M', 'G', 'T');
        if(in_array(\@array, substr($dataToParse,-1)))
        {
                my $unit = substr($dataToParse,-1);
                $parsedData = substr($dataToParse, 0, -1);
                if(!($parsedData =~ /^\d+\.*\d*$/))
                {
                        return 'Plusieurs unités ou unité non reconnue.';
                }
                $unit =~ s/K/1000/;             # 1 000 : 1Ko
                $unit =~ s/M/1000000/;          # 1 000 000 : 1Mo
                $unit =~ s/G/1000000000/;       # 1 000 000 000 : 1Go
                $unit =~ s/T/1000000000000/;    # 1 000 000 000 000 : 1To
                $parsedData *= $unit;
                return $parsedData;
        }
        else
        {
                if(!($dataToParse =~ /^\d+\.*\d*$/))
                {
                        return 'Unité non reconnue.';
                }
                return $dataToParse;
        }
        return 'critical error';

}

sub getInterfacesName
{
	$oid = '.1.3.6.1.2.1.2.2.1.2';
	$idIf = 0;
	$prevOid = -1;
	$return = '';
	while($idIf > $prevOid)
	{
		$SNMPSession->get_next_request($oid);
		$oid = ($SNMPSession->var_bind_names())[0];
		$ifName = $SNMPSession->get_request($oid)->{$oid};
		$prevOid = $idIf;
		$idIf = substr($oid, rindex($oid, '.') + 1);
		if($idIf < $prevOid)
		{
			last;
		}
		$return .= $ifName;
		$return .= "\n";
	}

	return $return;
}

sub getInterfacesIDs
{
	my (@names) = @_;
	foreach my $value (@names)
	{
		$currentID = getInterfaceID($value);
		if($currentID eq 'error')
		{
			return 'error';
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

	$oid = '.1.3.6.1.2.1.2.2.1.2';
	$idIf = 0;
	$prevOid = -1;

	while($idIf > $prevOid)
	{
		$SNMPSession->get_next_request($oid);
		$oid = ($SNMPSession->var_bind_names())[0];
		$ifName = $SNMPSession->get_request($oid)->{$oid};
		$prevOid = $idIf;
		$idIf = substr($oid, rindex($oid, '.') + 1);
		if($idIf < $prevOid)
		{
			return 'error';
		}
		if($ifName eq $name)
		{
			return $idIf;
		}
	}
	return 'error';
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
	my $oid = ".1.3.6.1.2.1.2.2.1.$sensID.$IDInterface";
	$hash = $SNMPSession->get_request($oid);
	return $hash->{$oid};
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

$defaultWarn = getParsedData('1M'); # 1 Mo/s
$defaultCrit = getParsedData('5M'); # 5 Mo/s

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
		spec     => 'warning|w=s',
		default  => $defaultWarn,
		help     => '--warning=X bytes/s',
		);
$plugin->add_arg(
		spec     => 'critical|c=s',
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
($SNMPSession, $error) = Net::SNMP->session(
		-hostname 	=> $ip,
		-community 	=> $community,
		-version	=> 1,
		-timeout	=> 5
		);
if(!defined($SNMPSession))
{
	print $error;
	exit -1;
}

$interfaceName = $options->get('interface');
$warningThresold = getParsedData($options->get('warning'));
$criticalThresold = getParsedData($options->get('critical'));
$viewInterface = $options->get('view-interface');
@interfacesNames = split(',', $options->get('interfaces'));
$badName = 0;
if($interfacesNames[0] ne "default")
{
	@interfacesIDs = getInterfacesIDs(@interfacesNames);
}
else
{
	$badName = 1;	
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

$status = '';
$statusinfo ='';
$global_crit = 0;
$global_warn = 0;
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


		if($speedIN == 0 && $speedOUT == 0)
		{
			$status = "UNKNOWN";
			$statusinfos = "(Port maybe not connected)";
		}
		elsif($speedIN > $criticalThresold || $speedOUT > $criticalThresold)
		{
			$status = "CRITICAL";
			$statusinfos = "(>$criticalThresold)";
			$global_crit = 1;
		}
		elsif($speedIN > $warningThresold || $speedOUT > $warningThresold)
		{
			$status = "WARNING";
			$statusinfos = "(>$warningThresold)";
			$global_warn = 1;
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
}
else
{
	$averageIN = $totalIN / $dividerAverage;
	$averageOUT = $totalOUT / $dividerAverage;
	print "Max entrant/sortant : " . getFormattedData($maxIN) . "/" . getFormattedData($maxOUT) . " ; ";
	print "Total entrant/sortant : " . getFormattedData($totalIN) . "/" . getFormattedData($totalOUT) . " ; ";
	print "Moyenne entrant/sortant : " . getFormattedData($averageIN) . "/" . getFormattedData($averageOUT) . ".";
	print "|";
	print "maxIN=$maxIN" . "octets/s; ";
	print "maxOUT=$maxOUT" . "octets/s; ";
	print "averageIN=$averageIN" . "octets/s; ";
	print "averageOUT=$averageOUT" . "octets/s; ";
	print "\n";
	if($global_crit == 1)
	{
		exit $plugin->nagios_exit(CRITICAL, "Bandwidth CRITICAL");
	}
	elsif($global_warn == 1)
	{
		exit $plugin->nagios_exit(WARNING, "Bandwidth WARNING");
	}
	elsif($status eq "UNKNOWN")
	{
		exit $plugin->nagios_exit(UNKNOWN, "Bandwidth UNKNOWN");
	}
	elsif($status eq "OK")
	{
		exit $plugin->nagios_exit(OK, "Bandwidth OK" );
	}
}


