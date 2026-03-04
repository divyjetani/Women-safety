# App/backend/services/text_threat_classifier.py
from __future__ import annotations

import joblib
from pathlib import Path
from typing import Any

from sklearn.exceptions import NotFittedError

from config.settings import TEXT_CLASSIFIER_MODEL_PATH
from utils.logger import logger


class TextThreatClassifier:
    def __init__(self, model_path: str | None = None):
        self.model_path = model_path or TEXT_CLASSIFIER_MODEL_PATH
        self._model: Any | None = None
        self._rebuild_attempted = False
        self._load_model()

    def _load_model(self):
        path = Path(self.model_path)
        if not path.exists():
            logger.warning(f"⚠️ Threat classifier model not found at {path}")
            self._model = None
            return

        try:
            candidate = joblib.load(path)
            if not self._is_model_usable(candidate):
                logger.warning("⚠️ Loaded threat classifier model is not usable. Rebuilding model artifact.")
                if self._rebuild_model_artifact():
                    candidate = joblib.load(path)
                else:
                    self._model = None
                    logger.warning("⚠️ Threat classifier disabled because model artifact could not be rebuilt")
                    return

                if not self._is_model_usable(candidate):
                    self._model = None
                    logger.warning("⚠️ Threat classifier disabled because rebuilt model is still unusable")
                    return

            self._model = candidate
            logger.info(f"✅ Loaded threat text classifier from {path}")
        except Exception as exc:
            logger.error(f"❌ Failed loading threat text classifier: {exc}")
            self._model = None

    @staticmethod
    def _is_unfitted_error(exc: Exception) -> bool:
        if isinstance(exc, NotFittedError):
            return True

        msg = str(exc).lower()
        return "not fitted" in msg or "idf vector is not fitted" in msg

    def _rebuild_model_artifact(self) -> bool:
        if self._rebuild_attempted:
            return False

        self._rebuild_attempted = True
        try:
            from safety_prediction.train_classifier import train_and_save

            train_and_save()
            logger.info("✅ Rebuilt threat text classifier model artifact")
            return True
        except Exception as exc:
            logger.error(f"❌ Failed to rebuild threat text classifier model: {exc}")
            return False

    def _predict_internal(self, text: str) -> tuple[int, float]:
        model = self._model
        if model is None:
            raise RuntimeError("Threat classifier model not loaded")

        if hasattr(model, "predict"):
            label = int(model.predict([text])[0])
            confidence = 0.0
            if hasattr(model, "predict_proba"):
                probs = model.predict_proba([text])[0]
                confidence = float(probs[1] if len(probs) > 1 else probs[0])
            return label, confidence

        if isinstance(model, dict):
            predictor = (
                model.get("pipeline")
                or model.get("model")
                or model.get("classifier")
            )
            vectorizer = model.get("vectorizer") or model.get("tfidf")

            if predictor is None:
                raise ValueError("Unsupported model dict format: missing predictor")

            if vectorizer is not None:
                features = vectorizer.transform([text])
                label = int(predictor.predict(features)[0])
                confidence = 0.0
                if hasattr(predictor, "predict_proba"):
                    probs = predictor.predict_proba(features)[0]
                    confidence = float(probs[1] if len(probs) > 1 else probs[0])
                return label, confidence

            if hasattr(predictor, "predict"):
                label = int(predictor.predict([text])[0])
                confidence = 0.0
                if hasattr(predictor, "predict_proba"):
                    probs = predictor.predict_proba([text])[0]
                    confidence = float(probs[1] if len(probs) > 1 else probs[0])
                return label, confidence

        raise ValueError(f"Unsupported text threat classifier artifact type: {type(model)}")

    def _is_model_usable(self, model: Any) -> bool:
        prev_model = self._model
        try:
            self._model = model
            self._predict_internal("health check")
            return True
        except Exception as exc:
            logger.warning(f"⚠️ Threat classifier health-check failed: {exc}")
            return False
        finally:
            self._model = prev_model

    def predict(self, text: str) -> dict:
        normalized = (text or "").strip()
        if not normalized or self._model is None:
            return {
                "is_threat": False,
                "confidence": 0.0,
                "label": 0,
            }

        try:
            label, confidence = self._predict_internal(normalized)

            return {
                "is_threat": label == 1,
                "confidence": round(confidence, 4),
                "label": label,
            }
        except Exception as exc:
            if self._is_unfitted_error(exc) and self._rebuild_model_artifact():
                try:
                    self._load_model()
                    label, confidence = self._predict_internal(normalized)
                    return {
                        "is_threat": label == 1,
                        "confidence": round(confidence, 4),
                        "label": label,
                    }
                except Exception as retry_exc:
                    logger.error(f"❌ Threat classifier retry after rebuild failed: {retry_exc}")

            logger.error(f"❌ Threat classifier prediction failed: {exc}")
            return {
                "is_threat": False,
                "confidence": 0.0,
                "label": 0,
            }
