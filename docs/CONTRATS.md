# CONTRATS.md — Projet Gant intelligent

> Version : 0.1 (brouillon à valider par les 4 membres)
> Ce document est la **référence unique** pour les formats d'échange. Toute modification passe par l'équipe et incrémente la version.

---

## 1. Conventions générales

| Règle | Valeur |
|---|---|         
| Encodage des messages | JSON, UTF-8 |
| Horodatage `ts` | Entier, millisecondes depuis epoch, UTC |
| Identifiants | `glove-01`, `car-01`, `light-01` (format `<type>-<NN>`) |
| Casse des champs | `snake_case` |
| Version du schéma | Champ `v` (entier) dans chaque message, actuellement `1` |
| Taille max d'un message | 4 Ko |
| Gestes (valeurs de `label` / `gesture`) | `open_hand`, `closed_hand`, `turn_left`, `turn_right`, `unknown` |
| Commandes voiture | `FORWARD`, `STOP`, `TURN_LEFT`, `TURN_RIGHT` |
| Couleurs du feu | `GREEN`, `RED` (`unknown` si état périmé ou absent) |

> Les identifiants sont **variables** dans les topics (`{id}`), jamais codés en dur, pour permettre plusieurs gants ou voitures.

---

## 2. Topics MQTT

| Topic | Publieur | Abonné | QoS | Retain | Contenu |
|---|---|---|---|---|---|
| `glove/{id}/sensors` | Gant | Backend | 0 | non | Lot d'échantillons capteurs |
| `glove/{id}/gesture` | Gant (IA embarquée, plus tard) | Backend | 1 | non | Geste reconnu directement sur le gant |
| `glove/{id}/status` | Gant | Backend | 1 | **oui** | `online` / `offline` (Last Will) |
| `traffic/{id}/light` | Feu | Backend | 1 | **oui** | Couleur courante |
| `traffic/{id}/status` | Feu | Backend | 1 | **oui** | `online` / `offline` (Last Will) |
| `car/{id}/command` | Backend | Voiture | 1 | non | Commande moteur |
| `car/{id}/status` | Voiture | Backend | 1 | **oui** | `online` / `offline` (Last Will) |
| `car/{id}/telemetry` | Voiture | Backend | 0 | non | Dernière commande appliquée, batterie |

**Last Will** : chaque appareil déclare à la connexion un Last Will sur son topic `status` avec le payload `{"v":1,"state":"offline"}`, et publie `{"v":1,"state":"online","ts":...}` une fois connecté.

---

## 3. Schémas des messages

### 3.1 `glove/{id}/sensors` — lot d'échantillons

Fréquence d'échantillonnage : **50 Hz**. Un message contient **10 échantillons** (soit 200 ms).

```json
{
  "v": 1,
  "device": "glove-01",
  "seq": 1042,
  "fs": 50,
  "ts": 1760000000000,
  "samples": [
    { "dt": 0,  "f": [3200, 3150, 3100, 3050, 3120], "a": [0.12, 0.04, 0.98], "g": [1.2, 0.4, 0.1] },
    { "dt": 20, "f": [3202, 3149, 3101, 3048, 3119], "a": [0.11, 0.05, 0.99], "g": [1.1, 0.3, 0.2] }
  ]
}
```

| Champ | Type | Description |
|---|---|---|
| `seq` | int | Compteur croissant par appareil (détecte les pertes) |
| `fs` | int | Fréquence d'échantillonnage en Hz |
| `ts` | int | Horodatage du **premier** échantillon |
| `samples[].dt` | int | Décalage en ms par rapport à `ts` |
| `samples[].f` | int[5] | Flex sensors, pouce → auriculaire, valeur ADC brute (0–4095) |
| `samples[].a` | float[3] | Accéléromètre x, y, z en g |
| `samples[].g` | float[3] | Gyroscope x, y, z en °/s |

### 3.2 `glove/{id}/gesture` — geste reconnu (IA embarquée)

```json
{ "v": 1, "device": "glove-01", "ts": 1760000000200, "gesture": "open_hand", "confidence": 0.93 }
```

