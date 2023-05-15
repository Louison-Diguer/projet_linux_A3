#!/bin/bash

clear
if [ $# -ne 1 ]
then
	echo "ERREUR : sudo bash $0 fichier.csv"
	exit 1
fi

#################################################################################################################################################################
###############################################################  VARIABLES UTILISATEUR  #########################################################################
#################################################################################################################################################################

echo "Quel est votre nom d'utilisateur sur la machine distante ? : "
read user_distant

echo "Quel est le nom de votre serveur SMTP ? : "
read smtp_serv

echo "Quel est votre adresse mail ? : "
read user_mail

echo "Quel est le mdp de votre mail? : "
read user_mdp


#Installation de swaks pour l'envoi de mail
apt-get install swaks


#################################################################################################################################################################
###############################################################   CREATION ARBORESCENCE  ########################################################################
#################################################################################################################################################################


# Création du dossier shared s'il n'existe pas
if [ ! -d /home/shared ]; then
    mkdir /home/shared
fi

# On donne les bons droits et on change le propriétaire du dossier shared
chmod 755 /home/shared
chown root /home/shared

# Création du dossier saves et permissions dans la machine distante
ssh $user_distant@10.30.48.100 "mkdir /home/saves"
ssh $user_distant@10.30.48.100 "chmod 006 /home/saves"

#################################################################################################################################################################
###############################################################   ECRITURE DES AUTRES FICHIERS BASH   ###########################################################
#################################################################################################################################################################


# Création du script retablir la sauvegarde
cat > /home/retablir_sauvegarde.sh << EOF
#!/bin/bash

cd /home/\$USER/a_sauver
tar xzf /home/saves/save_\$USER.tgz
EOF
chmod +x /home/retablir_sauvegarde.sh

# Création du script pour la sauvegarde quotidienne
cat > /home/sauvegarde_quotidienne.sh << EOF
#!/bin/bash

# Récupération de la liste des utilisateurs
USERS=$(cut -d: -f1 /etc/passwd)

# Boucle pour sauvegarder les fichiers de chaque utilisateur
for USER in \$USERS
do
	# Vérification que l'utilisateur a un dossier a_sauver
	if [ -d /home/\$USER/a_sauver ]; then
		# Récupération de la date et du nom de fichier
		DATE=$(date +"%Y-%m-%d_%H-%M-%S")
		FILENAME="save_${USER}_${DATE}.tgz"
		# Compression du dossier a_sauver
		tar czf /tmp/\$FILENAME /home/\$USER/a_sauver
		# Envoi du fichier compressé sur la machine distante
		scp /tmp/\$FILENAME $user_distant@m10.30.48.100:/home/saves/\$FILENAME
		# Suppression du fichier compressé local
		rm /tmp/\$FILENAME
  	fi
done
EOF

# Ajout de la ligne dans la crontab pour effectuer la sauvegarde quotidienne
$(echo "0 23 * * 1-5 /home/sauvegarde_quotidienne.sh" | crontab)


#################################################################################################################################################################
#########################################################   BOUCLE PRINCIPALE DE LECTURE DE FICHIER   ###########################################################
#################################################################################################################################################################

while read line; do
	# Lecture du fichier
	name=$(echo "$line" | cut -d';' -f1)
	surname=$(echo "$line" | cut -d';' -f2)
	mail=$(echo "$line" | cut -d';' -f3)
	psswd=$(echo "$line" | cut -d';' -f4)
	
	# On créé le nom du compte avec la première lettre du prénom et le nom
	login="${name:0:1}$surname"
	
	# On supprime les espaces dans le login
	login=$(echo "$login" | sed 's/ //g')
	
	# Création du compte de l'utilisateur
	useradd -m $login
	
	# Changement du mot de passe
	#echo -e "$psswd\n$psswd" | passwd $login
	psswd=$(echo "$psswd" | sed 's/\r//g')
	echo "$login:$psswd" | chpasswd

	# Mot de passe considéré comme expiré pour le changer à la prochaine connexion
	chage -d0 $login
	
	# Envoi d'un mail login, mdp, expiration
	swaks -t $mail \
	-s $smtp_serv \
	-tls \
	-au $user_mail \
	-ap $user_mdp \
	-f $user_mail \
	--body "Bonjour,\n\nVos identifiants sont les suivants :\nLogin : $login\nPassword : $psswd\n\nIl vous sera demande de changer votre mot de passe à votre prochaine connexion.\n\nCordialement,\n\nDIGUER Louison et LOBEL Martin" \
	--h-Subject "Création de votre compte"
	
	# On change le propriétaire et on donne tous les droits à l'utilisateur
	chown $login /home/$login
	chmod 700 /home/$login
	
	# Création d'un dossier a_sauver pour chaque utilisateur
	mkdir /home/$login/a_sauver
	chown $login /home/$login/a_sauver
	chmod 700 /home/$login/a_sauver
	
	# Création d'un dossier par utilisateur dans le dossier shared
	mkdir /home/shared/$login
	chown $login /home/shared/$login
	chmod 205 /home/shared/$login

done<$1

#################################################################################################################################################################
###############################################################   TELECHARGEMENT ECLIPSE   ######################################################################
#################################################################################################################################################################

# Installation de Eclipse
URL_dl_eclipse="https://rhlx01.hs-esslingen.de/pub/Mirrors/eclipse/oomph/epp/2023-03/R/eclipse-inst-jre-linux64.tar.gz"
comp_eclipse="eclipse.tar.gz"
share_eclipse="/opt/eclipse"

# Téléchargement et extraction de l'archive de la dernière version de Eclipse
wget "$URL_dl_eclipse" -O "$comp_eclipse"
tar -zxvf "$comp_eclipse" -C /opt/
mv "/opt/eclipse-installer" "$share_eclipse"

# Configuration des droits pour que le dossier Eclipse soit disponible pour tous les utilisateurs en lecture/exécution
chown -R root:root "$share_eclipse"
chmod -R 755 "$share_eclipse"

# Création d'un lien symbolique dans le home pour que Eclipse soit disponible pour tous
ln -s "$share_eclipse/eclipse" /home/eclipse

#################################################################################################################################################################
######################################################################   PARE-FEUX   ############################################################################
#################################################################################################################################################################

# Création de l'iptables
iptables -N RULES	

# Blocage des connexions  FTP
sudo iptables -A OUTPUT -p tcp --dport 21 -j DROP

# Blocage des connexions UDP
sudo iptables -A OUTPUT -p udp -j DROP

#################################################################################################################################################################
###############################################################   TELECHARGEMENT NEXTCLOUD   ####################################################################
#################################################################################################################################################################

# Installation de Nginx, PostgreSQL, PHP et d’autres packages
ssh $user_distant@10.30.48.100 "apt install imagemagick php-imagick php7.4-common php7.4-pgsql php7.4-fpm php7.4-gd php7.4-curl php7.4-imagick php7.4-zip php7.4-xml php7.4-mbstring php7.4-bz2 php7.4-intl php7.4-bcmath php7.4-gmp nginx unzip wget"
ssh $user_distant@10.30.48.100 "apt install -y postgresql postgresql-contrib"

# Installation de NextCloud
ssh $user_distant@10.30.48.100 "wget https://download.nextcloud.com/server/releases/latest.zip"

# Décompression du zip
ssh $user_distant@10.30.48.100 "unzip latest.zip"

# On déplace le répertoire extrait vers la racine Web Apache
ssh $user_distant@10.30.48.100 "mv nextcloud /var/www/"

# On donne les autorisations appropriées au répertoire nextcloud
ssh $user_distant@10.30.48.100 "chown -R www-data:www-data /var/www/nextcloud/ chmod -R 755 /var/www/nextcloud/"

# Connexion a PostgreSQL
ssh $user_distant@10.30.48.100 "sudo -u postgres psql"

# Création de la base de données
ssh $user_distant@10.30.48.100 "CREATE DATABASE nextcloud TEMPLATE template0 ENCODING 'UNICODE' ;"
ssh $user_distant@10.30.48.100 "CREATE USER nextcloud_admin WITH PASSWORD 'N3x+_Cl0uD' ;"
ssh $user_distant@10.30.48.100 "ALTER DATABASE nextcloud OWNER TO nextcloud_admin ;"
ssh $user_distant@10.30.48.100 "nextcloud A nextcloud_admin ;"
ssh $user_distant@10.30.48.100 "exit"

#################################################################################################################################################################
####################################################################   MONITORING   #############################################################################
#################################################################################################################################################################

# Création du script pour le monitoring chaque minute
cat > /home/monitoring_minute.sh << EOF
#!/bin/bash

# Création du fichier du monitoring chaque minute
date_file=$(date +%Y%m%d)
time_file=$(date +%H%M%S)

ssh $user_distant@10.30.48.100 "mkdir /home/monitoring_${date_file}"
ssh $user_distant@10.30.48.100 "touch /home/monitoring_${date_file}/monitoring_${date_file}_${time_file}.txt"

# CPU
ssh $user_distant@10.30.48.100 "sar -u 1 1 > /home/monitoring_${date_file}/monitoring_${date_file}_${time_file}.txt"
# Mémoire
ssh $user_distant@10.30.48.100 "sar -r 1 1 >> /home/monitoring_${date_file}/monitoring_${date_file}_${time_file}.txt"
# Réseaux
ssh $user_distant@10.30.48.100 "vnstat -d >> /home/monitoring_${date_file}/monitoring_${date_file}_${time_file}.txt"
EOF

commande="bash $user_distant@10.30.48.100:/home/monitoring_minute.sh"
# Ajout de la ligne dans la crontab pour effectuer le monitoring toutes les minutes
$(echo "* * * * 1-5 commande" | crontab)


# Création du script pour le rapport de monitoring
ssh $user_distant@10.30.48.100 "mkdir /home/rapport_monitoring"

cat > /home/monitoring_rapport.sh << EOF
#!/bin/bash

# Création du fichier du rapport de monitoring
date_file=$(date +%Y%m%d)

ssh $user_distant@10.30.48.100 "touch /home/rapport_monitoring/rapport_monitoring_${date_file}.txt"

for i in $(ls /home/monitoring_${date_file})
do
ssh $user_distant@10.30.48.100 "/home/monitoring_${date_file}/$i >> /home/rapport_monitoring/rapport_monitoring_${date_file}.txt"
done
EOF

commande="bash $user_distant@10.30.48.100:/home/monitoring_rapport.sh"
# Ajout de la ligne dans la crontab pour effectuer le monitoring toutes les minutes
$(echo "* * * * 1-5 commande" | crontab)