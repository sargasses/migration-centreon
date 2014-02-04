#!/bin/bash
#
# Copyright 2013-2014 
# Développé par : Stéphane HACQUARD
# Date : 04-02-2014
# Version 1.0
# Pour plus de renseignements : stephane.hacquard@sargasses.fr



#############################################################################
# Variables d'environnement
#############################################################################


DIALOG=${DIALOG=dialog}

REPERTOIRE_CONFIG=/usr/local/scripts/config
FICHIER_CENTRALISATION_SAUVEGARDE=config_centralisation_sauvegarde

DATE_HEURE=`date +%d.%m.%y`-`date +%H`h`date +%M`

NagiosLockFile=/usr/local/nagios/var/nagios.lock
Ndo2dbPidFile=/var/run/ndo2db/ndo2db.pid
NrpePidFile=/var/run/nrpe/nrpe.pid

CentenginePidFile=/var/run/centengine.pid
CbdbrokerPidFile=/var/run/cbd_central-broker.pid
CbdrrdPidFile=/var/run/cbd_central-rrd.pid
CentcorePidFile=/var/run/centreon/centcore.pid
CentstoragePidFile=/var/run/centreon/centstorage.pid


#############################################################################
# Fonction Verification installation de dialog
#############################################################################


if [ ! -f /usr/bin/dialog ] ; then
	echo "Le programme dialog n'est pas installé!"
	apt-get install dialog
else
	echo "Le programme dialog est déjà installé!"
fi


#############################################################################
# Fonction Activation De La Banner Pour SSH
#############################################################################


if grep "^#Banner" /etc/ssh/sshd_config > /dev/null ; then
	echo "Configuration de Banner en cours!"
	sed -i "s/#Banner/Banner/g" /etc/ssh/sshd_config 
	/etc/init.d/ssh reload
else 
	echo "Banner déjà activée!"
fi


#############################################################################
# Fonction Verification Plateforme 32 bits ou 64 bits
#############################################################################


if [ -d /lib64 ] ; then
	PLATEFORME_LOCAL=64
else
	PLATEFORME_LOCAL=32
fi


#############################################################################
# Fonction Lecture Fichier Configuration Gestion Centraliser Sauvegarde
#############################################################################

lecture_config_centraliser_sauvegarde()
{

if test -e $REPERTOIRE_CONFIG/$FICHIER_CENTRALISATION_SAUVEGARDE ; then

num=10
while [ "$num" -le 15 ] 
	do
	VAR=VAR$num
	VAL1=`cat $REPERTOIRE_CONFIG/$FICHIER_CENTRALISATION_SAUVEGARDE | grep $VAR=`
	VAL2=`expr length "$VAL1"`
	VAL3=`expr substr "$VAL1" 7 $VAL2`
	eval VAR$num="$VAL3"
	num=`expr $num + 1`
	done

else 

mkdir -p $REPERTOIRE_CONFIG

num=10
while [ "$num" -le 15 ] 
	do
	echo "VAR$num=" >> $REPERTOIRE_CONFIG/$FICHIER_CENTRALISATION_SAUVEGARDE
	num=`expr $num + 1`
	done

num=10
while [ "$num" -le 15 ] 
	do
	VAR=VALFIC$num
	VAL1=`cat $REPERTOIRE_CONFIG/$FICHIER_CENTRALISATION_SAUVEGARDE | grep $VAR=`
	VAL2=`expr length "$VAL1"`
	VAL3=`expr substr "$VAL1" 7 $VAL2`
	eval VAR$num="$VAL3"
	num=`expr $num + 1`
	done

fi

if [ "$VAR10" = "" ] ; then
	REF10=`uname -n`
else
	REF10=$VAR10
fi

if [ "$VAR11" = "" ] ; then
	REF11=3306
else
	REF11=$VAR11
fi

if [ "$VAR12" = "" ] ; then
	REF12=sauvegarde
else
	REF12=$VAR12
fi

if [ "$VAR13" = "" ] ; then
	REF13=root
else
	REF13=$VAR13
fi

if [ "$VAR14" = "" ] ; then
	REF14=directory
else
	REF14=$VAR14
fi

}

#############################################################################
# Fonction Lecture Des Valeurs Dans La Base de Donnée
#############################################################################

lecture_valeurs_base_donnees()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


cat <<- EOF > $fichtemp
select user
from sauvegarde_bases
where uname='`uname -n`' and application='centreon' ;
EOF

mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/lecture-user-local.txt

