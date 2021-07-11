import logging
import coloredlogs

logger = logging.getLogger("arnix")
coloredlogs.install(level=logging.DEBUG, logger=logger)
