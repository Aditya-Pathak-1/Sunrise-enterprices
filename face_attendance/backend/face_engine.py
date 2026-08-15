"""
face_engine.py — Face recognition engine using InsightFace buffalo_l.

This is the ONLY file that imports InsightFace.
Swapping models/backends means only editing this file.

Model: buffalo_l (InsightFace)
  - Detector : RetinaFace  (accurate multi-scale face detection)
  - Recognizer: ArcFace R100 (512-dim L2-normalized embeddings)
  - Runtime  : ONNX Runtime CPU (no TensorFlow / PyTorch needed)

buffalo_l is downloaded automatically on first run to:
  ~/.insightface/models/buffalo_l/
  (~350 MB, one-time download, then cached permanently)

Similarity metric:
  Cosine similarity = dot product of two L2-normalized (unit) vectors.
  Range: -1.0 (opposite) to 1.0 (identical).
  Typical same-person scores: 0.35 – 0.75
  Default acceptance threshold: 0.35
"""

from __future__ import annotations

import io
import logging
import os
from typing import Optional

import cv2
import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
_DEFAULT_THRESHOLD = 0.35   # InsightFace buffalo_l cosine similarity scale


def _get_threshold() -> float:
    """Read threshold from env var FACE_SIMILARITY_THRESHOLD, fallback to default."""
    raw = os.environ.get("FACE_SIMILARITY_THRESHOLD", str(_DEFAULT_THRESHOLD))
    try:
        val = float(raw)
        if not (-1.0 < val < 1.0):
            raise ValueError
        return val
    except ValueError:
        logger.warning(
            "Invalid FACE_SIMILARITY_THRESHOLD=%r — using default %.2f",
            raw,
            _DEFAULT_THRESHOLD,
        )
        return _DEFAULT_THRESHOLD


# ---------------------------------------------------------------------------
# FaceEngine
# ---------------------------------------------------------------------------