> Tant que l'IA n'est pas sur le gant, ce message est **produit par le backend** (voir §6) et republié en interne. Le format reste identique.

### 3.3 `traffic/{id}/light`

```json
{ "v": 1, "device": "light-01", "ts": 1760000000000, "color": "GREEN" }
```

Le feu republie son état **toutes les 2 s** (heartbeat), même sans changement.

### 3.4 `car/{id}/command`

```json
{ "v": 1, "ts": 1760000000300, "command": "FORWARD", "speed": 150, "reason": "open_hand+GREEN", "cmd_id": "c-000231" }
```

| Champ | Type | Description |
|---|---|---|
| `command` | string | `FORWARD`, `STOP`, `TURN_LEFT`, `TURN_RIGHT` |
| `speed` | int | PWM 0–255. Fixe à **150** en v1 (voir questions ouvertes) |
| `reason` | string | Règle de décision ayant produit la commande (journalisation) |
| `cmd_id` | string | Identifiant unique, repris dans la télémétrie et l'historique |

### 3.5 `car/{id}/telemetry`

```json
{ "v": 1, "device": "car-01", "ts": 1760000000350, "last_cmd_id": "c-000231", "applied": "FORWARD", "battery_pct": 82 }
```

### 3.6 `*/status`

```json
{ "v": 1, "device": "glove-01", "state": "online", "ts": 1760000000000 }
```

---

## 4. Table de décision

Évaluée **dans l'ordre**, la première règle qui correspond s'applique.

| Priorité | Condition | Commande | `reason` |
|---|---|---|---|
| 1 | Gant `offline` ou aucun message depuis > 1 s | `STOP` | `glove_lost` |
| 2 | `confidence` < **0.70** | `STOP` | `low_confidence` |
| 3 | `gesture` = `unknown` | `STOP` | `unknown_gesture` |
| 4 | Feu `unknown` (absent ou périmé > 5 s) | `STOP` | `light_unknown` |
| 5 | `gesture` = `closed_hand` | `STOP` | `closed_hand` |
| 6 | Feu = `RED` | `STOP` | `red_light` |
| 7 | `open_hand` + `GREEN` | `FORWARD` | `open_hand+GREEN` |
| 8 | `turn_left` + `GREEN` | `TURN_LEFT` | `turn_left+GREEN` |
| 9 | `turn_right` + `GREEN` | `TURN_RIGHT` | `turn_right+GREEN` |

**Règle générale : en cas de doute, STOP.**

Le moteur de décision est une **fonction pure** : `decide(gesture, confidence, light, now) -> Command`, testable sans MQTT.

---

## 5. Sécurité de la voiture (côté firmware)

| Mécanisme | Valeur |
|---|---|
| Watchdog commande | La voiture passe en `STOP` si aucune commande reçue depuis **1 s** |
| Re-publication | Le backend renvoie la commande courante toutes les **300 ms** tant que l'état ne change pas |
| Commande rejetée | `v` inconnu, `command` hors liste, `speed` hors 0–255, JSON invalide |
| Déconnexion broker | `STOP` immédiat, puis reconnexion automatique |

---

## 6. Interface du classifieur (backend)

```python
class Classifier(Protocol):
    def predict(self, window: list[Sample]) -> tuple[str, float]:
        """Retourne (gesture, confidence) pour une fenêtre de 1 à 2 s."""
```

| Implémentation | Usage |
|---|---|
| `RuleClassifier` | Règles simples sur les flex, pour tester le pipeline sans modèle |
| `EdgeImpulseClassifier` | Modèle entraîné sur de vraies données |
| Passthrough | Quand le gant publie déjà `glove/{id}/gesture` (IA embarquée) |

Fenêtre d'inférence : **1 s** glissante, pas de **200 ms** (donc une prédiction par lot reçu).

---

## 7. Sécurité MQTT (ACL)

| Utilisateur | Peut publier | Peut s'abonner |
|---|---|---|
| `glove-NN` | `glove/glove-NN/#` | — |
| `light-NN` | `traffic/light-NN/#` | — |
| `car-NN` | `car/car-NN/status`, `car/car-NN/telemetry` | `car/car-NN/command` |
| `backend` | `car/+/command` | `glove/+/#`, `traffic/+/#`, `car/+/status`, `car/+/telemetry` |

