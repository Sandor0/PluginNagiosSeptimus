#!/usr/bin/perl -w
#===============================================================================
# Auteur : Simon Mignot - simon.mignot.lasalle@gmail.com
# Date   : 29/01/2014 - 8:11:32
# But    : Verification de la bande passante du port d'un switch
# Site   : https://github.com/Sandor0/PluginNagiosSeptimus
#===============================================================================

use Nagios::Plugin;
use Net::SNMP;

my $LICENCE = 
"#===============================================================================\n" . 
'# Auteur : Simon Mignot - simon.mignot.lasalle@gmail.com' . "\n" .
"# But    : Verification de la bande passante du port d'un switch\n" . 
"# Site   : https://github.com/Sandor0/PluginNagiosSeptimus\n" .
"# ########\n" .
"# Ce plugin Nagios est gratuit et libre de droits, et vous pouvez l'utiliser à votre convenance.\n" .
"# Ce plugin n'est livrée avec ABSOLUMENT AUCUNE GARANTIE.\n" . 
"#===============================================================================\n";


my $USAGE = "Usage : %s [-H <host>] [-C <community>]";

use vars qw/ $VERSION /;
$VERSION = 'v1.1';

my $plugin = Nagios::Plugin->new(
	shortname => "check if UPS is on battery",
	usage     => $USAGE,
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

$plugin->getopts();
my $options = $plugin->opts();
$ip = $options->get('host');
$community = $options->get('community');

($SNMPSession, $error) = Net::SNMP->session(
                -hostname       => $ip,
                -community      => $community,
                -version        => 1,
                -timeout        => 5
                );
if(!defined($SNMPSession))
{
        print $error;
        exit -1;
}

$oid = ".1.3.6.1.4.1.705.1.7.3.0";
$hash = $SNMPSession->get_request($oid);

if($hash->{$oid} == 2)
{
	print "UPS OK.|on_state=1; off_state=0;\n";
	exit $plugin->nagios_exit(OK, "");
}
elsif($hash->{$oid} == 1)
{
	print "UPS CRITICAL : On battery.|off_state=1; on_state=0;\n";
	exit $plugin->nagios_exit(CRITICAL, "");
}
