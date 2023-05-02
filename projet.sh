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
ssh ldiguer25@10.30.48.100
# On donne les bons droits et on change le propriétaire du dossier shared
chmod 755 /home/shared
chown root /home/shared

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
	echo -e "$psswd\n$psswd" | passwd $login
	echo "$login:$psswd" | chpasswd
	
	# Mot de passe considéré comme expiré pour le changer à la prochaine connexion
	#chage -d0 $login
	
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
