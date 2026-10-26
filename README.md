# PR Radar

Un widget iPhone qui affiche les pull requests qui attendent ta review, et qui **fait tinter une petite cloche** quand une nouvelle arrive. Il est pensé pour le mode **StandBy** (iPhone en charge, posé à l'horizontale ou en tente), mais marche aussi sur l'écran d'accueil et l'écran verrouillé.

- **Connexion GitHub sans token** : « Se connecter avec GitHub » ouvre l'écran d'autorisation officiel de GitHub (OAuth, *device flow*). Rien à copier à part un code court.
- **Tu choisis les repositories** : l'app ne voit que les repos auxquels tu donnes accès en installant la GitHub App, et tu peux encore filtrer parmi eux dans l'app.
- **Détection** : PR ouvertes où ta review est demandée (y compris via une équipe), et en option celles qui te sont assignées.
- **Animation sobre** : la cloche se balance deux fois, deux ondes vertes se diffusent, la carte de la PR glisse depuis le bas avec un badge « NOUVELLE PR », et le compteur défile. Le widget reste ensuite légèrement éclairé en vert tant que tu n'as pas ouvert la PR (24 h max).
- Toucher le widget ouvre la PR (dans l'app GitHub si elle est installée) et la marque comme vue.

## Mise en place

Il te faut un Mac avec Xcode 15 ou plus récent, un iPhone sous iOS 17 ou plus récent, et [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

### 1. Créer ta GitHub App (2 minutes, une seule fois)

C'est elle qui fournit la connexion « third-party app » avec écran d'autorisation. Va sur **https://github.com/settings/apps/new** :

| Champ | Valeur |
|---|---|
| GitHub App name | un nom unique, ex. `PR Radar (ton-login)` |
| Homepage URL | n'importe quelle URL, ex. `https://github.com/ton-login` |
| Callback URL | vide |
| Expire user authorization tokens | **décoché** (sinon la session expire et il faut se reconnecter régulièrement) |
| Request user authorization (OAuth) during installation | décoché |
| **Enable Device Flow** | **coché** |
| Webhook › Active | **décoché** |
| Permissions › Repository › **Pull requests** | **Read-only** (*Metadata : Read-only* s'ajoute tout seul) |
| Where can this GitHub App be installed? | *Any account* si tu veux l'utiliser sur les repos d'une organisation, sinon *Only on this account* |

Crée l'app, puis note :

- le **Client ID** (ex. `Iv23li…`) affiché en haut de la page de l'app ;
- le **slug** de l'app : la fin de l'URL publique `https://github.com/apps/<slug>`.

Pas besoin de clé privée ni de client secret : le device flow n'en utilise pas, rien de sensible n'est embarqué dans l'app.

### 2. Installer l'app sur tes repositories

Sur la page de ton app, **Install App**, puis pour chaque compte (toi, tes organisations) : **Only select repositories** et coche ceux à surveiller. Pour une organisation, un owner de l'org devra peut-être approuver l'installation.

Tu peux modifier cette liste plus tard depuis l'app (lien « Modifier les repositories accessibles »).

### 3. Configurer et lancer le projet

```sh
cp Config/Local.example.xcconfig Config/Local.xcconfig
# édite Config/Local.xcconfig : DEVELOPMENT_TEAM, BUNDLE_ID_PREFIX, GITHUB_CLIENT_ID, GITHUB_APP_SLUG
xcodegen
open PRRadar.xcodeproj
```

Choisis ton iPhone comme destination et lance le schéma **PRRadar**. La signature automatique crée l'App Group `group.<BUNDLE_ID_PREFIX>.prradar` qui permet à l'app et au widget de partager la session. Si Xcode signale une erreur d'App Group, ouvre *Signing & Capabilities* sur les deux cibles et laisse-le corriger.

> Avec un compte Apple gratuit, l'app installée expire au bout de 7 jours : il faut alors la relancer depuis Xcode.

### 4. Dans l'app

1. **Se connecter avec GitHub** : l'app affiche un code, **Copier le code et ouvrir GitHub**, colle le code, puis **Authorize**. De retour dans l'app, tu es connecté.
2. **Repositories** : garde « Tous les repositories accessibles » ou coche ceux que tu veux.
3. **Tester l'animation du widget** te permet de voir l'animation sans attendre une vraie PR.

### 5. Ajouter le widget en StandBy

1. Branche l'iPhone et pose-le à l'horizontale (ou en tente) : le mode StandBy s'affiche (*Réglages › StandBy* doit être activé).
2. Balaie vers la gauche jusqu'à la vue widgets, fais un appui long sur une pile, **+**, puis ajoute **PR Radar**.

En StandBy, iOS n'affiche que le **petit** format, mais en grand, sur la moitié de l'écran. Le format moyen et le grand format sont disponibles sur l'écran d'accueil, et deux formats existent aussi pour l'écran verrouillé.

### Plan B : token personnel

Sur l'écran de connexion, **Utiliser un token personnel**. Crée un *fine-grained token* (github.com › Settings › Developer settings › Personal access tokens) limité aux repos voulus, avec **Pull requests : Read-only**. Il est stocké dans le trousseau de l'iPhone. Ce mode ne nécessite pas de GitHub App (tu peux laisser `GITHUB_CLIENT_ID` vide).

## Ce qu'il faut savoir

- **Ce n'est pas instantané.** iOS décide quand un widget peut se rafraîchir. Le widget demande une mise à jour toutes les 10 minutes et l'app profite en plus des réveils en arrière-plan, mais en pratique compte **de 10 à 30 minutes** entre l'ouverture d'une PR et l'animation. Touche l'heure affichée dans le widget moyen ou grand pour forcer une vérification.
- **L'animation est jouée une seule fois par PR** (et par format de widget), au rafraîchissement qui la détecte, si elle date de moins de 45 min. Elle est faite de 4 étapes de timeline espacées de 1,2 s ; si iOS n'affiche pas le widget à ce moment-là (écran éteint par exemple), tu verras directement l'état final : badge « NOUVELLE PR » et lueur verte.
- Au premier lancement, et chaque fois que tu changes la liste des repos, les PR déjà en attente sont considérées comme vues : pas de fausse alerte.
- Les requêtes passent par l'API de recherche GitHub (`is:pr is:open review-requested:@me`, plus `assignee:@me` en option), limitée aux repos choisis.

### Piste pour du temps réel

Pour une animation dans la seconde, il faudrait un petit serveur qui reçoit les webhooks GitHub `pull_request` et envoie une notification push de mise à jour du widget (WidgetKit sait recharger un widget sur réception d'un push depuis iOS 26). Ce n'est pas inclus ici pour éviter d'avoir un serveur à héberger.

## Organisation du code

```
project.yml                  Projet XcodeGen (app + extension widget, App Group)
Config/                      Client ID, slug, Team ID (Local.xcconfig ignoré par git)
Shared/                      Compilé dans l'app ET le widget
  GitHubAuth.swift           Device flow OAuth, stockage et refresh des identifiants
  GitHubAPI.swift            Client REST (installations, repos, recherche)
  PRChecker.swift            Construit les requêtes de recherche, fusionne les résultats
  SharedStore.swift          Réglages, PR déjà vues, état « nouvelle », animations déjà jouées
  Keychain.swift             Trousseau partagé (lisible iPhone verrouillé, pour StandBy)
  RefreshIntent.swift        Bouton « rafraîchir » du widget
App/                         L'app : connexion, liste des PR, choix des repos, réglages
Widget/                      Timeline (séquence d'animation) et vues du widget
```