class FaceEngine:
    """
    Modular face recognition engine (InsightFace buffalo_l backend).

    Thread safety: InsightFace FaceAnalysis is NOT thread-safe.
    For an MVP with low concurrency, the module-level singleton is fine.
    For production, use a thread-local or per-request instance with locking.

    Public API
    ──────────
    get_embedding(image_bytes)          -> list[float]  (512-dim)
    detect_faces_count(image_bytes)     -> int
    find_best_match(embedding, people)  -> (person | None, similarity)
    """

    def __init__(self) -> None:
        self.threshold: float = _get_threshold()
        self._app = None          # lazy-loaded InsightFace FaceAnalysis
        logger.info(
            "[FaceEngine] Initialized. Model=buffalo_l  Threshold=%.2f  (not loaded yet)",
            self.threshold,
        )

    # ------------------------------------------------------------------
    # Lazy model loader
    # ------------------------------------------------------------------

    def _load_model(self) -> None:
        """
        Load InsightFace buffalo_l on first use.
        Downloads model weights if not already cached (~350 MB, one time).
        """
        if self._app is not None:
            return

        logger.info("[FaceEngine] Loading InsightFace buffalo_l model …")
        try:
            from insightface.app import FaceAnalysis
            self._app = FaceAnalysis(
                name="buffalo_l",
                providers=["CPUExecutionProvider"],
            )
            # ctx_id=0 means CPU (use 0 for GPU with CUDAExecutionProvider)
            # det_size=(640, 640) — good balance of speed vs accuracy
            self._app.prepare(ctx_id=0, det_size=(640, 640))
            logger.info("[FaceEngine] buffalo_l loaded successfully.")
        except Exception as exc:
            self._app = None
            logger.error("[FaceEngine] Failed to load model: %s", exc)
            raise RuntimeError(f"InsightFace model load failed: {exc}") from exc

    # ------------------------------------------------------------------
    # Image decoding helper
    # ------------------------------------------------------------------

    @staticmethod
    def _bytes_to_bgr(image_bytes: bytes) -> np.ndarray:
        """
        Decode raw image bytes (JPEG/PNG/etc.) to a BGR numpy array
        suitable for OpenCV / InsightFace.
        """
        try:
            # Use Pillow first for robust format support, then convert to BGR
            pil_img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
            arr = np.array(pil_img)
            bgr = cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)
            return bgr
        except Exception as exc:
            raise ValueError(f"Cannot decode image: {exc}") from exc

    # ------------------------------------------------------------------
    # Public methods
    # ------------------------------------------------------------------

    def get_embedding(self, image_bytes: bytes) -> list[float]:
        """
        Extract a face embedding from raw image bytes.

        Exactly ONE face must be present in the image.

        Returns
        -------
        list[float]
            512-dimensional L2-normalized ArcFace embedding.

        Raises
        ------
        ValueError
            If 0 faces or >1 faces are detected.
        RuntimeError
            If the model fails to load or inference fails.
        """
        self._load_model()

        img_bgr = self._bytes_to_bgr(image_bytes)
        faces = self._app.get(img_bgr)

        if len(faces) == 0:
            raise ValueError(
                "No face detected in the image. "
                "Please ensure your face is clearly visible and well-lit."
            )
        if len(faces) > 1:
            raise ValueError(
                f"Multiple faces detected ({len(faces)}). "
                "Please ensure only one face is visible in the frame."
            )

        embedding: np.ndarray = faces[0].normed_embedding   # already L2-normalized
        return embedding.tolist()

    def detect_faces_count(self, image_bytes: bytes) -> int:
        """
        Count the number of faces detected in the image.

        Returns
        -------
        int
            0  — no face
            1  — exactly one face (suitable for recognition)
            N  — multiple faces
        """
        self._load_model()
        img_bgr = self._bytes_to_bgr(image_bytes)
        faces = self._app.get(img_bgr)
        return len(faces)

    def find_best_match(
        self,
        embedding: list[float],
        people: list[dict],
    ) -> tuple[Optional[dict], float]:
        """
        Find the closest registered person to the given embedding.

        Parameters
        ----------
        embedding : list[float]
            Query embedding (512-dim, L2-normalized) from get_embedding().
        people : list[dict]
            Each dict must have an 'embeddings' key containing a list of
            list[float] (one per enrolled photo).

        Returns
        -------
        (person_dict, similarity)
            Best matching person and their highest similarity score,
            if similarity >= self.threshold.
        (None, 0.0)
            If no person exceeds the threshold.
        """
        if not people:
            return None, 0.0

        query = np.array(embedding, dtype=np.float32)

        best_person: Optional[dict] = None
        best_similarity: float = -1.0

        for person in people:
            stored_embeddings: list[list[float]] = person.get("embeddings", [])
            if not stored_embeddings:
                continue

            # Compare query against each stored embedding for this person,
            # take the MAX similarity (best matching photo)
            for stored_emb in stored_embeddings:
                ref = np.array(stored_emb, dtype=np.float32)
                sim = float(np.dot(query, ref))   # cosine sim (both L2-normalized)
                if sim > best_similarity:
                    best_similarity = sim
                    best_person = person

        if best_similarity >= self.threshold:
            return best_person, best_similarity

        return None, 0.0

    # ------------------------------------------------------------------
    # Static helper exposed for testing
    # ------------------------------------------------------------------

    @staticmethod
    def _cosine_similarity(a: list[float], b: list[float]) -> float:
        """
        Cosine similarity between two vectors (need not be normalized).
        Returns a value in [-1, 1] where 1 = identical direction.
        """
        va = np.array(a, dtype=np.float32)
        vb = np.array(b, dtype=np.float32)
        norm_a = np.linalg.norm(va)
        norm_b = np.linalg.norm(vb)
        if norm_a == 0.0 or norm_b == 0.0:
            return 0.0
        return float(np.dot(va, vb) / (norm_a * norm_b))


# ---------------------------------------------------------------------------
# Module-level singleton — import and use this everywhere
# ---------------------------------------------------------------------------
face_engine = FaceEngine()
