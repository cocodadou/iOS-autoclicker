# AdvancedAutoClicker

Autoclicker iOS générique destiné à être injecté dans une application, notamment via LiveContainer ou un injecteur de tweaks compatible.

## Fonctions

- Jusqu'à 20 points indépendants
- Délai propre à chaque point, de 1 ms à des valeurs très longues
- Durée d'appui configurable par point
- Nombre de répétitions configurable par point
- Décalage aléatoire optionnel des coordonnées
- Délai initial avant démarrage
- Nombre de boucles fini ou infini
- Sauvegarde des réglages par application
- Contrôles flottants `SET` et `GO/STOP`
- Injection tactile basée sur ZSFakeTouch

## Compiler sans Mac avec GitHub Actions

Le dépôt contient déjà `.github/workflows/build.yml`.

1. Créez un nouveau dépôt GitHub.
2. Envoyez **tout le contenu de ce dossier**, y compris `.gitmodules` et `.github/`.
3. Ouvrez l'onglet **Actions** du dépôt.
4. Sélectionnez **Build AdvancedAutoClicker**.
5. Appuyez sur **Run workflow**.
6. Attendez la fin du job `Build iOS tweak`.
7. Ouvrez l'exécution terminée et téléchargez l'artifact `AdvancedAutoClicker-...`.

L'artifact contient :

```text
AdvancedAutoClicker.dylib
AdvancedAutoClicker.deb
SHA256SUMS.txt
```

Pour LiveContainer, importez `AdvancedAutoClicker.dylib` dans **Tweaks**, puis utilisez le bouton **Signer** avant de l'activer pour l'application souhaitée.

Pour un injecteur prenant en charge les paquets Debian, vous pouvez utiliser `AdvancedAutoClicker.deb`.

## Déclenchement automatique

Le workflow compile également lors :

- d'un push sur `main` ou `master` ;
- d'une pull request ;
- d'un tag commençant par `v`.

Aucun certificat Apple, fichier `.p12`, provisioning profile ou secret GitHub n'est nécessaire pour produire la dylib destinée à LiveContainer. LiveContainer peut ensuite signer la dylib avec son propre mécanisme de signature.

## Compilation locale facultative

Avec Theos déjà installé :

```bash
./build.sh
```

Les sorties sont copiées dans `dist/`.

## Structure

```text
.github/workflows/build.yml     GitHub Actions
.gitmodules                     Dépendance ZSFakeTouch
AdvancedAutoClicker.plist       Filtre de tweak
Makefile                        Configuration Theos
Tweak.x                         Code du tweak
build.sh                        Build local facultatif
control                         Métadonnées du paquet .deb
LICENSE                         Licence
```

## Notes

La compatibilité dépend de l'application cible et de son système d'entrée. Certaines applications utilisant des piles d'entrée ou de rendu particulières peuvent ne pas accepter les événements tactiles synthétiques.

Le projet utilise ZSFakeTouch depuis `DYY-Studio/ZSFakeTouch` comme sous-module Git. Conservez les notices de licence du projet amont lors d'une redistribution.