lecture_user_local=$(sed '$!d' /tmp/lecture-user-local.txt)
rm -f /tmp/lecture-user-local.txt
rm -f $fichtemp

cat <<- EOF > $fichtemp
select password
from sauvegarde_bases
where uname='`uname -n`' and application='centreon' ;
EOF

mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/lecture-password-local.txt

lecture_password_local=$(sed '$!d' /tmp/lecture-password-local.txt)
rm -f /tmp/lecture-password-local.txt
rm -f $fichtemp

cat <<- EOF > $fichtemp
select user
from sauvegarde_bases
where uname='`uname -n`' and application='centreon' ;
EOF

mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/lecture-user-distant.txt

lecture_user_distant=$(sed '$!d' /tmp/lecture-user-distant.txt)
rm -f /tmp/lecture-user-distant.txt
rm -f $fichtemp

cat <<- EOF > $fichtemp
select password
from sauvegarde_bases
where uname='`uname -n`' and application='centreon' ;
EOF

mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/lecture-password-distant.txt

lecture_password_distant=$(sed '$!d' /tmp/lecture-password-distant.txt)
rm -f /tmp/lecture-password-distant.txt
rm -f $fichtemp


cat <<- EOF > $fichtemp
select base
from sauvegarde_bases
where uname='$choix_serveur' and application='centreon' ;
EOF

mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/lecture-bases-sauvegarder.txt

sed -i '1d' /tmp/lecture-bases-sauvegarder.txt

lecture_bases_no1=$(sed -n '1p' /tmp/lecture-bases-sauvegarder.txt)
lecture_bases_no2=$(sed -n '2p' /tmp/lecture-bases-sauvegarder.txt)
lecture_bases_no3=$(sed -n '3p' /tmp/lecture-bases-sauvegarder.txt)
rm -f /tmp/lecture-bases-sauvegarder.txt
rm -f $fichtemp


REF20=$lecture_user_local
REF21=$lecture_password_local
REF22=$lecture_user_distant
REF23=$lecture_password_distant
REF24=$lecture_bases_no1
REF25=$lecture_bases_no2
REF26=$lecture_bases_no3

}

#############################################################################
# Fonction Message d'erreur
#############################################################################

message_erreur()
{
	
cat <<- EOF > /tmp/erreur
Veuillez vous assurer que les parametres saisie
                sont correcte
EOF

erreur=`cat /tmp/erreur`

$DIALOG --ok-label "Quitter" \
	 --colors \
	 --backtitle "Configuration Migration Centreon" \
	 --title "Erreur" \
	 --msgbox  "\Z1$erreur\Zn" 6 52 

rm -f /tmp/erreur

}

#############################################################################
# Fonction Message d'erreur sauvegarde
#############################################################################

message_erreur_sauvegarde()
{
	
cat <<- EOF > /tmp/erreur
Veuillez vous assurer que la sauvegarde 
             soit correcte 
EOF

erreur=`cat /tmp/erreur`

$DIALOG --ok-label "Quitter" \
	 --colors \
	 --backtitle "Configuration Migration Centreon" \
	 --title "Erreur" \
	 --msgbox  "\Z1$erreur\Zn" 6 44 

rm -f /tmp/erreur

}

#############################################################################
# Fonction Message d'erreur centreon
#############################################################################

message_erreur_centreon()
{
	
cat <<- EOF > /tmp/erreur
Veuillez vous assurer que centreon
           est installer
EOF

erreur=`cat /tmp/erreur`

$DIALOG --ok-label "Quitter" \
	 --colors \
	 --backtitle "Configuration Migration Centreon" \
	 --title "Erreur" \
	 --msgbox  "\Z1$erreur\Zn" 6 38 

rm -f /tmp/erreur

}

#############################################################################
# Fonction Message d'erreur ssh
#############################################################################

message_erreur_ssh()
{
	
cat <<- EOF > /tmp/erreur
Veuillez vous assurer que les parametres saisie
      pour la connexion au serveur en ssh    
                 sont correcte
EOF

erreur=`cat /tmp/erreur`

$DIALOG --ok-label "Quitter" \
	 --colors \
	 --backtitle "Configuration Migration Centreon" \
	 --title "Erreur" \
	 --msgbox  "\Z1$erreur\Zn" 7 52 

rm -f /tmp/erreur

}

#############################################################################
# Fonction Verification Couleur
#############################################################################

