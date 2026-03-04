# App/backend/services/safety_service.py
import numpy as np
import pandas as pd
import joblib
import sys
import types
from sklearn.metrics.pairwise import haversine_distances
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.preprocessing import StandardScaler
from config.settings import (
    GEO_SAFETY_MODEL_PATH,
    GEO_SCALER_PATH,
    DATA_CSV_PATH,
    EARTH_RADIUS,
)
from utils.logger import logger


class SafetyScoreService:
    def __init__(self):
        try:
            self.df = pd.read_csv(DATA_CSV_PATH)
            self.model, self.scaler = self._load_or_rebuild_geo_artifacts()
            logger.info("✅ SafetyScoreService initialized successfully")
        except Exception as e:
            logger.error(f"❌ Error initializing SafetyScoreService: {e}")
            raise

    def _load_or_rebuild_geo_artifacts(self):
        try:
            model = self._load_model_with_compat()
            scaler = joblib.load(GEO_SCALER_PATH)
            return model, scaler
        except Exception as exc:
            logger.warning(f"⚠️ Failed to load geo model artifacts, rebuilding: {exc}")
            return self._rebuild_geo_artifacts()

    def _rebuild_geo_artifacts(self):
        training_rows = []
        random_generator = np.random.default_rng(42)

        for _, row in self.df.iterrows():
            for _ in range(20):
                lat = row["crime_area_lat"] + random_generator.uniform(-0.01, 0.01)
                lon = row["crime_area_lon"] + random_generator.uniform(-0.01, 0.01)

                dist_police = self.calculate_distance(lat, lon, row["police_lat"], row["police_lon"])
                dist_brts = self.calculate_distance(lat, lon, row["nearest_brts_lat"], row["nearest_brts_lon"])
                dist_crime = self.calculate_distance(lat, lon, row["crime_area_lat"], row["crime_area_lon"])
                dist_crowd = self.calculate_distance(lat, lon, row["crowd_density_lat"], row["crowd_density_lon"])
                dist_cctv = self.calculate_distance(lat, lon, row["cctv_coverage_lat"], row["cctv_coverage_lon"])
                dist_lighting = self.calculate_distance(
                    lat,
                    lon,
                    row["lighting_condition_lat"],
                    row["lighting_condition_lon"],
                )

                safety_score = (
                    50
                    - row["crime_rate_score"] * 5
                    - dist_crime * 3
                    - row["crowd_density_score"] * 2
                    + row["cctv_coverage_score"] * 3
                    + row["lighting_condition_score"] * 3
                    - dist_police * 1.5
                )

                safety_score = np.clip(safety_score, 10, 90)

                training_rows.append(
                    [
                        dist_police,
                        dist_brts,
                        dist_crime,
                        dist_crowd,
                        dist_cctv,
                        dist_lighting,
                        row["crime_rate_score"],
                        row["crowd_density_score"],
                        row["cctv_coverage_score"],
                        row["lighting_condition_score"],
                        safety_score,
                    ]
                )

        train_df = pd.DataFrame(
            training_rows,
            columns=[
                "dist_police",
                "dist_brts",
                "dist_crime",
                "dist_crowd",
                "dist_cctv",
                "dist_lighting",
                "crime_rate_score",
                "crowd_density_score",
                "cctv_score",
                "lighting_score",
                "safety_score",
            ],
        )

        features = train_df.drop("safety_score", axis=1)
        target = train_df["safety_score"]

        scaler = StandardScaler()
        features_scaled = scaler.fit_transform(features)

        model = GradientBoostingRegressor(n_estimators=300, learning_rate=0.05, random_state=42)
        model.fit(features_scaled, target)

        joblib.dump(model, GEO_SAFETY_MODEL_PATH)
        joblib.dump(scaler, GEO_SCALER_PATH)
        logger.warning("⚠️ Rebuilt geo safety model artifacts using current environment")
        return model, scaler

    @staticmethod
    def _load_model_with_compat():
        applied_loss_compat = False
        applied_numpy_compat = False

        while True:
            try:
                return joblib.load(GEO_SAFETY_MODEL_PATH)
            except Exception as exc:
                applied = False

                if SafetyScoreService._needs_legacy_loss_compat(exc) and not applied_loss_compat:
                    SafetyScoreService._apply_legacy_loss_compat()
                    applied_loss_compat = True
                    applied = True

                if SafetyScoreService._needs_numpy_pickle_compat(exc) and not applied_numpy_compat:
                    SafetyScoreService._apply_numpy_pickle_compat()
                    applied_numpy_compat = True
                    applied = True

                if not applied:
                    raise

    @staticmethod
    def _needs_legacy_loss_compat(exc: Exception) -> bool:
        if isinstance(exc, ModuleNotFoundError) and exc.name == "_loss":
            return True

        if isinstance(exc, AttributeError):
            msg = str(exc)
            return "Can't get attribute" in msg and "_loss" in msg

        return False

    @staticmethod
    def _needs_numpy_pickle_compat(exc: Exception) -> bool:
        if isinstance(exc, ModuleNotFoundError):
            return exc.name.startswith("numpy._core")

        if isinstance(exc, ValueError):
            return "BitGenerator" in str(exc)

        if isinstance(exc, SystemError):
            return "structseq.c" in str(exc)

        return False

    @staticmethod
    def _apply_legacy_loss_compat() -> None:
        import sklearn._loss.loss as sklearn_loss_loss

        legacy_loss_module = types.ModuleType("_loss")
        for name in dir(sklearn_loss_loss):
            setattr(legacy_loss_module, name, getattr(sklearn_loss_loss, name))

        sys.modules["_loss"] = legacy_loss_module
        sys.modules["_loss.loss"] = sklearn_loss_loss
        logger.warning("⚠️ Applied sklearn '_loss' compatibility shim for legacy model")

    @staticmethod
    def _apply_numpy_pickle_compat() -> None:
        import numpy.core as numpy_core
        import numpy.core.numeric as numpy_core_numeric
        import numpy.random._pickle as numpy_pickle

        sys.modules.setdefault("numpy._core", numpy_core)
        sys.modules.setdefault("numpy._core.numeric", numpy_core_numeric)

        original_ctor = getattr(numpy_pickle, "__bit_generator_ctor", None)
        if original_ctor is None:
            return

        if not getattr(original_ctor, "_she_safe_compat", False):
            def compat_bit_generator_ctor(bit_generator_name):
                if isinstance(bit_generator_name, type):
                    bit_generator_name = bit_generator_name.__name__
                return original_ctor(bit_generator_name)

            compat_bit_generator_ctor._she_safe_compat = True
            setattr(numpy_pickle, "__bit_generator_ctor", compat_bit_generator_ctor)

        logger.warning("⚠️ Applied NumPy pickle compatibility shim for legacy model")

    @staticmethod
    def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        coords1 = np.radians([[lat1, lon1]])
        coords2 = np.radians([[lat2, lon2]])
        return haversine_distances(coords1, coords2)[0][0] * EARTH_RADIUS

    def get_features_for_location(self, lat: float, lon: float) -> pd.DataFrame:
        # find nearest feature row based on crime area distance
        self.df["temp_distance"] = self.df.apply(
            lambda row: self.calculate_distance(
                lat, lon,
                row["crime_area_lat"],
                row["crime_area_lon"]
            ),
            axis=1
        )

        nearest = self.df.loc[self.df["temp_distance"].idxmin()]

        features = [
            self.calculate_distance(lat, lon, nearest["police_lat"], nearest["police_lon"]),
            self.calculate_distance(lat, lon, nearest["nearest_brts_lat"], nearest["nearest_brts_lon"]),
            self.calculate_distance(lat, lon, nearest["crime_area_lat"], nearest["crime_area_lon"]),
            self.calculate_distance(lat, lon, nearest["crowd_density_lat"], nearest["crowd_density_lon"]),
            self.calculate_distance(lat, lon, nearest["cctv_coverage_lat"], nearest["cctv_coverage_lon"]),
            self.calculate_distance(lat, lon, nearest["lighting_condition_lat"], nearest["lighting_condition_lon"]),
            nearest["crime_rate_score"],
            nearest["crowd_density_score"],
            nearest["cctv_coverage_score"],
            nearest["lighting_condition_score"],
        ]

        feature_names = [
            "dist_police",
            "dist_brts",
            "dist_crime",
            "dist_crowd",
            "dist_cctv",
            "dist_lighting",
            "crime_rate_score",
            "crowd_density_score",
            "cctv_score",
            "lighting_score"
        ]

        return pd.DataFrame([features], columns=feature_names)

    # safety score -> higher = safer
    def get_safety_score(self, lat: float, lon: float) -> float:
        try:
            features = self.get_features_for_location(lat, lon)
            features_scaled = self.scaler.transform(features)
            prediction = self.model.predict(features_scaled)[0]
            
            prediction = max(0, min(100, round(prediction, 2)))
            return prediction
        except Exception as e:
            logger.error(f"❌ Error calculating safety score: {e}")
            return 50.0 
