#!/usr/bin/perl -w
#===============================================================================
# Auteur : Simon Mignot - simon.mignot.lasalle@gmail.com
# Date   : 29/01/2014 - 8:11:32
# But    : Verification de la bande passante du port d'un switch
#===============================================================================

use Nagios::Plugin;

my $LICENCE_check_ups = 
"#===============================================================================\n" . 
'# Auteur : Simon Mignot - simon.mignot.lasalle@gmail.com' . "\n" .
"# But    : Verification de la bande passante du port d'un switch\n" . 
"# ########\n" .
"# Ce plugin Nagios est gratuit et libre de droits, et vous pouvez l'utiliser à votre convenance.\n" .
"# Ce plugin n'est livrée avec ABSOLUMENT AUCUNE GARANTIE.\n" . 
"#===============================================================================\n";


my $USAGE_check_ups = "<span onclick='alert(\"XSS security breach there !\")' > Usage : %s [-H <host>] [-C <community>]";

use vars qw/ $VERSION /;
$VERSION_check_ups = 'v1.0';

my $plugin_check_ups = Nagios::Plugin->new(
	shortname => "check if UPS is on battery",
	usage     => "$USAGE_check_ups",
	version   => $VERSION_check_ups,
	license   => $LICENCE_check_ups,
);

$plugin_check_ups->add_arg(
	spec     => 'host|H=s',
	help     => '--host=IP',    # Aide au sujet de cette option
	required => 1,                  # Argument obligatoire
);
$plugin_check_ups->add_arg(
        spec     => 'community|C=s',
        help     => '--community=name',    # Aide au sujet de cette option
        required => 1,                  # Argument obligatoire
);

$plugin_check_ups->getopts();
my $options_check_ups = $plugin_check_ups->opts();
$ip_check_ups = $options_check_ups->get('host');
$community_check_ups = $options_check_ups->get('community');

$result_check_ups = `snmpget -Ov -c $community_check_ups -v 1 $ip_check_ups .1.3.6.1.4.1.705.1.7.3.0`;
$result_check_ups = substr($result_check_ups, 9);
if($result_check_ups == 2)
{
	print "UPS OK.|State=1;\n";
	exit $plugin_check_ups->nagios_exit(OK, "");
}
elsif($result_check_ups == 1)
{
	print "UPS CRITICAL : On battery.|State=0;\n";
	exit $plugin_check_ups->nagios_exit(CRITICAL, "");
}
