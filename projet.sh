#!/bin/bash

clear
if [ $# -ne 1 ]
then
	echo "ERREUR : $0 fichier.csv"
	exit 1
fi

#Installation de swaks pour l'envoi de mail
apt-get install swaks

# Création du dossier shared s'il n'existe pas
if [ ! -d /home/shared ]; then
    mkdir /home/shared
fi

# On donne les bons droits et on change le propriétaire du dossier shared
chmod 755 /home/shared
chown root /home/shared

# Création du dossier saves et permissions dans la machine distante
sudo -u isen ssh ldigue25@10.30.48.100 "mkdir /home/saves"
sudo -u isen ssh ldigue25@10.30.48.100 "chmod 006 /home/saves"

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
		scp /tmp/\$FILENAME ldigue25@m10.30.48.100:/home/saves/\$FILENAME
		# Suppression du fichier compressé local
		rm /tmp/\$FILENAME
  	fi
done
EOF

# Ajout de la ligne dans la crontab pour effectuer la sauvegarde quotidienne
$(echo "0 23 * * 1-5 /home/sauvegarde_quotidienne.sh" | crontab)

# Boucle de lecture du fichier
while read line; do
	# Lecture du fichier
	name=$(echo "$line" | cut -d';' -f1)
	surname=$(echo "$line" | cut -d';' -f2)
	mail=$(echo "$line" | cut -d';' -f3)
	psswd=$(echo "$line" | cut -d';' -f4)
	echo -e "$name - $surname - $mail - $psswd"
	
	# On créé le nom du compte avec la première lettre du prénom et le nom
	login="${name:0:1}$surname"
	
	# On supprime les espaces dans le login
	login=$(echo "$login" | sed 's/ //g')
	echo -e "nom du compte : $login"
	
	# Suppression des comptes
	userdel $login
	rm -Rf /home/$login
	
	# Création du compte de l'utilisateur
	useradd -m $login
	
	# Changement du mot de passe
	#echo -e "$psswd\n$psswd" | passwd $login
	psswd=$(echo "$psswd" | sed 's/\r//g')
	echo "$login:$psswd" | chpasswd

	# Mot de passe considéré comme expiré pour le changer à la prochaine connexion
	chage -d0 $login
	
	# Envoi d'un mail login, mdp, expiration
	#swaks -t $mail \
	#-s smtp.sfr.fr:587 \
	#-tls \
	#-au diguer.louison@sfr.fr \
	#-ap 395903 \
	#-f diguer.louison@sfr.fr \
	#--body "Bonjour,\n\nVos identifiants sont les suivants :\nLogin : $login\nPassword : $psswd\n\nIl vous sera demande de changer votre mot de passe à votre prochaine connexion.\n\nCordialement,\n\nDIGUER Louison et LOBEL Martin" \
	#--h-Subject "Création de votre compte"
	
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
	
	echo -e
	echo -e
done<$1

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

# Pare-feux
# Création de l'iptables
iptables -N RULES

# Blocage des connexions  FTP
sudo iptables -A OUTPUT -p tcp --dport 21 -j DROP

# Blocage des connexions UDP
sudo iptables -A OUTPUT -p udp -j DROP