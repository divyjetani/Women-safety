import logging
import sys

# setup logger
def setup_logger(name: str, level: int = logging.INFO) -> logging.Logger:
    logging.basicConfig(
        level=level,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        stream=sys.stdout,
        force=True,
    )
    logger = logging.getLogger(name)
    logger.setLevel(level)
    logger.propagate = True
    return logger

# Main app logger
logger = setup_logger("she_safe_backend")