verification_couleur()
{


# 0=noir, 1=rouge, 2=vert, 3=jaune, 4=bleu, 5=magenta, 6=cyan 7=blanc

if ! grep -w "OUI" $REPERTOIRE_CONFIG/$FICHIER_CENTRALISATION_SAUVEGARDE > /dev/null ; then
	choix1="\Z1Gestion Centraliser des Sauvegardes\Zn" 
else
	choix1="\Z2Gestion Centraliser des Sauvegardes\Zn" 
fi

}

#############################################################################
# Fonction Menu 
#############################################################################

menu()
{

lecture_config_centraliser_sauvegarde
verification_couleur

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG --backtitle "Configuration Migration Centreon" \
	 --title "Configuration Migration Centreon" \
	 --clear \
	 --colors \
	 --default-item "3" \
	 --menu "Quel est votre choix" 12 60 4 \
	 "1" "$choix1" \
	 "2" "Configuration Migration Centreon" \
	 "3" "Quitter" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Gestion Centraliser des Sauvegardes
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
              menu_gestion_centraliser_sauvegardes
	fi

	# Configuration Migration Centreon
	if [ "$choix" = "2" ]
	then
		if [ "$VAR15" = "OUI" ] ; then
			rm -f $fichtemp
			menu_choix_serveur
		else
			rm -f $fichtemp
			message_erreur
			menu
		fi
	fi
	
	# Quitter
	if [ "$choix" = "3" ]
	then
		clear
	fi

	;;


 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

exit

}

#############################################################################
# Fonction Menu Gestion Centraliser des Sauvegardes
#############################################################################

menu_gestion_centraliser_sauvegardes()
{

lecture_config_centraliser_sauvegarde

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG --backtitle "Configuration Migration Centreon" \
	 --insecure \
	 --title "Gestion Centraliser des Sauvegardes" \
	 --mixedform "Quel est votre choix" 12 60 0 \
	 "Nom Serveur:"     1 1  "$REF10"  1 20  30 28 0  \
	 "Port Serveur:"    2 1  "$REF11"  2 20  30 28 0  \
	 "Base de Donnees:" 3 1  "$REF12"  3 20  30 28 0  \
	 "Compte Root:"     4 1  "$REF13"  4 20  30 28 0  \
	 "Password Root:"   5 1  "$REF14"  5 20  30 28 1  2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Gestion Centraliser des Sauvegardes
	VARSAISI10=$(sed -n 1p $fichtemp)
	VARSAISI11=$(sed -n 2p $fichtemp)
	VARSAISI12=$(sed -n 3p $fichtemp)
	VARSAISI13=$(sed -n 4p $fichtemp)
	VARSAISI14=$(sed -n 5p $fichtemp)
	

	sed -i "s/VAR10=$VAR10/VAR10=$VARSAISI10/g" $REPERTOIRE_CONFIG/$FICHIER_CENTRALISATION_SAUVEGARDE
	sed -i "s/VAR11=$VAR11/VAR11=$VARSAISI11/g" $REPERTOIRE_CONFIG/$FICHIER_CENTRALISATION_SAUVEGARDE
	sed -i "s/VAR12=$VAR12/VAR12=$VARSAISI12/g" $REPERTOIRE_CONFIG/$FICHIER_CENTRALISATION_SAUVEGARDE
	sed -i "s/VAR13=$VAR13/VAR13=$VARSAISI13/g" $REPERTOIRE_CONFIG/$FICHIER_CENTRALISATION_SAUVEGARDE
	sed -i "s/VAR14=$VAR14/VAR14=$VARSAISI14/g" $REPERTOIRE_CONFIG/$FICHIER_CENTRALISATION_SAUVEGARDE

      
	cat <<- EOF > /tmp/databases.txt
	SHOW DATABASES;
	EOF

	mysql -h $VARSAISI10 -P $VARSAISI11 -u $VARSAISI13 -p$VARSAISI14 < /tmp/databases.txt &>/tmp/resultat.txt

	if grep -w "^$VARSAISI12" /tmp/resultat.txt > /dev/null ; then
	sed -i "s/VAR15=$VAR15/VAR15=OUI/g" $REPERTOIRE_CONFIG/$FICHIER_CENTRALISATION_SAUVEGARDE

	else
	sed -i "s/VAR15=$VAR15/VAR15=NON/g" $REPERTOIRE_CONFIG/$FICHIER_CENTRALISATION_SAUVEGARDE
	message_erreur
	fi

	rm -f /tmp/databases.txt
	rm -f /tmp/resultat.txt
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

menu

}

#############################################################################
# Fonction Menu Choix Serveur
#############################################################################

menu_choix_serveur()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG --backtitle "Configuration Migration Centreon" \
	 --title "Configuration Migration Centreon" \
	 --form "Quel est votre choix" 8 50 1 \
	 "Migration Serveur:"  1 1  "`uname -n`"   1 20 20 0  2> $fichtemp


