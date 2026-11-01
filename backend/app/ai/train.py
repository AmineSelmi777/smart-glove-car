import argparse
from collections import defaultdict

import joblib
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import GroupKFold, cross_val_predict

from ..config import MODEL_PATH
from .dataset import DATA_DIR, STEP, WINDOW, build_dataset
from .features import FEATURE_NAMES


def make_model() -> RandomForestClassifier:
    return RandomForestClassifier(
        n_estimators=30,        # petit : exportable vers l'ESP32 plus tard
        max_depth=8,
        min_samples_leaf=3,
        class_weight="balanced",
        random_state=42,
        n_jobs=-1,
    )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default=str(DATA_DIR))
    args = ap.parse_args()

    X, y, groups = build_dataset(args.data_dir)
    labels = sorted(str(c) for c in set(y))
    print(f"{len(X)} fenêtres, {len(set(groups))} sessions, classes : {labels}")

    # Évaluation : les sessions de test ne sont JAMAIS vues à l'entraînement
    n_splits = min(5, len(set(groups)))
    if n_splits < 2:
        raise SystemExit("Il faut au moins 2 sessions pour évaluer le modèle")
    pred = cross_val_predict(make_model(), X, y, groups=groups, cv=GroupKFold(n_splits=n_splits))
    print("\n=== Évaluation par sessions (validation croisée) ===")
    print(classification_report(y, pred, digits=3))
    print("Matrice de confusion (lignes = réel, colonnes = prédit) :")
    print(labels)
    print(confusion_matrix(y, pred, labels=labels))

    # Entraînement final sur toutes les données
    model = make_model().fit(X, y)

    # Importance par canal (aide à décider du nombre de capteurs)
    par_canal = defaultdict(float)
    for name, imp in zip(FEATURE_NAMES, model.feature_importances_):
        par_canal[name.split("_")[0]] += imp
    print("\n=== Importance par canal ===")
    for canal, imp in sorted(par_canal.items(), key=lambda kv: -kv[1]):
        print(f"{canal:>5} : {imp:6.1%}")

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({"model": model, "window": WINDOW, "step": STEP, "labels": labels}, MODEL_PATH)
    print(f"\nModèle sauvegardé : {MODEL_PATH}")


if __name__ == "__main__":
    main()