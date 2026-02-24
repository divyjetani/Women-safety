import logging

# setup logger
def setup_logger(name: str, level: int = logging.INFO) -> logging.Logger:
    logging.basicConfig(
        level=level,
        format="%(asctime)s | %(levelname)s | %(message)s"
    )
    logger = logging.getLogger(name)
    return logger

# Main app logger
logger = setup_logger("she_safe_backend")
