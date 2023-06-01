# Introduction

Ce module a pour but de créer un système Linux embarqué pour Raspberry Pi.

# Structure des fichiers

```
WORKDIR/
├─ build/ (Contient les sources compilées)
├─ data/ (Données à copier, nécessaires au script)
│ ├─ boot_rpi/ (Fichiers à copier dans le répertoire boot de la carte SD)
│ ├─ configs_busybox/ (Fichiers de configuration de busybox sauvegardés)
│ ├─ images/ (Images de test pour le framebuffer)
| ├─ makefiles/ (Makefiles qui seront recopiés dans certains dossiers des sources)
│ ├─ azerty.kmap
│ ├─ inittab
│ ├─ rcS
├─ docs/ (Documentation)
├─ logs/ (Logs des installations, créé par le script)
├─ src/ (Sources)
│ ├─ fbv/ (Sources de/pour fbv)
│ | ├─ fbv-master.zip (Sources de fbv)
│ | ├─ jpegsrc.v9e.tar.gz (Sources de lib jpeg)
│ | ├─ libpng-x.x.x.tar.gz (Sources de lib png)
│ | ├─ zlib-x.x.x.tar.gz (Sources de lib z)
│ ├─ hello_world/ (Programme de test de compilation croisée)
| ├─ ncurses/ (Sources de/pour ncurses)
│ | ├─ ncurses-x.x.tar.gz (Sources de ncurses)
│ | ├─ ncurses-examples.tar.gz (Exemples de ncurses)
│ | ├─ ncurses_programs.tar.gz (Programmes de test de ncurses)
│ | ├─ hello_ncurses/ (Programme "Hello World" de test de ncurses)
│ ├─ busybox-x.x.x.tar.bz2 (Archive des sources de busybox)
│ ├─ tools-master.zip (Outils de compilation croisée)
│ ├─ dropbear-xxxx.x.tar.bz2 (Archive des sources de dropbear)
├─ targets/ (Cibles pour la compilation)
├─ mk_env.sh (Script de création de l'environnement de compilation)
├─ script.sh
```

# Utilisation

## Prérequis

Dans le répertoire data :
- Dossier `boot_rpi` contient les fichiers à copier dans le répertoire boot de la carte SD
- Dossier `configs_busybox` contient les fichiers de configuration de busybox sauvegardés
- Dossier `images` contient les images de test pour le framebuffer
- Dossier `makefiles` contient les makefiles qui seront recopiés dans certains dossiers des sources
- Fichier `azerty.kmap` contenant la configuration du clavier
- Script `inittab` contenant la configuration de l'init
- Script `rcS` exécuté au démarrage

## Lancement du script

Le script doit être lancé depuis le dossier `WORKDIR` en tant que root.

```bash
sudo ./script.sh
```

## Utilisation du script

1. Dépaquetage des sources

2. Séléction du périphérique de stockage (carte SD)

3. Séléction du fichier de configuration de busybox (ou d'abord modification du fichier de configuration puis enregistrement de la configuration)

4. Installation étape par étape ou installation rapide
