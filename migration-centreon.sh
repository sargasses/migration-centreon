#!/bin/bash
#
# Copyright 2013-2014 
# Développé par : Stéphane HACQUARD
# Date : 23-02-2014
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
where uname='$choix_serveur' and application='centreon' ;
EOF

mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/lecture-user-distant.txt

lecture_user_distant=$(sed '$!d' /tmp/lecture-user-distant.txt)
rm -f /tmp/lecture-user-distant.txt
rm -f $fichtemp

cat <<- EOF > $fichtemp
select password
from sauvegarde_bases
where uname='$choix_serveur' and application='centreon' ;
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
# Fonction Message d'erreur migration
#############################################################################

message_erreur_migration()
{
	
cat <<- EOF > /tmp/erreur
Veuillez vous assurer que le nom du serveur a migrer
                ne soit pas lui meme
EOF

erreur=`cat /tmp/erreur`

$DIALOG --ok-label "Quitter" \
	 --colors \
	 --backtitle "Configuration Migration Centreon" \
	 --title "Erreur" \
	 --msgbox  "\Z1$erreur\Zn" 6 56 

rm -f /tmp/erreur

}

#############################################################################
# Fonction Message d'erreur fichier
#############################################################################

message_erreur_fichier()
{
	
cat <<- EOF > /tmp/erreur
Le fichier *.tgz n'est pas present sur le serveur 
      la migration n'est donc pas possible
EOF

erreur=`cat /tmp/erreur`

$DIALOG --ok-label "Quitter" \
	 --colors \
	 --backtitle "Configuration Migration Centreon" \
	 --title "Erreur" \
	 --msgbox  "\Z1$erreur\Zn" 6 54 

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
	 --form "Quel est votre choix" 9 60 1 \
	 "Migration Serveur:"  1 1  "`uname -n`" 1 20 34 18 2> $fichtemp


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
		rm -f $fichtemp
		message_erreur_migration
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

	nmap --unprivileged $VARSAISI20 -p $VARSAISI21 > /tmp/nmap.txt 

	if ! grep -w "open" /tmp/nmap.txt > /dev/null ; then
		rm -f /tmp/nmap.txt
		rm -f $fichtemp
		message_erreur_ssh
		menu
	else
		rm -f /tmp/nmap.txt
		sshpass -p $VARSAISI23 ssh -o StrictHostKeyChecking=no -p $VARSAISI21 $VARSAISI22@$VARSAISI20 "exit" &> /dev/null
		sshpass -p $VARSAISI23 scp -P $VARSAISI21 $VARSAISI22@$VARSAISI20:/etc/hostname /tmp/ &> /dev/null
	fi


	if [ -f /tmp/hostname ] ; then

		if grep -w "$choix_serveur" /tmp/hostname > /dev/null ; then
			rm -f /tmp/hostname
			rm -f $fichtemp
			fonction_verification_plateforme_serveur_distant
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
# Fonction Verification Plateforme 32 bits ou 64 bits Serveur Distant
#############################################################################

fonction_verification_plateforme_serveur_distant()
{

cat <<- EOF > plateforme.sh
if [ -d /lib64 ] ; then
       PLATEFORME_DISTANT=64
else
       PLATEFORME_DISTANT=32
fi

echo "\$PLATEFORME_DISTANT" > plateforme-distant.txt
EOF

sshpass -p $VARSAISI23 scp -P $VARSAISI21 plateforme.sh $VARSAISI22@$VARSAISI20:/root &> /dev/null
sshpass -p $VARSAISI23 ssh -o StrictHostKeyChecking=no -p $VARSAISI21 $VARSAISI22@$VARSAISI20 "chmod 755 plateforme.sh" &> /dev/null
sshpass -p $VARSAISI23 ssh -o StrictHostKeyChecking=no -p $VARSAISI21 $VARSAISI22@$VARSAISI20 "./plateforme.sh" &> /dev/null
sshpass -p $VARSAISI23 scp -P $VARSAISI21 $VARSAISI22@$VARSAISI20:/root/plateforme-distant.txt /root/ &> /dev/null
sshpass -p $VARSAISI23 ssh -o StrictHostKeyChecking=no -p $VARSAISI21 $VARSAISI22@$VARSAISI20 "rm -f /root/plateforme.sh ; rm -f /root/plateforme-distant.txt" &> /dev/null


PLATEFORME_DISTANT=`cat plateforme-distant.txt`

rm -f plateforme.sh
rm -f plateforme-distant.txt
echo "Plateforme distante: $PLATEFORME_DISTANT"		

fonction_verification_engine_serveur_distant

}

#############################################################################
# Fonction Verification Engine Serveur Distant
#############################################################################

fonction_verification_engine_serveur_distant()
{

cat <<- EOF > engine.sh
fichtemp=\`tempfile 2>/dev/null\` || fichtemp=/tmp/test\$$

if [ -f /etc/centreon/instCentWeb.conf ] ; then
       grep "^MONITORINGENGINE_ETC=" /etc/centreon/instCentWeb.conf  > \$fichtemp
       sed -i "s/MONITORINGENGINE_ETC=//g" \$fichtemp
       ENGINE_DISTANT=\`cat \$fichtemp\` 
fi

echo "\$ENGINE_DISTANT" > engine-distant.txt
EOF

sshpass -p $VARSAISI23 scp -P $VARSAISI21 engine.sh $VARSAISI22@$VARSAISI20:/root &> /dev/null
sshpass -p $VARSAISI23 ssh -o StrictHostKeyChecking=no -p $VARSAISI21 $VARSAISI22@$VARSAISI20 "chmod 755 engine.sh" &> /dev/null
sshpass -p $VARSAISI23 ssh -o StrictHostKeyChecking=no -p $VARSAISI21 $VARSAISI22@$VARSAISI20 "./engine.sh" &> /dev/null
sshpass -p $VARSAISI23 scp -P $VARSAISI21 $VARSAISI22@$VARSAISI20:/root/engine-distant.txt /root/ &> /dev/null
sshpass -p $VARSAISI23 ssh -o StrictHostKeyChecking=no -p $VARSAISI21 $VARSAISI22@$VARSAISI20 "rm -f /root/engine.sh ; rm -f /root/engine-distant.txt" &> /dev/null


ENGINE_DISTANT=`cat engine-distant.txt`

rm -f engine.sh
rm -f engine-distant.txt
echo "Engine distant: $ENGINE_DISTANT"		

menu_confirmation_migration_centreon

}

#############################################################################
# Fonction Menu Confirmation Migration Centreon
#############################################################################

menu_confirmation_migration_centreon()
{

lecture_valeurs_base_donnees

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG --backtitle "Configuration Migration Centreon" \
	 --colors \
	 --title "Confirmation Migration Centreon" \
	 --menu "Quel est votre choix" 7 66 0 \
	 "Utilisateur de la Base Local:"   "\Z2$REF20\Zn" \
	 "Password de la Base Local:"      "\Z2$REF21\Zn" \
	 "Utilisateur de la Base Distant:" "\Z2$REF22\Zn" \
	 "Password de la Base Distant:"    "\Z2$REF23\Zn" \
	 "Nom de la Base:"                 "\Z2$REF24\Zn" \
	 "Nom de la Base:"                 "\Z2$REF25\Zn" \
	 "Nom de la Base:"                 "\Z2$REF26\Zn" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Confirmation Migration Centreon (Oui)
	VARSAISI30=$REF20
	VARSAISI31=$REF21
	VARSAISI32=$REF22
	VARSAISI33=$REF23
	VARSAISI34=$REF24
	VARSAISI35=$REF25
	VARSAISI36=$REF26

	rm -f $fichtemp
	migration_serveur_centreon
	;;


 1)	# Confirmation Migration Centreon (Non)
	echo "Appuyé sur Touche (Non)"
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

	if [ $PLATEFORME_LOCAL -ne $PLATEFORME_DISTANT ] ; then

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

		mysqldump -h \`uname -n\` -u $VARSAISI32 -p$VARSAISI33 $VARSAISI34 --databases > /root/dump-mysql/$VARSAISI34.sql
		mysqldump -h \`uname -n\` -u $VARSAISI32 -p$VARSAISI33 $VARSAISI35 --databases > /root/dump-mysql/$VARSAISI35.sql
		mysqldump -h \`uname -n\` -u $VARSAISI32 -p$VARSAISI33 $VARSAISI36 --databases > /root/dump-mysql/$VARSAISI36.sql

		tar cfvz migration-centreon.tgz \$PLUGINS/ /usr/local/centreon/www/img/media/ /etc/centreon/ dump-rrd/ dump-mysql/ -P

		rm -rf dump-mysql/
		rm -rf dump-rrd/
		EOF

	else

		cat <<- EOF > migration.sh
		if [ -d /usr/local/nagios/libexec ] ; then
		       PLUGINS=/usr/local/nagios/libexec
		fi

		if [ -d /usr/local/centreon-plugins/libexec ] ; then
		       PLUGINS=/usr/local/centreon-plugins/libexec
		fi

		mkdir -p /root/dump-mysql/
	

		cd /root

		mysqldump -h \`uname -n\` -u $VARSAISI32 -p$VARSAISI33 $VARSAISI34 --databases > /root/dump-mysql/$VARSAISI34.sql
		mysqldump -h \`uname -n\` -u $VARSAISI32 -p$VARSAISI33 $VARSAISI35 --databases > /root/dump-mysql/$VARSAISI35.sql
		mysqldump -h \`uname -n\` -u $VARSAISI32 -p$VARSAISI33 $VARSAISI36 --databases > /root/dump-mysql/$VARSAISI36.sql

		tar cfvz migration-centreon.tgz \$PLUGINS/ /usr/local/centreon/www/img/media/ /var/lib/centreon/ /etc/centreon/ dump-mysql/ -P

		rm -rf dump-mysql/
		EOF

	fi

 echo "20" ; sleep 1
 echo "XXX" ; echo "Migration en cours veuillez patienter"; echo "XXX"

	sshpass -p $VARSAISI23 scp -P $VARSAISI21 -p  migration.sh $VARSAISI22@$VARSAISI20:/root &> /dev/null

	rm -f migration.sh	

	sshpass -p $VARSAISI23 ssh -o StrictHostKeyChecking=no -p $VARSAISI21 $VARSAISI22@$VARSAISI20 "chmod 755 migration.sh" &> /dev/null
	sshpass -p $VARSAISI23 ssh -o StrictHostKeyChecking=no -p $VARSAISI21 $VARSAISI22@$VARSAISI20 "./migration.sh" &> /dev/null
	sshpass -p $VARSAISI23 scp -P $VARSAISI21 $VARSAISI22@$VARSAISI20:/root/migration-centreon.tgz /root/ &> /dev/null
	sshpass -p $VARSAISI23 ssh -o StrictHostKeyChecking=no -p $VARSAISI21 $VARSAISI22@$VARSAISI20 "rm -f /root/migration.sh ; rm -f /root/migration-centreon.tgz" &> /dev/null

) |
$DIALOG --backtitle "Configuration Migration Centreon" \
	 --title "Configuration Migration Centreon" \
	 --gauge "Migration en cours veuillez patienter" 10 62 0 \


(
 echo "30" ; sleep 1
) |
$DIALOG --backtitle "Configuration Migration Centreon" \
	 --title "Configuration Migration Centreon" \
	 --gauge "Migration en cours veuillez patienter" 10 62 0 \

	
	if [ -f migration-centreon.tgz ] ; then
		tar xvzf migration-centreon.tgz &> /dev/null
	else
		message_erreur_fichier
		menu
	fi

(
 echo "40" ; sleep 1
 echo "XXX" ; echo "Migration en cours veuillez patienter"; echo "XXX"

	grep "hostCentreon" /etc/centreon/centreon.conf.php > $fichtemp
	sed -n 's/.* =\ \(.*\);.*/\1/ip' $fichtemp > /tmp/lecture-serveur-centreon-local.txt 
	sed -i 's/\"//g' /tmp/lecture-serveur-centreon-local.txt
	lecture_serveur_centreon_local=`cat /tmp/lecture-serveur-centreon-local.txt`
	rm -f /tmp/lecture-serveur-centreon-local.txt
	rm -f $fichtemp

	grep "user" /etc/centreon/centreon.conf.php > $fichtemp
	sed -n 's/.* =\ \(.*\);.*/\1/ip' $fichtemp > /tmp/lecture-utilisateur-centreon-local.txt 
	sed -i 's/\"//g' /tmp/lecture-utilisateur-centreon-local.txt
	lecture_utilisateur_centreon_local=`cat /tmp/lecture-utilisateur-centreon-local.txt`
	rm -f /tmp/lecture-utilisateur-centreon-local.txt
	rm -f $fichtemp


	grep "hostCentreon" etc/centreon/centreon.conf.php > $fichtemp
	sed -n 's/.* =\ \(.*\);.*/\1/ip' $fichtemp > /tmp/lecture-serveur-centreon-distant.txt 
	sed -i 's/\"//g' /tmp/lecture-serveur-centreon-distant.txt
	lecture_serveur_centreon_distant=`cat /tmp/lecture-serveur-centreon-distant.txt`
	rm -f /tmp/lecture-serveur-centreon-distant.txt
	rm -f $fichtemp

	grep "user" etc/centreon/centreon.conf.php > $fichtemp
	sed -n 's/.* =\ \(.*\);.*/\1/ip' $fichtemp > /tmp/lecture-utilisateur-centreon-distant.txt 
	sed -i 's/\"//g' /tmp/lecture-utilisateur-centreon-distant.txt
	lecture_utilisateur_centreon_distant=`cat /tmp/lecture-utilisateur-centreon-distant.txt`
	rm -f /tmp/lecture-utilisateur-centreon-distant.txt
	rm -f $fichtemp

	grep "password" etc/centreon/centreon.conf.php > $fichtemp
	sed -n 's/.* =\ \(.*\);.*/\1/ip' $fichtemp > /tmp/lecture-password-centreon-distant.txt 
	sed -i 's/\"//g' /tmp/lecture-password-centreon-distant.txt
	lecture_password_centreon_distant=`cat /tmp/lecture-password-centreon-distant.txt`
	rm -f /tmp/lecture-password-centreon-distant.txt
	rm -f $fichtemp


	if [ "$lecture_utilisateur_centreon_local" != "" ] ; then

		cat <<- EOF > $fichtemp
		use mysql;
		SELECT Db FROM db WHERE User='$lecture_utilisateur_centreon_local';
		EOF

		mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < $fichtemp > /tmp/lecture-bases-supprimer.txt


		sed -i '1d' /tmp/lecture-bases-supprimer.txt

		lecture_bases_supprimer_no1=$(sed -n '1p' /tmp/lecture-bases-supprimer.txt)
		lecture_bases_supprimer_no2=$(sed -n '2p' /tmp/lecture-bases-supprimer.txt)
		lecture_bases_supprimer_no3=$(sed -n '3p' /tmp/lecture-bases-supprimer.txt)
		rm -f /tmp/lecture-bases-supprimer.txt
		rm -f $fichtemp


		if [ "$lecture_bases_supprimer_no1" != "" ] ||
	          [ "$lecture_bases_supprimer_no2" != "" ] ||
	          [ "$lecture_bases_supprimer_no3" != "" ] ; then


			cat <<- EOF > $fichtemp
			DROP DATABASE IF EXISTS $lecture_bases_supprimer_no1;
			EOF

			mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < $fichtemp

			rm -f $fichtemp


			cat <<- EOF > $fichtemp
			DROP DATABASE IF EXISTS $lecture_bases_supprimer_no2;
			EOF

			mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < $fichtemp

			rm -f $fichtemp


			cat <<- EOF > $fichtemp
			DROP DATABASE IF EXISTS $lecture_bases_supprimer_no3;
			EOF

			mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < $fichtemp

			rm -f $fichtemp


			cat <<- EOF > $fichtemp
			REVOKE ALL PRIVILEGES ON $lecture_bases_supprimer_no1 . * FROM '$lecture_utilisateur_centreon_local'@'$lecture_serveur_centreon_local';
			REVOKE GRANT OPTION ON $lecture_bases_supprimer_no1 . * FROM '$lecture_utilisateur_centreon_local'@'$lecture_serveur_centreon_local';
			EOF

			mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < $fichtemp

			rm -f $fichtemp


			cat <<- EOF > $fichtemp
			REVOKE ALL PRIVILEGES ON $lecture_bases_supprimer_no2 . * FROM '$lecture_utilisateur_centreon_local'@'$lecture_serveur_centreon_local';
			REVOKE GRANT OPTION ON $lecture_bases_supprimer_no2 . * FROM '$lecture_utilisateur_centreon_local'@'$lecture_serveur_centreon_local';
			EOF

			mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < $fichtemp

			rm -f $fichtemp


			cat <<- EOF > $fichtemp
			REVOKE ALL PRIVILEGES ON $lecture_bases_supprimer_no3 . * FROM '$lecture_utilisateur_centreon_local'@'$lecture_serveur_centreon_local';
			REVOKE GRANT OPTION ON $lecture_bases_supprimer_no3 . * FROM '$lecture_utilisateur_centreon_local'@'$lecture_serveur_centreon_local';
			EOF

			mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < $fichtemp

			rm -f $fichtemp

		else
			if [ $PLATEFORME_LOCAL -ne $PLATEFORME_DISTANT ] ; then
				rm -rf etc/
				rm -rf usr/
				rm -rf var/
				rm -rf dump-mysql/
				rm -rf dump-rrd/
				rm -rf plateforme/
				message_erreur_centreon
				menu
			else
				rm -rf etc/
				rm -rf usr/
				rm -rf var/
				rm -rf dump-mysql/
				rm -rf plateforme/
				message_erreur_centreon
				menu
			fi
		fi


		cat <<- EOF > $fichtemp
		DROP USER '$lecture_utilisateur_centreon_local'@'$lecture_serveur_centreon_local';
		EOF

		mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < $fichtemp

		rm -f $fichtemp


	else
		if [ $PLATEFORME_LOCAL -ne $PLATEFORME_DISTANT ] ; then
			rm -rf etc/
			rm -rf usr/
			rm -rf var/
			rm -rf dump-mysql/
			rm -rf dump-rrd/
			rm -rf plateforme/
			message_erreur_centreon
			menu
		else
			rm -rf etc/
			rm -rf usr/
			rm -rf var/
			rm -rf dump-mysql/
			rm -rf plateforme/
			message_erreur_centreon
			menu
		fi
	fi

 echo "50" ; sleep 1
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

 echo "60" ; sleep 1
 echo "XXX" ; echo "Migration en cours veuillez patienter"; echo "XXX"
	
	rm -rf /etc/centreon/
	rm -rf /usr/local/centreon/www/img/media/
	rm -rf /var/lib/centreon/


	cp -Rp etc/centreon/ /etc/
	cp -Rp usr/local/centreon/www/img/media/ /usr/local/centreon/www/img/


	if [ -d usr/local/nagios/libexec ] ; then
	cp -Rpn usr/local/nagios/libexec/ /usr/local/nagios/ 
	fi

	if [ -d usr/local/centreon-plugins/libexec ] ; then
	cp -Rpn usr/local/centreon-plugins/libexec/ /usr/local/centreon-plugins/
	fi

 echo "70" ; sleep 1
 echo "XXX" ; echo "Migration en cours veuillez patienter"; echo "XXX"


	if [ $PLATEFORME_LOCAL -ne $PLATEFORME_DISTANT ] ; then
		
		mkdir -p /var/lib/centreon/
		mkdir -p /var/lib/centreon/centplugins
		mkdir -p /var/lib/centreon/log
		mkdir -p /var/lib/centreon/log/1
		mkdir -p /var/lib/centreon/metrics
		mkdir -p /var/lib/centreon/nagios-perf
		mkdir -p /var/lib/centreon/nagios-perf/perfmon-1
		mkdir -p /var/lib/centreon/status

		cd /root/dump-rrd/metrics
		for i in `find -name "*.xml"`; do rrdtool restore $i `echo /var/lib/centreon/metrics/$i |sed s/.xml//g`; done

		cd /root/dump-rrd/nagios-perf/perfmon-1
		for i in `find -name "*.xml"`; do rrdtool restore $i `echo /var/lib/centreon/nagios-perf/perfmon-1/$i |sed s/.xml//g`; done
		
		cd /root/dump-rrd/status
		for i in `find -name "*.xml"`; do rrdtool restore $i `echo /var/lib/centreon/status/$i |sed s/.xml//g`; done

		cd ../..

	else
		cp -Rp var/lib/centreon/ /var/lib/
	fi

	chown -R centreon:centreon  /var/lib/centreon
	chmod -R 775 /var/lib/centreon

 echo "80" ; sleep 1
 echo "XXX" ; echo "Migration en cours veuillez patienter"; echo "XXX"


	mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < /root/dump-mysql/$VARSAISI34.sql
	
	mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < /root/dump-mysql/$VARSAISI35.sql

	mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < /root/dump-mysql/$VARSAISI36.sql


	cat <<- EOF > $fichtemp
	CREATE USER '$lecture_utilisateur_centreon_distant'@'$lecture_serveur_centreon_distant' IDENTIFIED BY '$lecture_password_centreon_distant';
	EOF

	mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < $fichtemp

	rm -f $fichtemp


	cat <<- EOF > $fichtemp
	GRANT ALL PRIVILEGES ON $VARSAISI34 . * TO '$lecture_utilisateur_centreon_distant'@'$lecture_serveur_centreon_distant' WITH GRANT OPTION;
	EOF

	mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < $fichtemp

	rm -f $fichtemp


	cat <<- EOF > $fichtemp
	GRANT ALL PRIVILEGES ON $VARSAISI35 . * TO '$lecture_utilisateur_centreon_distant'@'$lecture_serveur_centreon_distant' WITH GRANT OPTION;
	EOF

	mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < $fichtemp

	rm -f $fichtemp


	cat <<- EOF > $fichtemp
	GRANT ALL PRIVILEGES ON $VARSAISI36 . * TO '$lecture_utilisateur_centreon_distant'@'$lecture_serveur_centreon_distant' WITH GRANT OPTION;
	EOF

	mysql -h `uname -n` -u $VARSAISI30 -p$VARSAISI31 < $fichtemp

	rm -f $fichtemp

 echo "90" ; sleep 1
 echo "XXX" ; echo "Migration en cours veuillez patienter"; echo "XXX"

	if [ $PLATEFORME_LOCAL -ne $PLATEFORME_DISTANT ] ; then
		rm -rf etc/
		rm -rf usr/
		rm -rf var/
		rm -rf dump-mysql/
		rm -rf dump-rrd/
		rm -rf plateforme/
	else
		rm -rf etc/
		rm -rf usr/
		rm -rf var/
		rm -rf dump-mysql/
		rm -rf plateforme/
	fi

	rm -rf migration-centreon.tgz

 echo "95" ; sleep 1
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