valret=$?
choix_serveur=`cat $fichtemp`
case $valret in

 0)	# Choix Migration Serveur
	
	if [ "$choix_serveur" != `uname -n` ] ; then
	
		cat <<- EOF > $fichtemp
		select uname
		from information
		where uname='$choix_serveur' and application='centreon' ;
		EOF

		mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /tmp/lecture-serveur-distant.txt

		lecture_serveur_distant=$(sed '$!d' /tmp/lecture-serveur-distant.txt)

		rm -f $fichtemp

		cat <<- EOF > $fichtemp
		select uname
		from information
		where uname='`uname -n`' and application='centreon' ;
		EOF

		mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /tmp/lecture-serveur-local.txt

		lecture_serveur_local=$(sed '$!d' /tmp/lecture-serveur-local.txt)
		
		rm -f $fichtemp


		if grep -w "^$choix_serveur" /tmp/lecture-serveur-distant.txt > /dev/null &&
		   grep -w "^`uname -n`" /tmp/lecture-serveur-local.txt > /dev/null ; then

			rm -f /tmp/lecture-serveur-distant.txt
			rm -f /tmp/lecture-serveur-local.txt
			menu_configuration_migration_centreon
		else
			rm -f /tmp/lecture-serveur-distant.txt
			rm -f /tmp/lecture-serveur-local.txt
			message_erreur_sauvegarde
		fi	

	else

		cat <<- EOF > $fichtemp
		select uname
		from information
		where uname='`uname -n`' and application='centreon' ;
		EOF

		mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /tmp/lecture-serveur-local.txt

		lecture_serveur_local=$(sed '$!d' /tmp/lecture-serveur-local.txt)

		if grep -w "^`uname -n`" /tmp/lecture-serveur-local.txt > /dev/null ; then
			rm -f /tmp/lecture-serveur-local.txt
			rm -f $fichtemp
			menu_configuration_migration_centreon
		else
			rm -f /tmp/lecture-serveur-local.txt
			rm -f $fichtemp
			message_erreur_sauvegarde
		fi

	fi

	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

menu

}

#############################################################################
# Fonction Menu Configuration Migration Centreon
#############################################################################

menu_configuration_migration_centreon()
{

lecture_valeurs_base_donnees

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG --backtitle "Configuration Migration Centreon" \
	 --insecure \
	 --title "Connexion Serveur SSH Distant" \
	 --mixedform "Quel est votre choix" 11 60 0 \
	 "Nom Serveur:"   1 1  "$choix_serveur"  1 20  30 28 0  \
	 "Port Serveur:"  2 1  "22"              2 20  30 28 0  \
	 "Compte Root:"   3 1  "root"            3 20  30 28 0  \
	 "Password Root:" 4 1  ""                4 20  30 28 1  2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Configuration Migration Centreon
	VARSAISI20=$(sed -n 1p $fichtemp)
	VARSAISI21=$(sed -n 2p $fichtemp)
	VARSAISI22=$(sed -n 3p $fichtemp)
	VARSAISI23=$(sed -n 4p $fichtemp)

	sshpass -p $VARSAISI23 ssh -o StrictHostKeyChecking=no -p $VARSAISI21 $VARSAISI22@$VARSAISI20 "exit" &> /dev/null
	sshpass -p $VARSAISI23 scp -P $VARSAISI21 -p $VARSAISI22@$VARSAISI20:/etc/hostname /tmp/ &> /dev/null

	if [ -f /tmp/hostname ] ; then

		if grep -w "$choix_serveur" /tmp/hostname > /dev/null ; then
			rm -f /tmp/hostname
			rm -f $fichtemp
			migration_serveur_centreon
		else
			rm -f /tmp/hostname
			rm -f $fichtemp
			message_erreur_ssh
			menu
		fi

	else
		rm -f /tmp/hostname
		rm -f $fichtemp
		message_erreur_ssh
		menu
	fi

	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

menu

}

#############################################################################
# Fonction Migration Serveur Centreon
#############################################################################

migration_serveur_centreon()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


