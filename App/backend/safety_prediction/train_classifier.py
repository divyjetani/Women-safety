from __future__ import annotations

from pathlib import Path

import joblib
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline

from config.settings import THREAT_DATASET_PATH, TEXT_CLASSIFIER_MODEL_PATH


def _find_dataset() -> Path:
    primary = Path(THREAT_DATASET_PATH)
    if primary.exists():
        return primary

    candidates = [
        Path(__file__).resolve().parent / "threat_dataset.csv",
        Path(__file__).resolve().parents[1] / "data" / "threat_dataset.csv",
        Path(__file__).resolve().parents[2] / "data" / "threat_dataset.csv",
        Path(__file__).resolve().parents[3] / "threat_dataset.csv",
    ]

    for fallback in candidates:
        if fallback.exists():
            return fallback

    raise FileNotFoundError("threat_dataset.csv not found in expected locations")


def train_and_save() -> None:
    dataset_path = _find_dataset()
    df = pd.read_csv(dataset_path)

    if "text" not in df.columns or "label" not in df.columns:
        raise ValueError("Dataset must contain 'text' and 'label' columns")

    texts = df["text"].astype(str).fillna("").tolist()
    labels = df["label"].astype(int).tolist()

    model = Pipeline(
        [
            (
                "tfidf",
                TfidfVectorizer(
                    ngram_range=(1, 2),
                    min_df=1,
                    max_features=12000,
                ),
            ),
            ("clf", LogisticRegression(max_iter=2000, class_weight="balanced")),
        ]
    )

    model.fit(texts, labels)

    output_path = Path(TEXT_CLASSIFIER_MODEL_PATH)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, output_path)

    # print(f"Dataset: {dataset_path}")
    # print(f"Rows: {len(df)}")
    # print(f"Model saved at: {output_path}")


if __name__ == "__main__":
    train_and_save()
