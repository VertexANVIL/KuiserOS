import logging
import coloredlogs

logger = logging.getLogger("kuiseros")
coloredlogs.install(level=logging.DEBUG, logger=logger)