(
 echo "10" ; sleep 1
 echo "XXX" ; echo "Migration en cours veuillez patienter"; echo "XXX"

	cat <<- EOF > migration.sh
	if [ -d /usr/local/nagios/libexec ] ; then
		PLUGINS=/usr/local/nagios/libexec
	fi

	if [ -d /usr/local/centreon-plugins/libexec ] ; then
		PLUGINS=/usr/local/centreon-plugins/libexec
	fi

	mkdir -p /root/dump-mysql/
	mkdir -p /root/dump-rrd/
	mkdir -p /root/dump-rrd/metrics
	mkdir -p /root/dump-rrd/nagios-perf
	mkdir -p /root/dump-rrd/nagios-perf/perfmon-1
	mkdir -p /root/dump-rrd/status

	cd /var/lib/centreon/metrics
	for i in \`find -name "*.rrd"\`; do rrdtool dump \$i > /root/dump-rrd/metrics/\$i.xml; done

	cd /var/lib/centreon/nagios-perf/perfmon-1
	for i in \`find -name "*.rrd"\`; do rrdtool dump \$i > /root/dump-rrd/nagios-perf/perfmon-1/\$i.xml; done

	cd /var/lib/centreon/status
	for i in \`find -name "*.rrd"\`; do rrdtool dump \$i > /root/dump-rrd/status/\$i.xml; done


	cd /root

	mysqldump -h \`uname -n\` -u $REF22 -p$REF23 $REF24 --databases > /root/dump-mysql/$REF24.sql

	tar cfvz migration-centreon.tgz \$PLUGINS/ /usr/local/centreon/www/img/media/ /etc/centreon/ dump-rrd/ -P

	rm -rf dump-mysql/
	rm -rf dump-rrd/
	EOF


 echo "20" ; sleep 1
 echo "XXX" ; echo "Migration en cours veuillez patienter"; echo "XXX"


	#sshpass -p $VARSAISI23 scp -P $VARSAISI21 -p  migration.sh $VARSAISI22@$VARSAISI20:/root &> /dev/null
	#sshpass -p $VARSAISI23 ssh -o StrictHostKeyChecking=no -p $VARSAISI21 $VARSAISI22@$VARSAISI20 "chmod 755 migration.sh" &> /dev/null
	#sshpass -p $VARSAISI23 ssh -o StrictHostKeyChecking=no -p $VARSAISI21 $VARSAISI22@$VARSAISI20 "./migration.sh" &> /dev/null


	#rm -f migration.sh


 echo "30" ; sleep 1
 echo "XXX" ; echo "Migration en cours veuillez patienter"; echo "XXX"

	if [ -f $NagiosLockFile ] ; then
	/etc/init.d/nagios stop &> /dev/null
	fi

	if [ -f $Ndo2dbPidFile ] ; then
	/etc/init.d/ndo2db stop &> /dev/null
	fi

	if [ -f $CentenginePidFile ] ; then
	/etc/init.d/centengine stop &> /dev/null
	fi

	if [ -f $CbdbrokerPidFile ] || [ -f $CbdrrdPidFile ] ; then	
	/etc/init.d/cbd stop &> /dev/null
	fi

	if [ -f $CentcorePidFile ] ; then
	/etc/init.d/centcore stop &> /dev/null
	fi

	if [ -f $CentstoragePidFile ] ; then
	/etc/init.d/centstorage stop &> /dev/null
	fi

 echo "30" ; sleep 1
 echo "XXX" ; echo "Migration en cours veuillez patienter"; echo "XXX"
	

 echo "60" ; sleep 1
 echo "XXX" ; echo "Migration en cours veuillez patienter"; echo "XXX"




 echo "80" ; sleep 1
 echo "XXX" ; echo "Migration en cours veuillez patienter"; echo "XXX"

	

 echo "90" ; sleep 1
 echo "XXX" ; echo "Migration en cours veuillez patienter"; echo "XXX"

	if [ -f /usr/local/nagios/bin/nagios ] ; then
	/etc/init.d/nagios start &> /dev/null
	fi

	if [ -f /usr/local/nagios/bin/ndo2db ] ; then
	/etc/init.d/ndo2db start &> /dev/null
	fi

	if [ -f /usr/local/centreon-engine/bin/centengine ] ; then
	/etc/init.d/centengine start &> /dev/null
	fi

	if [ -f /usr/local/centreon-broker/etc/central-broker.xml ] ; then
	/etc/init.d/cbd start &> /dev/null
	fi

	/etc/init.d/centcore start &> /dev/null

	if [ ! -d /usr/local/centreon-broker ] ; then
	/etc/init.d/centstorage start &> /dev/null
	fi
	
 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG --backtitle "Configuration Migration Centreon" \
	 --title "Configuration Migration Centreon" \
	 --gauge "Migration en cours veuillez patienter" 10 62 0 \

}

#############################################################################
# Demarrage du programme
#############################################################################

menu