- Port **8883** (TLS), `allow_anonymous false`, fichier de mots de passe.
- Les identifiants d'appareils ne sont **jamais** commités dans Git (fichier `.env`).

---

## 8. API REST (v1)

Préfixe : `/api/v1`. Authentification : **JWT** (`Authorization: Bearer <token>`).

| Méthode | Route | Rôle minimum | Description |
|---|---|---|---|
| POST | `/auth/login` | public | Retourne `access` et `refresh` |
| POST | `/auth/refresh` | public | Nouveau `access` |
| GET | `/devices` | user | Liste des appareils et leur état |
| GET | `/mappings` | user | Associations geste → action |
| PUT | `/mappings/{gesture}` | admin | Modifie une association |
| GET | `/commands?limit=&from=&to=` | user | Historique des commandes |
| POST | `/dataset/sessions` | admin | Démarre une session (`{"label":"open_hand","device":"glove-01"}`) |
| POST | `/dataset/sessions/{id}/stop` | admin | Termine la session et ferme le CSV |
| GET | `/audit?limit=` | admin | Journal d'audit |

**Rôles** : `admin` (tout), `user` (lecture + contrôle), `guest` (lecture de l'état en direct).

---

## 9. WebSocket

Point d'entrée : `wss://<hôte>/ws/live?token=<access_jwt>`. Messages serveur → client uniquement (v1).

```json
{ "type": "gesture", "device": "glove-01", "ts": 1760000000200, "gesture": "open_hand", "confidence": 0.93 }
{ "type": "command", "device": "car-01",   "ts": 1760000000300, "command": "FORWARD", "reason": "open_hand+GREEN" }
{ "type": "light",   "device": "light-01", "ts": 1760000000000, "color": "GREEN" }
{ "type": "status",  "device": "glove-01", "state": "offline" }
{ "type": "orientation", "device": "glove-01", "ts": 1760000000200, "roll": 12.4, "pitch": -3.1, "yaw": 80.0 }
```

> `orientation` sert à la main 3D de Flutter. Optionnel en v1.

---

## 10. CoAP (à préciser avec l'équipe firmware)

Rôle : **configuration et lecture d'état du gant**, pas de flux de données.

| Méthode | Ressource | Description |
|---|---|---|
| GET | `/state` | Batterie, version du modèle, uptime |
| GET / PUT | `/config` | `fs`, seuil de confiance, mode (`normal` / `raw_stream`) |

---

## 11. Format du dataset (CSV)

Un fichier par session : `data/<label>_<device>_<timestamp>.csv`

```csv
timestamp,f1,f2,f3,f4,f5,ax,ay,az,gx,gy,gz,label
1760000000000,3200,3150,3100,3050,3120,0.12,0.04,0.98,1.2,0.4,0.1,open_hand
```

- Une ligne par échantillon, `label` identique sur toute la session.
- Collecte : **chaque membre** enregistre chaque geste au moins **30 fois**, avec des variations (vitesse, position du bras).
- Les données issues des simulateurs sont **interdites** dans le jeu d'entraînement final.

---

## 12. Questions ouvertes (à trancher à 4)

| # | Question | Impact |
|---|---|---|
| 1 | Backend en **FastAPI** (schéma actuel) ou **Django** (ateliers) ? | Auth, rôles, WebSocket, base |
| 2 | Cloud accepté pour l'IA, ou IA **sur l'ESP32** obligatoire (sujet : « embarquée ») ? | Architecture, firmware |
| 3 | Voiture + feu validés par l'encadrant à la place de lampes / servomoteurs ? | Périmètre |
| 4 | Règle de `speed` : fixe, ou fonction de la confiance / flexion ? | Moteur de décision |
| 5 | Base de données : PostgreSQL, SQLite ou MongoDB ? | Persistance |
| 6 | Où héberger le broker pour la démo (PC local, VPS) ? | Réseau, TLS |

---

## 13. Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-10-10 | Premier brouillon |
