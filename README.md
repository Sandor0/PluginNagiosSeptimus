# Plugins pour nagios.

## check_traffic.pl
Permet de tester le traffic du port d'un switch, entrant et sortant.
Génére les données de performance permettant de tracer un graphique.

Ce script peut prendre en paramètre le nom d'une interface (port du switch) et retourne le traffic depuis la dernière verification.

Il peut aussi prendre une liste d'interfaces, séparé par une virgule, et retourne le traffic maximum de ces interfaces, ainsi que la moyenne des tous les ports.

Chaque mesure est faite sur le traffic ENTRANT et le traffic SORTANT.

Si l'interface n'est pas trouvé, le script retourne la liste de toutes les interfaces trouvés sur le switch.

### Help command

```
#===============================================================================
# Auteur : Simon Mignot - simon.mignot.lasalle@gmail.com
# But    : Verification de la bande passante du port d'un switch
# ########
# Ce plugin Nagios est gratuit et libre de droits, et vous pouvez l'utiliser à votre convenance.
# Ce plugin n'est livrée avec ABSOLUMENT AUCUNE GARANTIE.
#===============================================================================

Usage : check_traffic.pl [-H <host>] [-C <community>] [-i <interfaces name>] [-w <warning>] [-c <critical>]

 -?, --usage
   Print usage information
 -h, --help
   Print detailed help screen
 -V, --version
   Print version information
 --extra-opts=[section][@file]
   Read options from an ini file. See http://nagiosplugins.org/extra-opts
   for usage and examples.
 --host=IP
 --community=name
 --interfaces=name (eg. Ethernet1/0/1,Ethernet1/0/2,Ethernet1/0/3 or Ethernet1/0/11)
 --warning=X bytes/s
 --critical=X bytes/s
 -t, --timeout=INTEGER
   Seconds before plugin times out (default: 15)
 -v, --verbose
   Show details for command-line debugging (can repeat up to 3 times)
```

## check_UPS.pl
Permet de tester si un onduleur est sur batterie ou sur secteur.
Retourne OK sur secteur et CRITICAL sur batterie.
Le graphique généré est à 1 si OK, 0 si CRITICAL.

### Help command

```
#===============================================================================
# Auteur : Simon Mignot - simon.mignot.lasalle@gmail.com
# But    : Verification de la bande passante du port d'un switch
# ########
# Ce plugin Nagios est gratuit et libre de droits, et vous pouvez l'utiliser à votre convenance.
# Ce plugin n'est livrée avec ABSOLUMENT AUCUNE GARANTIE.
#===============================================================================

Usage : check_UPS.pl [-H <host>] [-C <community>]

 -?, --usage
   Print usage information
 -h, --help
   Print detailed help screen
 -V, --version
   Print version information
 --extra-opts=[section][@file]
   Read options from an ini file. See http://nagiosplugins.org/extra-opts
   for usage and examples.
 --host=IP
 --community=name
 -t, --timeout=INTEGER
   Seconds before plugin times out (default: 15)
 -v, --verbose
   Show details for command-line debugging (can repeat up to 3 times)
```
